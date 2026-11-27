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

// PUT /stickers/:id/share — submit your own sticker for the public feed.
// Goes into a pending-approval state; it won't show up for anyone else
// until an admin approves it (see routes/admin.js).
router.put('/:id/share', authMw, async (req, res) => {
  try {
    const r = await pool.query(
      'UPDATE stickers SET is_shared = TRUE, approved = FALSE WHERE id = $1 AND user_id = $2 RETURNING *',
      [req.params.id, req.user.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'Sticker not found' } });
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// GET /stickers/feed — public, approved, non-blurred stickers, excluding
// anything this viewer has personally hidden.
router.get('/feed', authMw, async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT s.* FROM stickers s
       LEFT JOIN sticker_hides h ON h.sticker_id = s.id AND h.user_id = $1
       WHERE s.is_shared = TRUE AND s.approved = TRUE AND s.is_blurred = FALSE AND h.sticker_id IS NULL
       ORDER BY s.created_at DESC`,
      [req.user.id]
    );
    return res.json({ data: { result: r.rows } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /stickers/:id/hide — remove a shared sticker from just this
// viewer's feed (does not affect the owner or anyone else).
router.post('/:id/hide', authMw, async (req, res) => {
  try {
    await pool.query(
      'INSERT INTO sticker_hides (sticker_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING',
      [req.params.id, req.user.id]
    );
    return res.json({ success: true });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

module.exports = router;
