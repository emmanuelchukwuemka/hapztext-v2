const pool = require('../db');

// Runs after the normal auth middleware (needs req.user.id already set) —
// looks up admin status fresh from the DB on every request rather than
// trusting a flag baked into the JWT, so revoking admin access takes effect
// immediately instead of waiting for the token to expire. Also attaches the
// role/permissions so route-level requirePermission() checks below can work.
module.exports = async (req, res, next) => {
  try {
    const r = await pool.query(
      'SELECT is_admin, admin_role, admin_permissions FROM users WHERE id = $1',
      [req.user.id]
    );
    if (!r.rows.length || r.rows[0].is_admin !== true) {
      return res.status(403).json({ errors: { detail: 'Admin access required' } });
    }
    req.admin = {
      role: r.rows[0].admin_role || 'staff',
      permissions: r.rows[0].admin_permissions || {},
    };
    next();
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
};

// A Master Admin bypasses individual flags (matches the doc's "Full Access —
// only Master" preset); everyone else needs the specific flag set to true.
// Never trust the frontend for this — it only hides buttons.
module.exports.requirePermission = function requirePermission(flag) {
  return (req, res, next) => {
    if (req.admin?.role === 'master') return next();
    if (req.admin?.permissions?.[flag] === true) return next();
    return res.status(403).json({
      errors: { detail: `You don't have permission for this action`, code: 'FORBIDDEN_PERMISSION' },
    });
  };
};
