const express = require('express');
const router = express.Router();
const pool = require('../db');
const asyncHandler = require('../middleware/asyncHandler');
const { requireAdmin } = require('../auth');

// life_teams가 source of truth이고, members.life_team은 화면에서 바로 읽기
// 위한 비정규화된 텍스트 사본이다. 이 파일에서만 두 곳을 함께 갱신해서
// 서로 어긋나지 않게 한다 (households 패턴과 동일).

// 1. 라이프팀 목록 조회 (카드에 필요한 리더 이름/인원 수까지 한 번에)
router.get('/', requireAdmin, asyncHandler(async (req, res) => {
  const result = await pool.query(`
    SELECT
      lt.life_team_id,
      lt.name,
      lt.leader_id,
      leader.first_name AS leader_first_name,
      leader.last_name AS leader_last_name,
      COUNT(m.person_id) AS member_count
    FROM life_teams lt
    LEFT JOIN members leader ON leader.person_id = lt.leader_id
    LEFT JOIN members m ON m.life_team_id = lt.life_team_id AND m.status != 'inactive'
    GROUP BY lt.life_team_id, lt.name, lt.leader_id, leader.first_name, leader.last_name
    ORDER BY lt.name
  `);
  res.json(result.rows);
}));

// 2. 새 라이프팀 등록
router.post('/', requireAdmin, asyncHandler(async (req, res) => {
  const { name } = req.body;
  if (!name || !name.trim()) {
    return res.status(400).json({ success: false, message: "라이프팀 이름을 입력해주세요." });
  }
  try {
    const result = await pool.query(
      'INSERT INTO life_teams (life_team_id, name) VALUES ($1, $2) RETURNING *',
      [Date.now(), name.trim()]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505') { // unique_violation on name
      return res.status(409).json({ success: false, message: "이미 존재하는 라이프팀 이름입니다." });
    }
    throw err;
  }
}));

// 3. 라이프팀 상세 조회 (팀 정보 + 멤버 목록, 리더 표시 포함)
router.get('/:id', requireAdmin, asyncHandler(async (req, res) => {
  const { id } = req.params;

  const teamResult = await pool.query('SELECT * FROM life_teams WHERE life_team_id = $1', [id]);
  if (teamResult.rows.length === 0) {
    return res.status(404).json({ success: false, message: "라이프팀을 찾을 수 없습니다." });
  }

  const membersResult = await pool.query(
    `SELECT person_id, first_name, last_name, church_title
     FROM members WHERE life_team_id = $1 AND status != 'inactive'
     ORDER BY (person_id = $2) DESC, first_name`,
    [id, teamResult.rows[0].leader_id]
  );

  res.json({ team: teamResult.rows[0], members: membersResult.rows });
}));

// 4. 라이프팀 이름 변경 (비정규화된 members.life_team 텍스트도 함께 동기화)
router.put('/:id', requireAdmin, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { name } = req.body;
  if (!name || !name.trim()) {
    return res.status(400).json({ success: false, message: "라이프팀 이름을 입력해주세요." });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query(
      'UPDATE life_teams SET name = $1, updated_at = NOW() WHERE life_team_id = $2 RETURNING *',
      [name.trim(), id]
    );
    if (result.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, message: "라이프팀을 찾을 수 없습니다." });
    }
    await client.query('UPDATE members SET life_team = $1 WHERE life_team_id = $2', [name.trim(), id]);
    await client.query('COMMIT');
    res.json(result.rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    if (err.code === '23505') {
      return res.status(409).json({ success: false, message: "이미 존재하는 라이프팀 이름입니다." });
    }
    throw err;
  } finally {
    client.release();
  }
}));

// 5. 라이프팀 삭제 (팀원은 삭제되지 않고 소속만 해제된다)
router.delete('/:id', requireAdmin, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('UPDATE members SET life_team_id = NULL, life_team = NULL WHERE life_team_id = $1', [id]);
    const result = await client.query('DELETE FROM life_teams WHERE life_team_id = $1 RETURNING life_team_id', [id]);
    if (result.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, message: "라이프팀을 찾을 수 없습니다." });
    }
    await client.query('COMMIT');
    res.json({ success: true, message: "라이프팀이 삭제되었습니다." });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}));

// 6. 리더 지정/변경 (반드시 현재 그 팀의 멤버여야 함)
router.post('/:id/leader', requireAdmin, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { person_id } = req.body; // null이면 리더 해제

  if (person_id) {
    const memberCheck = await pool.query(
      'SELECT person_id FROM members WHERE person_id = $1::BIGINT AND life_team_id = $2',
      [person_id, id]
    );
    if (memberCheck.rows.length === 0) {
      return res.status(400).json({ success: false, message: "리더는 해당 팀의 멤버여야 합니다." });
    }
  }

  const result = await pool.query(
    'UPDATE life_teams SET leader_id = $1, updated_at = NOW() WHERE life_team_id = $2 RETURNING *',
    [person_id || null, id]
  );
  if (result.rows.length === 0) {
    return res.status(404).json({ success: false, message: "라이프팀을 찾을 수 없습니다." });
  }
  res.json(result.rows[0]);
}));

module.exports = router;
