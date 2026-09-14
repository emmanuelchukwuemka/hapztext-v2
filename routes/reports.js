const router = require('express').Router();
const pool = require('../db');
const authMw = require('../middleware/auth');

const VALID_TARGET_TYPES = ['post', 'user', 'message'];
const VALID_REASONS = ['spam', 'harassment', 'nudity', 'hate_speech', 'violence', 'other'];

// POST /reports — any authenticated user reporting a post, user, or message.
// Feeds the admin panel's moderation queue (routes/admin.js) — nothing here
// requires admin rights, this is the citizen side of that same table.
router.post('/', authMw, async (req, res) => {
  const { targetType, targetId, reason, details, contentType } = req.body || {};
  if (!VALID_TARGET_TYPES.includes(targetType) || !targetId || !VALID_REASONS.includes(reason)) {
    return res.status(400).json({
      errors: { detail: `targetType (${VALID_TARGET_TYPES.join('/')}), targetId, and a valid reason (${VALID_REASONS.join('/')}) are required` },
    });
  }
  try {
    const r = await pool.query(
      `INSERT INTO content_reports (reporter_id, target_type, target_id, content_type, reason, details)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [req.user.id, targetType, targetId, contentType || null, reason, details || null]
    );
    return res.status(200).json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

module.exports = router;
