const express = require('express');
const router = express.Router();
const pool = require('../db');
const asyncHandler = require('../middleware/asyncHandler');
const { requireAdmin, requireSelfOrAdmin } = require('../auth');

// 오늘 날짜가 이미 마감(완료) 처리되었는지 확인. 마감된 날짜는 수동/일괄/QR
// 체크인 모두 서버에서 거부한다 (UI에서 버튼을 숨기는 것과 별개로, 실제
// 쓰기 자체를 막아야 마감의 의미가 있다).
async function isTodayFinalized() {
  const result = await pool.query(
    "SELECT 1 FROM attendance_finalizations WHERE attendance_date = CURRENT_DATE"
  );
  return result.rows.length > 0;
}

// 9.1 개별 성도 오늘 출석 여부 조회
router.get('/status/:person_id', requireSelfOrAdmin('person_id'), asyncHandler(async (req, res) => {
  const { person_id } = req.params;
  const query = 'SELECT status FROM attendance WHERE person_id = $1 AND attendance_date = CURRENT_DATE';
  const result = await pool.query(query, [person_id]);
  // 데이터가 존재하면 출석한 것으로 간주
  res.json({ attended: result.rows.length > 0 });
}));

// 3. 세대별 출석 데이터 + 오늘 마감 여부 조회 (AdminMainScreen - 출석 확인 탭 대응)
// household_id로 그룹화 (이름이 아닌 ID 기준 - 두 세대가 우연히 같은 이름을
// 가질 경우 잘못 합쳐지는 것을 방지). 세대가 없는 성도는 "소속 없음"으로.
router.get('/family-status', requireAdmin, asyncHandler(async (req, res) => {
  const [membersResult, finalizedResult] = await Promise.all([
    pool.query(`
      SELECT 
        m.household_id,
        m.household_name,
        m.person_id,
        m.first_name,
        m.last_name,
        m.church_title,
        m.life_team,
        m.membership_role,
        COALESCE(a.status, false) as is_present
      FROM members m
      LEFT JOIN attendance a ON m.person_id = a.person_id AND a.attendance_date = CURRENT_DATE
      WHERE m.status != 'inactive'
      ORDER BY m.household_id, m.is_primary_contact DESC, m.first_name
    `),
    pool.query("SELECT finalized_at FROM attendance_finalizations WHERE attendance_date = CURRENT_DATE"),
  ]);

  // UI의 familyData 구조로 가공: { [household_id]: { household_name, members: [...] } }
  const households = membersResult.rows.reduce((acc, row) => {
    const key = row.household_id ? String(row.household_id) : 'none';
    if (!acc[key]) acc[key] = { household_name: row.household_name || "소속 없음", members: [] };
    acc[key].members.push({
      id: row.person_id,
      name: `${row.last_name}${row.first_name}`,
      title: row.church_title,
      lifeTeam: row.life_team,
      role: row.membership_role,
      isPresent: row.is_present
    });
    return acc;
  }, {});

  res.json({
    households,
    is_finalized: finalizedResult.rows.length > 0,
    finalized_at: finalizedResult.rows[0]?.finalized_at || null,
  });
}));

