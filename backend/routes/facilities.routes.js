const express = require('express');
const router = express.Router();
const pool = require('../db');
const asyncHandler = require('../middleware/asyncHandler');
const { requireAuth, requireAdmin } = require('../auth');
const { generateDaySlots, isDefaultOpen } = require('../slots');

// 6. 장소 목록 조회 (기본 정보만 - 예약 가능 여부는 availability API 사용)
// 기본적으로 비활성화(삭제)된 장소는 제외. 관리자가 관리 화면에서
// include_inactive=true 로 요청하면 비활성 장소도 함께 반환한다.
router.get('/', requireAuth, asyncHandler(async (req, res) => {
  const includeInactive = req.query.include_inactive === 'true' && req.user.role === 'admin';
  const query = includeInactive
    ? 'SELECT facility_id, name, icon_key, description, is_active, is_reservable FROM facilities ORDER BY facility_id'
    : 'SELECT facility_id, name, icon_key, description, is_active, is_reservable FROM facilities WHERE is_active = TRUE ORDER BY facility_id';
  const result = await pool.query(query);
  res.json(result.rows);
}));

// 6.1 새 장소 등록
router.post('/', requireAdmin, asyncHandler(async (req, res) => {
  const { name, icon_key, description } = req.body;
  if (!name || !name.trim()) {
    return res.status(400).json({ success: false, message: "장소 이름을 입력해주세요." });
  }
  const result = await pool.query(
    'INSERT INTO facilities (name, icon_key, description) VALUES ($1, $2, $3) RETURNING *',
    [name.trim(), icon_key || 'church', description || null]
  );
  res.status(201).json(result.rows[0]);
}));

// 6.2 장소 정보 수정
router.put('/:id', requireAdmin, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { name, icon_key, description } = req.body;
  if (!name || !name.trim()) {
    return res.status(400).json({ success: false, message: "장소 이름을 입력해주세요." });
  }
  const result = await pool.query(
    'UPDATE facilities SET name = $1, icon_key = $2, description = $3, updated_at = NOW() WHERE facility_id = $4 RETURNING *',
    [name.trim(), icon_key || 'church', description || null, id]
  );
  if (result.rows.length === 0) {
    return res.status(404).json({ success: false, message: "장소를 찾을 수 없습니다." });
  }
  res.json(result.rows[0]);
}));

// 6.3 장소 삭제 (소프트 삭제 - 예약 이력 보존, 성도용 목록에서만 제외)
router.delete('/:id', requireAdmin, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const result = await pool.query(
    'UPDATE facilities SET is_active = FALSE, updated_at = NOW() WHERE facility_id = $1 RETURNING facility_id',
    [id]
  );
  if (result.rows.length === 0) {
    return res.status(404).json({ success: false, message: "장소를 찾을 수 없습니다." });
  }
  res.json({ success: true, message: "장소가 삭제되었습니다." });
}));

// 6.35 장소의 예약 가능 여부 전환 (삭제와는 다름 - 목록엔 계속 보이되
// "예약 불가"로 표시된다). 이름/설명/아이콘을 다시 보낼 필요 없이 이 값만
// 바꿀 수 있도록 PUT과 분리된 전용 엔드포인트로 둔다.
router.post('/:id/toggle-reservable', requireAdmin, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { is_reservable } = req.body;
  const result = await pool.query(
    'UPDATE facilities SET is_reservable = $1, updated_at = NOW() WHERE facility_id = $2 RETURNING *',
    [Boolean(is_reservable), id]
  );
  if (result.rows.length === 0) {
    return res.status(404).json({ success: false, message: "장소를 찾을 수 없습니다." });
  }
  res.json(result.rows[0]);
}));

// 6.4 장소 복구 (실수로 삭제했을 때)
router.post('/:id/restore', requireAdmin, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const result = await pool.query(
    'UPDATE facilities SET is_active = TRUE, updated_at = NOW() WHERE facility_id = $1 RETURNING facility_id',
    [id]
  );
  if (result.rows.length === 0) {
    return res.status(404).json({ success: false, message: "장소를 찾을 수 없습니다." });
  }
  res.json({ success: true, message: "장소가 복구되었습니다." });
}));

