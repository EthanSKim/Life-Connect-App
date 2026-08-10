const express = require('express');
const router = express.Router();
const pool = require('../db');
const asyncHandler = require('../middleware/asyncHandler');
const { encryptPin, decryptPin, generateAttendanceToken } = require('../crypto');
const { requireAdmin, requireSelfOrAdmin } = require('../auth');

// 성도 등록/수정 요청 바디에서 공통으로 뽑아 쓰는 필드 목록.
// 한 곳에서만 관리해서 등록/수정 라우트가 서로 다른 필드 집합을 받는
// 실수를 방지한다.
function extractMemberFields(body) {
  return {
    first_name: body.first_name,
    last_name: body.last_name,
    mobile_phone: body.mobile_phone,
    birthdate: body.birthdate || null,
    gender: body.gender,
    marital_status: body.marital_status || null,
    anniversary: body.anniversary || null,
    is_child: body.is_child === true,
    grade: body.grade === '' || body.grade === undefined ? null : body.grade,
    email: body.email,
    address_street: body.address_street,
    address_city: body.address_city,
    address_state: body.address_state,
    address_zip: body.address_zip,
    address_country_code: body.address_country_code || 'US',
    address_country: body.address_country || 'United States',
    membership_role: body.membership_role || 'Member',
    life_team_id: body.life_team_id || null,
    church_title: body.church_title,
    campus_name: body.campus_name || 'Louisville Woori Church',
  };
}

// 프론트엔드도 이름을 검사하지만, 서버가 클라이언트 쪽 검증만 믿어서는 안 된다 -
// 직접 API를 호출하면 프론트엔드 검증을 건너뛸 수 있기 때문에, 이름 없는
// 성도가 생성되는 것을 막으려면 서버에서도 반드시 확인해야 한다.
function validateMemberFields(f, res) {
  if (!f.first_name || !f.first_name.trim() || !f.last_name || !f.last_name.trim()) {
    res.status(400).json({ success: false, message: "성과 이름을 입력해주세요." });
    return false;
  }
  return true;
}

// 1. 성도 목록 조회 및 검색 (기본적으로 탈퇴(inactive) 처리된 성도는 제외)
router.get('/', requireAdmin, asyncHandler(async (req, res) => {
  const { search, life_team, include_inactive } = req.query;
  const conditions = [];
  const values = [];

  if (!include_inactive || include_inactive === 'false') {
    conditions.push("status != 'inactive'");
  }
  if (search) {
    values.push(`%${search}%`);
    // 성/이름을 따로 검색할 때뿐 아니라, 성+이름을 붙여서 입력할 때도
    // (한국어 이름을 입력하는 일반적인 방식) 찾을 수 있어야 한다 - 그렇지
    // 않으면 성을 입력할 땐 검색되다가 이름까지 이어서 입력하는 순간
    // 결과가 사라지는 문제가 생긴다 (성/이름이 각각 다른 컬럼이라 합쳐진
    // 문자열은 어느 쪽과도 일치하지 않기 때문). 로그인/QR 스캔의 이름
    // 매칭에서 이미 쓰던 것과 같은 패턴.
    conditions.push(`(first_name ILIKE $${values.length} OR last_name ILIKE $${values.length} OR (last_name || first_name) ILIKE $${values.length})`);
  }
  if (life_team) {
    values.push(life_team);
    conditions.push(`life_team = $${values.length}`);
  }

  const query = `SELECT * FROM members${conditions.length ? ' WHERE ' + conditions.join(' AND ') : ''} ORDER BY household_id, is_primary_contact DESC, first_name`;
  const result = await pool.query(query, values);
  // pin_code is never returned in bulk listings, even encrypted - admins
  // use the dedicated GET /:id/pin endpoint to look one up.
  const rows = result.rows.map(({ pin_code, attendance_token, ...rest }) => rest);
  res.json(rows);
}));

