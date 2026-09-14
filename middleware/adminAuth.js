const pool = require('../db');

// Runs after the normal auth middleware (needs req.user.id already set) —
// looks up is_admin fresh from the DB on every request rather than trusting
// a flag baked into the JWT, so revoking admin access takes effect
// immediately instead of waiting for the token to expire.
module.exports = async (req, res, next) => {
  try {
    const r = await pool.query('SELECT is_admin FROM users WHERE id = $1', [req.user.id]);
    if (!r.rows.length || r.rows[0].is_admin !== true) {
      return res.status(403).json({ errors: { detail: 'Admin access required' } });
    }
    next();
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
};
