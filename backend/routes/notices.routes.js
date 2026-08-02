const express = require('express');
const router = express.Router();
const pool = require('../db');
const asyncHandler = require('../middleware/asyncHandler');

// 5. 공지사항 조회 API (is_new 계산 포함)
router.get('/', asyncHandler(async (req, res) => {
  const query = `
    SELECT 
      title, 
      TO_CHAR(created_at, 'YYYY-MM-DD') as date,
      CASE WHEN created_at >= CURRENT_DATE - INTERVAL '7 days' THEN true ELSE false END as is_new
    FROM notices
    WHERE is_active = true
    ORDER BY created_at DESC;
  `;
  const result = await pool.query(query);
  res.json(result.rows);
}));

module.exports = router;
