const express = require('express');
const router = express.Router();
const pool = require('../db');
const asyncHandler = require('../middleware/asyncHandler');

// 3.1 UI 메타데이터 조회 (라이프팀 리스트, 직분 리스트 등 하드코딩 방지)
router.get('/', asyncHandler(async (req, res) => {
  // 두 조회를 순차 실행하지 않고 병렬로 실행 - 서로 의존성이 없음
  const [lifeTeams, titles] = await Promise.all([
    pool.query('SELECT DISTINCT life_team FROM members WHERE life_team IS NOT NULL'),
    pool.query('SELECT DISTINCT church_title FROM members WHERE church_title IS NOT NULL'),
  ]);

  res.json({
    lifeTeams: lifeTeams.rows.map(r => r.life_team),
    titles: titles.rows.map(r => r.church_title),
  });
}));

module.exports = router;
