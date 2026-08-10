const express = require('express');
const router = express.Router();
const pool = require('../db');
const asyncHandler = require('../middleware/asyncHandler');
const { requireAdmin } = require('../auth');

// household_name/is_primary_contact are denormalized onto members for cheap
// reads (existing screens read them straight off a member row). Every write
// to a household goes through this file so those copies can't drift from
// the households table, which stays the source of truth.

// 더 이상 아무도 속하지 않은 세대는 정리한다 (빈 세대가 계속 쌓이는 것을 방지).
async function cleanupIfEmpty(client, householdId) {
  if (!householdId) return;
  const remaining = await client.query(
    'SELECT COUNT(*) FROM members WHERE household_id = $1',
    [householdId]
  );
  if (Number(remaining.rows[0].count) === 0) {
    await client.query('DELETE FROM households WHERE household_id = $1', [householdId]);
  }
}

// 1. 세대 이름 변경 / 세대주 변경
router.put('/:id', requireAdmin, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { household_name, head_of_household_id } = req.body;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const existing = await client.query('SELECT * FROM households WHERE household_id = $1', [id]);
    if (existing.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, message: "세대를 찾을 수 없습니다." });
    }

    if (head_of_household_id !== undefined) {
      const memberCheck = await client.query(
        'SELECT person_id FROM members WHERE person_id = $1::BIGINT AND household_id = $2',
        [head_of_household_id, id]
      );
      if (memberCheck.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(400).json({ success: false, message: "세대주는 같은 세대에 속한 성도여야 합니다." });
      }
    }

    if (household_name !== undefined && !household_name.trim()) {
      await client.query('ROLLBACK');
      return res.status(400).json({ success: false, message: "세대 이름을 입력해주세요." });
    }

    const name = household_name ?? existing.rows[0].household_name;
    const headId = head_of_household_id !== undefined ? head_of_household_id : existing.rows[0].head_of_household_id;

    await client.query(
      'UPDATE households SET household_name = $1, head_of_household_id = $2, updated_at = NOW() WHERE household_id = $3',
      [name, headId, id]
    );
    // 비정규화된 사본 동기화
    await client.query('UPDATE members SET household_name = $1 WHERE household_id = $2', [name, id]);
    if (head_of_household_id !== undefined) {
      await client.query(
        'UPDATE members SET is_primary_contact = (person_id = $1::BIGINT) WHERE household_id = $2',
        [headId, id]
      );
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

// 2. 성도를 세대에 연결/이동/생성/분리
// - new_household_name 이 있으면: 새 세대를 만들고 그 성도를 배정한다.
// - household_id 가 있으면: 기존 세대에 배정한다.
// - 둘 다 없으면: 세대에서 분리한다 (소속 없음 상태로).
router.post('/link', requireAdmin, asyncHandler(async (req, res) => {
  const { person_id, household_id, new_household_name, relationship_to_head, is_head } = req.body;

  if (!person_id) {
    return res.status(400).json({ success: false, message: "person_id가 필요합니다." });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const memberResult = await client.query(
      'SELECT household_id FROM members WHERE person_id = $1::BIGINT',
      [person_id]
    );
    if (memberResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, message: "성도를 찾을 수 없습니다." });
    }
    const previousHouseholdId = memberResult.rows[0].household_id;

    let targetHouseholdId = null;
    let targetHouseholdName = null;

    if (new_household_name) {
      targetHouseholdId = Date.now();
      targetHouseholdName = new_household_name;
      await client.query(
        'INSERT INTO households (household_id, household_name, head_of_household_id) VALUES ($1, $2, $3)',
        [targetHouseholdId, targetHouseholdName, is_head ? person_id : null]
      );
    } else if (household_id) {
      const householdResult = await client.query('SELECT * FROM households WHERE household_id = $1', [household_id]);
      if (householdResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ success: false, message: "세대를 찾을 수 없습니다." });
      }
      targetHouseholdId = household_id;
      targetHouseholdName = householdResult.rows[0].household_name;
      if (is_head) {
        await client.query(
          'UPDATE households SET head_of_household_id = $1::BIGINT, updated_at = NOW() WHERE household_id = $2',
          [person_id, targetHouseholdId]
        );
        // 세대 내 다른 사람의 세대주 표시는 해제 (아래에서 이 사람 것만 다시 TRUE로 설정)
        await client.query('UPDATE members SET is_primary_contact = FALSE WHERE household_id = $1', [targetHouseholdId]);
      }
    }
    // targetHouseholdId가 null이면 분리(detach) - household_id/household_name을 NULL로 설정

    await client.query(
      `UPDATE members SET
         household_id = $1, household_name = $2, relationship_to_head = $3,
         is_primary_contact = $4, updated_at = NOW()
       WHERE person_id = $5::BIGINT`,
      [targetHouseholdId, targetHouseholdName, targetHouseholdId ? (relationship_to_head || null) : null,
       Boolean(is_head) && targetHouseholdId !== null, person_id]
    );

    // 이전 세대에 남은 사람이 없으면 정리 (BIGINT는 pg에서 문자열로
    // 돌아오지만 targetHouseholdId는 경로에 따라 숫자(Date.now())일 수
    // 있으므로, 형변환 없이 비교하면 같은 세대인데도 다르다고 잘못
    // 판단할 수 있다 - 문자열로 정규화해서 비교한다.)
    if (previousHouseholdId && String(previousHouseholdId) !== String(targetHouseholdId)) {
      await client.query(
        'UPDATE households SET head_of_household_id = NULL WHERE household_id = $1 AND head_of_household_id = $2::BIGINT',
        [previousHouseholdId, person_id]
      );
      await cleanupIfEmpty(client, previousHouseholdId);
    }

    await client.query('COMMIT');
    res.json({ success: true, household_id: targetHouseholdId, household_name: targetHouseholdName });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}));

module.exports = router;