// 2. 새 성도 등록
router.post('/', requireAdmin, asyncHandler(async (req, res) => {
  const f = extractMemberFields(req.body);
  if (!validateMemberFields(f, res)) return;

  // life_team은 life_teams 테이블의 비정규화된 텍스트 사본이므로, ID로부터
  // 이름을 조회해서 함께 저장한다.
  let lifeTeamName = null;
  if (f.life_team_id) {
    const teamResult = await pool.query('SELECT name FROM life_teams WHERE life_team_id = $1', [f.life_team_id]);
    lifeTeamName = teamResult.rows[0]?.name || null;
  }

  const query = `
    INSERT INTO members (
      person_id, first_name, last_name, mobile_phone, birthdate,
      gender, marital_status, anniversary, is_child, grade, email,
      address_street, address_city, address_state, address_zip,
      address_country_code, address_country,
      membership_role, life_team_id, life_team, church_title, campus_name,
      pin_code, is_default_pin, attendance_token, created_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, NOW())
    RETURNING *`;

  // person_id는 실제 운영 환경에선 Sequence를 쓰지만, 여기서는 고유한 BIGINT를 위해 timestamp 사용
  const person_id = Date.now();

  // 초기 PIN: 휴대폰 번호 마지막 6자리. 번호가 없거나 6자리 미만이면 기본값 123456 사용.
  const phoneDigits = (f.mobile_phone || '').replace(/\D/g, '');
  const initialPin = phoneDigits.length >= 6 ? phoneDigits.slice(-6) : '123456';

  const values = [
    person_id, f.first_name, f.last_name, f.mobile_phone, f.birthdate,
    f.gender, f.marital_status, f.anniversary, f.is_child, f.grade, f.email,
    f.address_street, f.address_city, f.address_state, f.address_zip,
    f.address_country_code, f.address_country,
    f.membership_role, f.life_team_id, lifeTeamName, f.church_title, f.campus_name,
    encryptPin(initialPin), true, generateAttendanceToken(),
  ];

  const result = await pool.query(query, values);
  const { pin_code, attendance_token, ...memberWithoutPin } = result.rows[0];
  res.status(201).json(memberWithoutPin);
}));

// 2.1 특정 성도 상세 정보 조회 (ProfileScreen / 관리자 상세 대응)
router.get('/:id', requireSelfOrAdmin('id'), asyncHandler(async (req, res) => {
  const { id } = req.params;

  const memberResult = await pool.query('SELECT * FROM members WHERE person_id = $1', [id]);
  if (memberResult.rows.length === 0) {
    return res.status(404).json({ error: "성도를 찾을 수 없습니다." });
  }

  const { pin_code, attendance_token, ...member } = memberResult.rows[0];

  // 가족 정보 조회 (같은 세대에 속한 다른 성도들 + 관계)
  let family = [];
  if (member.household_id) {
    const familyResult = await pool.query(
      `SELECT person_id, first_name, last_name, membership_role, relationship_to_head, is_primary_contact
       FROM members WHERE household_id = $1 AND person_id != $2 AND status != 'inactive'`,
      [member.household_id, id]
    );
    family = familyResult.rows;
  }

  res.json({ member, family });
}));

// 2.2 성도 정보 수정
router.put('/:id', requireSelfOrAdmin('id'), asyncHandler(async (req, res) => {
  const { id } = req.params;
  const f = extractMemberFields(req.body);
  if (!validateMemberFields(f, res)) return;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const beforeResult = await client.query('SELECT life_team_id FROM members WHERE person_id = $1', [id]);
    if (beforeResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: "성도를 찾을 수 없습니다." });
    }
    const previousTeamId = beforeResult.rows[0].life_team_id;

    // life_team은 life_teams 테이블의 비정규화된 텍스트 사본이므로, ID로부터
    // 이름을 조회해서 함께 저장한다.
    let lifeTeamName = null;
    if (f.life_team_id) {
      const teamResult = await client.query('SELECT name FROM life_teams WHERE life_team_id = $1', [f.life_team_id]);
      lifeTeamName = teamResult.rows[0]?.name || null;
    }

    const query = `
      UPDATE members SET
        first_name = $1, last_name = $2, mobile_phone = $3, birthdate = $4,
        gender = $5, marital_status = $6, anniversary = $7, is_child = $8, grade = $9, email = $10,
        address_street = $11, address_city = $12, address_state = $13, address_zip = $14,
        address_country_code = $15, address_country = $16,
        membership_role = $17, life_team_id = $18, life_team = $19, church_title = $20, campus_name = $21,
        updated_at = NOW()
      WHERE person_id = $22 RETURNING *`;

    const values = [
      f.first_name, f.last_name, f.mobile_phone, f.birthdate,
      f.gender, f.marital_status, f.anniversary, f.is_child, f.grade, f.email,
      f.address_street, f.address_city, f.address_state, f.address_zip,
      f.address_country_code, f.address_country,
      f.membership_role, f.life_team_id, lifeTeamName, f.church_title, f.campus_name,
      id,
    ];

    const result = await client.query(query, values);

    // 이 성도가 이전 팀의 리더였는데 팀이 바뀌었다면, 그 팀의 리더 지정을 해제한다
    // (세대주 해제와 동일한 패턴).
    if (previousTeamId && previousTeamId !== f.life_team_id) {
      await client.query(
        'UPDATE life_teams SET leader_id = NULL, updated_at = NOW() WHERE life_team_id = $1 AND leader_id = $2::BIGINT',
        [previousTeamId, id]
      );
    }

    await client.query('COMMIT');
    const { pin_code, attendance_token, ...memberWithoutPin } = result.rows[0];
    res.json(memberWithoutPin);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}));