// 6.1 특정 장소의 특정 날짜 30분 단위 예약 가능 현황 조회
// 기본값: 월-토 10:00-18:00 오픈, 일요일 마감 (관리자가 슬롯별로 재정의 가능)
router.get('/:id/availability', requireAuth, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { date } = req.query;

  if (!date || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return res.status(400).json({ error: "date 쿼리 파라미터가 필요합니다 (YYYY-MM-DD)." });
  }

  const defaultOpen = isDefaultOpen(date);

  const [facilityResult, overridesResult, reservationsResult, nowResult] = await Promise.all([
    pool.query('SELECT is_reservable FROM facilities WHERE facility_id = $1', [id]),
    pool.query(
      'SELECT slot_time, is_open FROM facility_availability_overrides WHERE facility_id = $1 AND override_date = $2',
      [id, date]
    ),
    pool.query(
      `SELECT reservation_id, person_id, start_time, end_time
       FROM reservations
       WHERE facility_id = $1 AND reservation_date = $2 AND status = 'confirmed'`,
      [id, date]
    ),
    pool.query(`SELECT CURRENT_DATE::text as today, CURRENT_TIME::text as now_time`),
  ]);

  if (facilityResult.rows.length === 0) {
    return res.status(404).json({ error: "장소를 찾을 수 없습니다." });
  }
  const isReservable = facilityResult.rows[0].is_reservable;

  const overrideMap = new Map(overridesResult.rows.map(r => [r.slot_time.slice(0, 5), r.is_open]));
  const reservations = reservationsResult.rows;
  const { today, now_time } = nowResult.rows[0];

  const slots = generateDaySlots().map(({ start, end }) => {
    const startHm = start.slice(0, 5);
    const isPast = date < today || (date === today && start <= now_time);
    const isOpen = overrideMap.has(startHm) ? overrideMap.get(startHm) : defaultOpen;
    const covering = reservations.find(r => start >= r.start_time && start < r.end_time);

    let status;
    if (!isReservable) status = 'closed'; // 장소 자체가 예약 비활성화된 경우 모든 슬롯을 닫힌 것으로 처리
    else if (isPast) status = 'past';
    else if (!isOpen) status = 'closed';
    else if (covering) status = String(covering.person_id) === String(req.user.person_id) ? 'mine' : 'booked';
    else status = 'available';

    return {
      start: startHm,
      end: end.slice(0, 5),
      status,
      reservation_id: covering ? covering.reservation_id : null,
    };
  });

  const myReservationToday = reservations.find(
    r => String(r.person_id) === String(req.user.person_id)
  );

  res.json({
    facility_id: Number(id),
    date,
    is_reservable: isReservable,
    slots,
    // 그날 같은 장소에 대해 이미 예약이 있는지 여부 (다른 날짜는 상관없음)
    my_active_reservation: myReservationToday
      ? { ...myReservationToday, reservation_date: date }
      : null,
  });
}));

// 8.1 관리자용 장소 예약 가능 슬롯 재정의 조회 (기본값 대비 관리자가 연/닫은 슬롯 확인)
router.get('/:id/overrides', requireAdmin, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { date } = req.query;
  if (!date || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return res.status(400).json({ error: "date 쿼리 파라미터가 필요합니다 (YYYY-MM-DD)." });
  }

  const defaultOpen = isDefaultOpen(date);
  const overridesResult = await pool.query(
    'SELECT slot_time, is_open FROM facility_availability_overrides WHERE facility_id = $1 AND override_date = $2',
    [id, date]
  );
  const overrideMap = new Map(overridesResult.rows.map(r => [r.slot_time.slice(0, 5), r.is_open]));

  const slots = generateDaySlots().map(({ start, end }) => {
    const hm = start.slice(0, 5);
    const hasOverride = overrideMap.has(hm);
    return {
      start: hm,
      end: end.slice(0, 5),
      default_open: defaultOpen,
      override: hasOverride ? overrideMap.get(hm) : null,
      effective_open: hasOverride ? overrideMap.get(hm) : defaultOpen,
    };
  });

  res.json({ facility_id: Number(id), date, slots });
}));

// 8.2 관리자용 장소 예약 가능 슬롯 재정의 저장 (여러 슬롯 일괄 저장, is_open=null이면 기본값으로 복원)
router.post('/:id/overrides', requireAdmin, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { date, slots } = req.body; // slots: [{ start_time: 'HH:MM', is_open: true|false|null }, ...]

  if (!date || !/^\d{4}-\d{2}-\d{2}$/.test(date) || !Array.isArray(slots)) {
    return res.status(400).json({ success: false, message: "요청 형식이 올바르지 않습니다." });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    for (const slot of slots) {
      const slotTime = `${slot.start_time}:00`;
      if (slot.is_open === null || slot.is_open === undefined) {
        await client.query(
          'DELETE FROM facility_availability_overrides WHERE facility_id = $1 AND override_date = $2 AND slot_time = $3',
          [id, date, slotTime]
        );
      } else {
        await client.query(
          `INSERT INTO facility_availability_overrides (facility_id, override_date, slot_time, is_open)
           VALUES ($1, $2, $3, $4)
           ON CONFLICT (facility_id, override_date, slot_time)
           DO UPDATE SET is_open = EXCLUDED.is_open`,
          [id, date, slotTime, slot.is_open]
        );
      }
    }
    await client.query('COMMIT');
    res.json({ success: true });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}));

module.exports = router;