// 9. QR 스캔 출석 처리 API (성도가 본인 QR을 스캐너에 보여줄 때 호출)
router.post('/scan', requireAdmin, asyncHandler(async (req, res) => {
  if (await isTodayFinalized()) {
    return res.status(409).json({ success: false, message: "오늘 출석은 이미 마감되었습니다." });
  }

  const { qr_data } = req.body; // QR 데이터 형식: "박민우|123456"

  if (!qr_data || !qr_data.includes('|')) {
    return res.status(400).json({ success: false, message: "올바르지 않은 QR 코드 형식입니다." });
  }

  const [name, pin] = qr_data.split('|');

  // 1. 이름과 PIN이 일치하는 사용자 조회 (공백 제거 로직 포함)
  const userQuery = `
    SELECT person_id, first_name, last_name 
    FROM members 
    WHERE (REPLACE(last_name || first_name, ' ', '') = REPLACE($1, ' ', '') OR REPLACE(first_name, ' ', '') = REPLACE($1, ' ', ''))
      AND REPLACE(pin_code, ' ', '') = REPLACE($2, ' ', '')
  `;
  const userResult = await pool.query(userQuery, [name, pin]);

  if (userResult.rows.length === 0) {
    return res.status(404).json({ success: false, message: "성도 정보가 일치하지 않거나 등록되지 않았습니다." });
  }

  const personId = userResult.rows[0].person_id;
  const fullName = `${userResult.rows[0].last_name}${userResult.rows[0].first_name}`;

  // 2. 출석 기록 추가 (오늘 날짜)
  const attendanceQuery = `
    INSERT INTO attendance (person_id, attendance_date, status)
    VALUES ($1, CURRENT_DATE, TRUE)
    ON CONFLICT (person_id, attendance_date) DO UPDATE SET status = EXCLUDED.status
    RETURNING *;
  `;
  await pool.query(attendanceQuery, [personId]);

  res.json({ success: true, message: `${fullName}님, 출석 확인되었습니다.` });
}));

// 4. 출석 체크 수동 변경 (관리자가 직접 체크/해제 - 성도가 QR을 깜빡했을 때 등)
router.post('/', requireAdmin, asyncHandler(async (req, res) => {
  if (await isTodayFinalized()) {
    return res.status(409).json({ success: false, message: "오늘 출석은 이미 마감되었습니다." });
  }

  const { person_id, is_present } = req.body;
  const query = `
    INSERT INTO attendance (person_id, attendance_date, status)
    VALUES ($1, CURRENT_DATE, $2)
    ON CONFLICT (person_id, attendance_date) DO UPDATE SET status = EXCLUDED.status;
  `;
  await pool.query(query, [person_id, is_present]);
  res.json({ success: true });
}));

// 5. 세대 단위 일괄 출석 체크 (가족이 한꺼번에 도착했을 때 한 번에 체크)
router.post('/bulk', requireAdmin, asyncHandler(async (req, res) => {
  if (await isTodayFinalized()) {
    return res.status(409).json({ success: false, message: "오늘 출석은 이미 마감되었습니다." });
  }

  const { person_ids, is_present } = req.body;

  if (!Array.isArray(person_ids) || person_ids.length === 0) {
    return res.status(400).json({ success: false, message: "person_ids가 필요합니다." });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    for (const personId of person_ids) {
      await client.query(
        `INSERT INTO attendance (person_id, attendance_date, status)
         VALUES ($1::BIGINT, CURRENT_DATE, $2)
         ON CONFLICT (person_id, attendance_date) DO UPDATE SET status = EXCLUDED.status`,
        [personId, is_present !== false]
      );
    }
    await client.query('COMMIT');
    res.json({ success: true, count: person_ids.length });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}));

// 6. 오늘 출석 마감 (완료 버튼) - 이후로는 해당 날짜에 대한 모든 체크인이
// 서버에서 거부된다. 이미 마감된 경우에도 에러 없이 기존 마감 정보를 반환한다
// (완료 버튼을 두 번 눌러도 안전하게 처리하기 위함).
router.post('/finalize', requireAdmin, asyncHandler(async (req, res) => {
  const existing = await pool.query(
    "SELECT finalized_at FROM attendance_finalizations WHERE attendance_date = CURRENT_DATE"
  );
  if (existing.rows.length > 0) {
    return res.json({ success: true, already_finalized: true, finalized_at: existing.rows[0].finalized_at });
  }

  const result = await pool.query(
    `INSERT INTO attendance_finalizations (attendance_date, finalized_by)
     VALUES (CURRENT_DATE, $1::BIGINT)
     RETURNING finalized_at`,
    [req.user.person_id]
  );
  res.json({ success: true, already_finalized: false, finalized_at: result.rows[0].finalized_at });
}));

module.exports = router;