// 2.3 성도 삭제 (소프트 삭제 - status를 inactive로 변경, 출석/예약 이력은 보존)
router.delete('/:id', requireAdmin, asyncHandler(async (req, res) => {
  const { id } = req.params;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const result = await client.query(
      "UPDATE members SET status = 'inactive', updated_at = NOW() WHERE person_id = $1::BIGINT RETURNING household_id",
      [id]
    );
    if (result.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, message: "성도를 찾을 수 없습니다." });
    }

    // 삭제된 성도가 세대주였다면 세대주 지정을 해제한다 (세대 자체는 유지)
    await client.query(
      'UPDATE households SET head_of_household_id = NULL, updated_at = NOW() WHERE head_of_household_id = $1::BIGINT',
      [id]
    );
    // 삭제된 성도가 라이프팀 리더였다면 리더 지정을 해제한다 (팀 자체는 유지)
    await client.query(
      'UPDATE life_teams SET leader_id = NULL, updated_at = NOW() WHERE leader_id = $1::BIGINT',
      [id]
    );

    await client.query('COMMIT');
    res.json({ success: true, message: "성도가 삭제(비활성화)되었습니다." });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}));

// 2.4 PIN 번호 변경 API (ProfileScreen 대응)
router.put('/:id/pin', requireSelfOrAdmin('id'), asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { old_pin, new_pin } = req.body;

  // 프론트엔드도 6자리 숫자인지 검사하지만, 직접 API를 호출하면 그 검증을
  // 건너뛸 수 있으므로 서버에서도 반드시 확인해야 한다.
  if (!/^\d{6}$/.test(String(new_pin || ''))) {
    return res.status(400).json({ success: false, message: "새 PIN 번호는 6자리 숫자여야 합니다." });
  }

  const userResult = await pool.query('SELECT pin_code FROM members WHERE person_id = $1::BIGINT', [id]);
  if (userResult.rows.length === 0) {
    return res.status(404).json({ success: false, message: "사용자를 찾을 수 없습니다." });
  }

  const dbPin = decryptPin(userResult.rows[0].pin_code || '').replace(/\s/g, '');
  const inputOldPin = String(old_pin).replace(/\s/g, '');

  if (dbPin !== inputOldPin) {
    return res.status(401).json({ success: false, message: "기존 PIN 번호가 일치하지 않습니다." });
  }

  // 새로운 PIN 번호로 업데이트 (암호화 저장, 기본 PIN 여부 해제)
  await pool.query(
    'UPDATE members SET pin_code = $1, is_default_pin = FALSE WHERE person_id = $2::BIGINT',
    [encryptPin(new_pin), id]
  );
  res.json({ success: true, message: "PIN 번호가 성공적으로 변경되었습니다." });
}));

// 2.5 관리자용 PIN 조회 API (성도가 PIN을 잊어버렸을 때 관리자가 확인)
router.get('/:id/pin', requireAdmin, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const result = await pool.query('SELECT pin_code FROM members WHERE person_id = $1::BIGINT', [id]);
  if (result.rows.length === 0) {
    return res.status(404).json({ success: false, message: "사용자를 찾을 수 없습니다." });
  }
  const pin = decryptPin(result.rows[0].pin_code || '');
  res.json({ success: true, pin_code: pin });
}));

module.exports = router;
