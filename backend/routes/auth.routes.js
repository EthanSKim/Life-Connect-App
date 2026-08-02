const express = require('express');
const router = express.Router();
const pool = require('../db');
const asyncHandler = require('../middleware/asyncHandler');
const { encryptPin, decryptPin, isEncrypted } = require('../crypto');
const { signToken } = require('../auth');

// 0. 사용자 확인 API (LoginScreen - 성함 확인 버튼 대응)
router.post('/verify-member', asyncHandler(async (req, res) => {
  const { name, user_name } = req.body;
  const searchName = name || user_name; // 두 필드 모두 대응
  console.log(`[Verify] Request Name: ${searchName}`);

  const query = `
    SELECT person_id, pin_code, is_default_pin
    FROM members 
    WHERE REPLACE(last_name || first_name, ' ', '') = REPLACE($1, ' ', '')
       OR REPLACE(first_name, ' ', '') = REPLACE($1, ' ', '')
    LIMIT 1`;
  const result = await pool.query(query, [searchName]);

  if (result.rows.length === 0) {
    return res.status(404).json({
      success: false,
      message: "교회 명단에 등록되지 않은 성함입니다. 성함을 다시 확인하시거나 행정실에 문의해주세요."
    });
  }

  const member = result.rows[0];
  console.log(`[Verify] Found PersonID: ${member.person_id}`);

  res.json({
    success: true,
    person_id: member.person_id,
    isNewUser: member.is_default_pin, // 기본 PIN을 아직 사용 중이면 첫 로그인으로 안내
    message: "성함 확인 완료."
  });
}));

// 0.1 PIN 로그인 API (LoginScreen - 로그인 버튼 대응)
router.post('/login', asyncHandler(async (req, res) => {
  const { person_id, pin } = req.body;
  console.log(`\n--- 로그인 시도 --- 입력된 ID: ${person_id}`);

  const userQuery = 'SELECT pin_code, is_default_pin, membership_role, church_title FROM members WHERE person_id = $1::BIGINT';
  const userResult = await pool.query(userQuery, [person_id]);

  if (userResult.rows.length === 0) {
    console.log(`결과: 실패 (사용자 없음)`);
    return res.status(404).json({ success: false, message: "사용자 정보를 찾을 수 없습니다. 다시 시도해주세요." });
  }

  const userData = userResult.rows[0];

  // 저장된 값은 암호화되어 있을 수도, (마이그레이션 전) 평문일 수도 있음
  const storedRaw = userData.pin_code || '';
  const dbPin = decryptPin(storedRaw).replace(/\s/g, '');
  const userPin = pin ? String(pin).replace(/\s/g, '') : "";

  if (dbPin.length === 0 || dbPin !== userPin) {
    console.log(`결과: 실패 (PIN 불일치)`);
    return res.status(401).json({
      success: false,
      message: "PIN 번호가 틀렸습니다. 다시 확인하고 입력해주세요."
    });
  }

  console.log(`결과: 성공 (PIN 일치)`);

  // 평문으로 저장되어 있던 값이면 이번 로그인을 계기로 암호화해서 재저장
  if (storedRaw && !isEncrypted(storedRaw)) {
    await pool.query(
      'UPDATE members SET pin_code = $1 WHERE person_id = $2::BIGINT',
      [encryptPin(storedRaw), person_id]
    );
  }

  const token = signToken({ person_id, membership_role: userData.membership_role });

  res.json({
    success: true,
    message: "로그인에 성공했습니다. 환영합니다!",
    token,
    membership_role: userData.membership_role,
    church_title: userData.church_title,
    is_default_pin: userData.is_default_pin,
  });
}));

module.exports = router;
