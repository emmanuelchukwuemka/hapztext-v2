const router = require('express').Router();
const pool = require('../db');
const authMw = require('../middleware/auth');

// GET /profiles/me
router.get('/me', authMw, async (req, res) => {
  try {
    const [ur, pr] = await Promise.all([
      pool.query('SELECT id, email, username FROM users WHERE id = $1', [req.user.id]),
      pool.query('SELECT * FROM profiles WHERE user_id = $1', [req.user.id]),
    ]);
    const user = ur.rows[0] || {};
    const profile = pr.rows[0] || {};
    return res.json({ data: { id: user.id, email: user.email, username: user.username, profile } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// PUT /profiles/me
router.put('/me', authMw, async (req, res) => {
  const allowed = [
    'first_name', 'last_name', 'bio', 'occupation', 'location',
    'height', 'weight', 'birth_date', 'ethnicity', 'relationship_status',
    'gender', 'profile_picture', 'cover_picture', 'username',
  ];
  const updates = [];
  const values = [];
  let idx = 1;
  for (const f of allowed) {
    if (req.body[f] !== undefined) {
      updates.push(`${f} = $${idx++}`);
      values.push(req.body[f]);
    }
  }
  if (updates.length === 0) {
    const r = await pool.query('SELECT * FROM profiles WHERE user_id = $1', [req.user.id]);
    return res.json({ data: r.rows[0] || {} });
  }
  values.push(req.user.id);
  try {
    const r = await pool.query(
      `UPDATE profiles SET ${updates.join(', ')}, updated_at = NOW() WHERE user_id = $${idx} RETURNING *`,
      values
    );
    return res.json({ data: r.rows[0] || {} });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// GET /profiles/:userId
router.get('/:userId', authMw, async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM profiles WHERE user_id = $1', [req.params.userId]);
    return res.json({ data: r.rows[0] || { user_id: req.params.userId } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

module.exports = router;
