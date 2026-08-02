const express = require('express');
const router = express.Router();
const pool = require('../db');
const asyncHandler = require('../middleware/asyncHandler');
const { requireAuth } = require('../auth');
const { isDefaultOpen, isValidSlotRange, slotsInRange } = require('../slots');

// 7. 새로운 예약 등록 (범위 예약 지원, 서버에서 영업시간/중복/1인1건 검증)
router.post('/', requireAuth, asyncHandler(async (req, res) => {
  const { facility_id, date, start_time, end_time } = req.body;
  const person_id = req.user.person_id; // 클라이언트가 보낸 person_id는 신뢰하지 않음

  if (!facility_id || !date || !start_time || !end_time) {
    return res.status(400).json({ success: false, message: "필수 정보가 누락되었습니다." });
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return res.status(400).json({ success: false, message: "날짜 형식이 올바르지 않습니다." });
  }
  if (!isValidSlotRange(start_time, end_time)) {
    return res.status(400).json({ success: false, message: "예약 시간은 10:00-18:00 사이, 30분 단위여야 합니다." });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // 같은 장소에 대한 동시 예약 요청을 직렬화 (레이스 컨디션으로 인한 중복 예약 방지)
    await client.query('SELECT pg_advisory_xact_lock($1)', [Number(facility_id)]);

    const facilityResult = await client.query(
      'SELECT is_active, is_reservable FROM facilities WHERE facility_id = $1',
      [facility_id]
    );
    if (facilityResult.rows.length === 0 || !facilityResult.rows[0].is_active) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, message: "존재하지 않는 장소입니다." });
    }
    if (!facilityResult.rows[0].is_reservable) {
      await client.query('ROLLBACK');
      return res.status(400).json({ success: false, message: "현재 예약을 받지 않는 장소입니다." });
    }

    const nowResult = await client.query(`SELECT CURRENT_DATE::text as today, CURRENT_TIME::text as now_time`);
    const { today, now_time } = nowResult.rows[0];
    if (date < today || (date === today && start_time <= now_time)) {
      await client.query('ROLLBACK');
      return res.status(400).json({ success: false, message: "이미 지난 시간은 예약할 수 없습니다." });
    }

    const defaultOpen = isDefaultOpen(date);
    const overridesResult = await client.query(
      'SELECT slot_time, is_open FROM facility_availability_overrides WHERE facility_id = $1 AND override_date = $2',
      [facility_id, date]
    );
    const overrideMap = new Map(overridesResult.rows.map(r => [r.slot_time.slice(0, 5), r.is_open]));
    const allOpen = slotsInRange(start_time, end_time).every(slotStart => {
      const hm = slotStart.slice(0, 5);
      return overrideMap.has(hm) ? overrideMap.get(hm) : defaultOpen;
    });
    if (!allOpen) {
      await client.query('ROLLBACK');
      return res.status(400).json({ success: false, message: "선택한 시간에는 예약이 불가능합니다." });
    }

    const overlapResult = await client.query(
      `SELECT reservation_id FROM reservations
       WHERE facility_id = $1 AND reservation_date = $2 AND status = 'confirmed'
         AND start_time < $4 AND end_time > $3`,
      [facility_id, date, start_time, end_time]
    );
    if (overlapResult.rows.length > 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ success: false, message: "이미 예약된 시간입니다." });
    }

    const activeResult = await client.query(
      `SELECT reservation_id FROM reservations
       WHERE facility_id = $1 AND person_id = $2::BIGINT AND status = 'confirmed'
         AND reservation_date = $3
       LIMIT 1`,
      [facility_id, person_id, date]
    );
    if (activeResult.rows.length > 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ success: false, message: "이 날짜에 이미 이 장소에 예약이 있습니다. 먼저 기존 예약을 취소해주세요." });
    }

    const insertResult = await client.query(
      `INSERT INTO reservations (facility_id, person_id, reservation_date, start_time, end_time)
       VALUES ($1, $2::BIGINT, $3, $4, $5) RETURNING *`,
      [facility_id, person_id, date, start_time, end_time]
    );

    await client.query('COMMIT');
    res.status(201).json({ success: true, reservation: insertResult.rows[0] });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}));

// 8. 예약 취소 API (본인 확인은 서버 세션(JWT) 기준, 관리자는 모두 취소 가능)
router.post('/cancel', requireAuth, asyncHandler(async (req, res) => {
  const { reservation_id } = req.body;

  const existing = await pool.query(
    "SELECT person_id FROM reservations WHERE reservation_id = $1 AND status = 'confirmed'",
    [reservation_id]
  );
  if (existing.rows.length === 0) {
    return res.status(404).json({ success: false, message: "존재하지 않는 예약입니다." });
  }
  const ownerId = existing.rows[0].person_id;
  if (req.user.role !== 'admin' && String(ownerId) !== String(req.user.person_id)) {
    return res.status(403).json({ success: false, message: "취소 권한이 없습니다." });
  }

  await pool.query(
    "UPDATE reservations SET status = 'cancelled' WHERE reservation_id = $1",
    [reservation_id]
  );
  res.json({ success: true, message: "예약이 취소되었습니다." });
}));

module.exports = router;
