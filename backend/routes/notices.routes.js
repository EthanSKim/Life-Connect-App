const express = require('express');
const router = express.Router();
const pool = require('../db');
const asyncHandler = require('../middleware/asyncHandler');
const { requireAuth, requireAdmin } = require('../auth');

// 1. 공지사항 목록 조회 (홈 화면 상위 4개, 전체보기 목록, 관리자 화면 모두 공용)
// - limit: 개수 제한 (홈 화면에서 ?limit=4로 사용)
// - include_inactive: 관리자가 삭제된 공지도 함께 보고 싶을 때 (관리자만 유효)
// - is_new: 게시 후 36시간 이내인지 여부
router.get('/', requireAuth, asyncHandler(async (req, res) => {
  const includeInactive = req.query.include_inactive === 'true' && req.user.role === 'admin';
  const limit = parseInt(req.query.limit, 10);

  let query = `
    SELECT
      notice_id, title, content,
      TO_CHAR(created_at, 'YYYY-MM-DD') as date,
      created_at, is_active,
      (created_at >= NOW() - INTERVAL '36 hours') as is_new
    FROM notices
    ${includeInactive ? '' : 'WHERE is_active = true'}
    ORDER BY created_at DESC
  `;
  if (Number.isInteger(limit) && limit > 0) {
    query += ` LIMIT ${limit}`;
  }

  const result = await pool.query(query);
  res.json(result.rows);
}));

// 2. 새 공지사항 등록
router.post('/', requireAdmin, asyncHandler(async (req, res) => {
  const { title, content } = req.body;
  if (!title || !title.trim()) {
    return res.status(400).json({ success: false, message: "제목을 입력해주세요." });
  }
  const result = await pool.query(
    'INSERT INTO notices (title, content) VALUES ($1, $2) RETURNING *',
    [title.trim(), content || null]
  );
  res.status(201).json(result.rows[0]);
}));

// 3. 공지사항 수정
router.put('/:id', requireAdmin, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { title, content } = req.body;
  if (!title || !title.trim()) {
    return res.status(400).json({ success: false, message: "제목을 입력해주세요." });
  }
  const result = await pool.query(
    'UPDATE notices SET title = $1, content = $2 WHERE notice_id = $3 RETURNING *',
    [title.trim(), content || null, id]
  );
  if (result.rows.length === 0) {
    return res.status(404).json({ success: false, message: "공지사항을 찾을 수 없습니다." });
  }
  res.json(result.rows[0]);
}));

// 4. 공지사항 삭제 (소프트 삭제 - 실수로 지웠을 때 복구할 수 있도록)
router.delete('/:id', requireAdmin, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const result = await pool.query(
    'UPDATE notices SET is_active = FALSE WHERE notice_id = $1 RETURNING notice_id',
    [id]
  );
  if (result.rows.length === 0) {
    return res.status(404).json({ success: false, message: "공지사항을 찾을 수 없습니다." });
  }
  res.json({ success: true, message: "공지사항이 삭제되었습니다." });
}));

// 5. 공지사항 복구
router.post('/:id/restore', requireAdmin, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const result = await pool.query(
    'UPDATE notices SET is_active = TRUE WHERE notice_id = $1 RETURNING notice_id',
    [id]
  );
  if (result.rows.length === 0) {
    return res.status(404).json({ success: false, message: "공지사항을 찾을 수 없습니다." });
  }
  res.json({ success: true, message: "공지사항이 복구되었습니다." });
}));

module.exports = router;
