const router = require('express').Router();
const pool = require('../db');
const authMw = require('../middleware/auth');

// GET /emojis — the chat composer's emoji picker. Replaces the old bundled
// asset list so admins can add/rename/blur/remove entries without a release.
router.get('/', authMw, async (req, res) => {
  try {
    const r = await pool.query(
      'SELECT id, name, image_url FROM emojis WHERE is_blurred = FALSE ORDER BY name ASC'
    );
    return res.json({ data: { result: r.rows } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

module.exports = router;
