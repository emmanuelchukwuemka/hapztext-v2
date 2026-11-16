const router = require('express').Router();
const pool = require('../db');
const authMw = require('../middleware/auth');

// GET /stickers/mine — this user's own created stickers, newest first.
router.get('/mine', authMw, async (req, res) => {
  try {
    const r = await pool.query(
      'SELECT * FROM stickers WHERE user_id = $1 ORDER BY created_at DESC',
      [req.user.id]
    );
    return res.json({ data: { result: r.rows } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /stickers — save a newly-cropped sticker (client already uploaded
// the cropped PNG to Cloudinary and just passes the URL).
router.post('/', authMw, async (req, res) => {
  const { imageUrl } = req.body || {};
  if (!imageUrl) return res.status(400).json({ errors: { detail: 'imageUrl is required' } });
  try {
    const r = await pool.query(
      'INSERT INTO stickers (user_id, image_url) VALUES ($1,$2) RETURNING *',
      [req.user.id, imageUrl]
    );
    return res.status(201).json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// DELETE /stickers/:id — only your own.
router.delete('/:id', authMw, async (req, res) => {
  try {
    const r = await pool.query(
      'DELETE FROM stickers WHERE id = $1 AND user_id = $2 RETURNING id',
      [req.params.id, req.user.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'Sticker not found' } });
    return res.json({ success: true });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

module.exports = router;
