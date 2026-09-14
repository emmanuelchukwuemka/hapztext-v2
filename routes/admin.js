const router = require('express').Router();
const pool = require('../db');
const authMw = require('../middleware/auth');
const adminMw = require('../middleware/adminAuth');
const presence = require('../realtime/presence');

// Every route below requires a valid session AND is_admin = true.
router.use(authMw, adminMw);

router.get('/me', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, email, username FROM users WHERE id = $1', [req.user.id]);
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// ─── DASHBOARD STATS ──────────────────────────────────────────────────────────

const pctChange = (curr, prev) => {
  if (prev > 0) return Math.round(((curr - prev) / prev) * 1000) / 10;
  return curr > 0 ? 100 : 0;
};

router.get('/stats/overview', async (req, res) => {
  try {
    const q = (sql, params) => pool.query(sql, params).then((r) => r.rows[0].c);
    const [
      totalUsers, usersThis, usersPrev,
      totalPosts, postsThis, postsPrev,
      totalReports, reportsThis, reportsPrev,
      totalCalls, callsThis, callsPrev,
    ] = await Promise.all([
      q('SELECT COUNT(*)::int AS c FROM users'),
      q(`SELECT COUNT(*)::int AS c FROM users WHERE created_at >= date_trunc('month', NOW())`),
      q(`SELECT COUNT(*)::int AS c FROM users
         WHERE created_at >= date_trunc('month', NOW() - INTERVAL '1 month')
           AND created_at < date_trunc('month', NOW())`),
      q(`SELECT COUNT(*)::int AS c FROM posts WHERE is_published = TRUE`),
      q(`SELECT COUNT(*)::int AS c FROM posts WHERE is_published = TRUE AND created_at >= date_trunc('month', NOW())`),
      q(`SELECT COUNT(*)::int AS c FROM posts WHERE is_published = TRUE
           AND created_at >= date_trunc('month', NOW() - INTERVAL '1 month')
           AND created_at < date_trunc('month', NOW())`),
      q(`SELECT COUNT(*)::int AS c FROM content_reports`),
      q(`SELECT COUNT(*)::int AS c FROM content_reports WHERE created_at >= date_trunc('month', NOW())`),
      q(`SELECT COUNT(*)::int AS c FROM content_reports
           WHERE created_at >= date_trunc('month', NOW() - INTERVAL '1 month')
             AND created_at < date_trunc('month', NOW())`),
      q(`SELECT COUNT(*)::int AS c FROM calls`),
      q(`SELECT COUNT(*)::int AS c FROM calls WHERE started_at >= date_trunc('month', NOW())`),
      q(`SELECT COUNT(*)::int AS c FROM calls
           WHERE started_at >= date_trunc('month', NOW() - INTERVAL '1 month')
             AND started_at < date_trunc('month', NOW())`),
    ]);

    return res.json({
      data: {
        totalUsers, totalUsersChangePct: pctChange(usersThis, usersPrev),
        totalPosts, totalPostsChangePct: pctChange(postsThis, postsPrev),
        reportsReceived: totalReports, reportsChangePct: pctChange(reportsThis, reportsPrev),
        totalCalls, callsChangePct: pctChange(callsThis, callsPrev),
        activeNow: presence.getActiveUserCount(),
      },
    });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.get('/stats/user-growth', async (req, res) => {
  const days = Math.min(Math.max(parseInt(req.query.days, 10) || 30, 1), 365);
  try {
    const [dailyR, baseR] = await Promise.all([
      pool.query(
        `SELECT date_trunc('day', created_at)::date AS day, COUNT(*)::int AS count
         FROM users WHERE created_at >= NOW() - ($1 || ' days')::interval
         GROUP BY day`,
        [days]
      ),
      pool.query(
        `SELECT COUNT(*)::int AS c FROM users WHERE created_at < NOW() - ($1 || ' days')::interval`,
        [days]
      ),
    ]);
    const dayMap = new Map(dailyR.rows.map((r) => [r.day.toISOString().slice(0, 10), r.count]));
    let running = baseR.rows[0].c;
    const series = [];
    const today = new Date();
    for (let i = days - 1; i >= 0; i--) {
      const d = new Date(today);
      d.setUTCDate(d.getUTCDate() - i);
      const key = d.toISOString().slice(0, 10);
      running += dayMap.get(key) || 0;
      series.push({ date: key, total: running });
    }
    return res.json({ data: series });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.get('/stats/content-distribution', async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT post_format, COUNT(*)::int AS c FROM posts WHERE is_published = TRUE GROUP BY post_format`
    );
    return res.json({ data: r.rows.map((row) => ({ type: row.post_format, count: row.c })) });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.get('/stats/reports-by-type', async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT reason, COUNT(*)::int AS c FROM content_reports GROUP BY reason ORDER BY c DESC`
    );
    return res.json({ data: r.rows.map((row) => ({ reason: row.reason, count: row.c })) });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// ─── REPORTS ──────────────────────────────────────────────────────────────────

// Resolves who actually owns the reported content — the report's target_type
// determines which table target_id points into (no single FK covers all three).
async function resolveTarget(report) {
  try {
    if (report.target_type === 'user') {
      const r = await pool.query('SELECT username FROM users WHERE id = $1', [report.target_id]);
      return { username: r.rows[0]?.username || 'Unknown', contentType: report.content_type || 'profile' };
    }
    if (report.target_type === 'post') {
      const r = await pool.query(
        'SELECT sender_username, post_format FROM posts WHERE id = $1',
        [report.target_id]
      );
      return {
        username: r.rows[0]?.sender_username || 'Unknown',
        contentType: report.content_type || r.rows[0]?.post_format || 'post',
      };
    }
    if (report.target_type === 'message') {
      const r = await pool.query(
        `SELECT u.username FROM messages m JOIN users u ON u.id = m.sender_id WHERE m.id = $1`,
        [report.target_id]
      );
      return { username: r.rows[0]?.username || 'Unknown', contentType: report.content_type || 'message' };
    }
  } catch (e) {
    console.error('resolveTarget error:', e.message);
  }
  return { username: 'Unknown', contentType: report.content_type || 'other' };
}

router.get('/reports', async (req, res) => {
  const status = req.query.status || null;
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const pageSize = Math.min(Math.max(parseInt(req.query.pageSize, 10) || 20, 1), 100);
  try {
    const r = await pool.query(
      `SELECT cr.*, u.username AS reporter_username
       FROM content_reports cr
       JOIN users u ON u.id = cr.reporter_id
       WHERE ($1::text IS NULL OR cr.status = $1)
       ORDER BY cr.created_at DESC
       LIMIT $2 OFFSET $3`,
      [status, pageSize, (page - 1) * pageSize]
    );
    const countR = await pool.query(
      `SELECT COUNT(*)::int AS c FROM content_reports WHERE ($1::text IS NULL OR status = $1)`,
      [status]
    );
    const rows = await Promise.all(
      r.rows.map(async (row) => ({
        id: row.id,
        ...(await resolveTarget(row)),
        reason: row.reason,
        status: row.status,
        reporterUsername: row.reporter_username,
        createdAt: row.created_at,
        resolvedAt: row.resolved_at,
      }))
    );
    return res.json({ data: { result: rows, total: countR.rows[0].c, page, pageSize } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.put('/reports/:id', async (req, res) => {
  const { status } = req.body || {};
  const valid = ['pending', 'under_review', 'resolved', 'dismissed'];
  if (!valid.includes(status)) return res.status(400).json({ errors: { detail: 'Invalid status' } });
  try {
    const r = await pool.query(
      `UPDATE content_reports
       SET status = $1,
           resolved_by = CASE WHEN $1 IN ('resolved','dismissed') THEN $2::uuid ELSE NULL END,
           resolved_at = CASE WHEN $1 IN ('resolved','dismissed') THEN NOW() ELSE NULL END
       WHERE id = $3
       RETURNING *`,
      [status, req.user.id, req.params.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'Report not found' } });
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// ─── USERS ────────────────────────────────────────────────────────────────────

router.get('/users', async (req, res) => {
  const search = (req.query.search || '').trim();
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const pageSize = Math.min(Math.max(parseInt(req.query.pageSize, 10) || 20, 1), 100);
  try {
    const r = await pool.query(
      `SELECT u.id, u.email, u.username, u.created_at, u.is_admin, u.is_banned, u.banned_reason,
              p.location, p.profile_picture
       FROM users u
       LEFT JOIN profiles p ON p.user_id = u.id
       WHERE ($1 = '' OR u.username ILIKE '%' || $1 || '%' OR u.email ILIKE '%' || $1 || '%')
       ORDER BY u.created_at DESC
       LIMIT $2 OFFSET $3`,
      [search, pageSize, (page - 1) * pageSize]
    );
    const countR = await pool.query(
      `SELECT COUNT(*)::int AS c FROM users
       WHERE ($1 = '' OR username ILIKE '%' || $1 || '%' OR email ILIKE '%' || $1 || '%')`,
      [search]
    );
    return res.json({ data: { result: r.rows, total: countR.rows[0].c, page, pageSize } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.get('/users/:id', async (req, res) => {
  try {
    const [userR, postsR, reportsR] = await Promise.all([
      pool.query(
        `SELECT u.id, u.email, u.username, u.created_at, u.is_admin, u.is_banned, u.banned_at, u.banned_reason,
                p.first_name, p.last_name, p.bio, p.location, p.profile_picture
         FROM users u LEFT JOIN profiles p ON p.user_id = u.id WHERE u.id = $1`,
        [req.params.id]
      ),
      pool.query(`SELECT COUNT(*)::int AS c FROM posts WHERE sender_id = $1`, [req.params.id]),
      pool.query(
        `SELECT COUNT(*)::int AS c FROM content_reports WHERE target_type = 'user' AND target_id = $1`,
        [req.params.id]
      ),
    ]);
    if (!userR.rows.length) return res.status(404).json({ errors: { detail: 'User not found' } });
    return res.json({
      data: { ...userR.rows[0], postCount: postsR.rows[0].c, reportsAgainst: reportsR.rows[0].c },
    });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.put('/users/:id/ban', async (req, res) => {
  const { reason } = req.body || {};
  try {
    const r = await pool.query(
      `UPDATE users SET is_banned = TRUE, banned_at = NOW(), banned_reason = $1 WHERE id = $2 RETURNING id, is_banned`,
      [reason || null, req.params.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'User not found' } });
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.put('/users/:id/unban', async (req, res) => {
  try {
    const r = await pool.query(
      `UPDATE users SET is_banned = FALSE, banned_at = NULL, banned_reason = NULL WHERE id = $1 RETURNING id, is_banned`,
      [req.params.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'User not found' } });
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// ─── CALLS ────────────────────────────────────────────────────────────────────

router.get('/calls/recent', async (req, res) => {
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
  try {
    const r = await pool.query(
      `SELECT c.id, c.call_type, c.is_discover, c.status, c.started_at, c.connected_at, c.ended_at,
              cu.username AS caller_username, ce.username AS callee_username
       FROM calls c
       JOIN users cu ON cu.id = c.caller_id
       LEFT JOIN users ce ON ce.id = c.callee_id
       ORDER BY c.started_at DESC
       LIMIT $1`,
      [limit]
    );
    return res.json({ data: r.rows });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.get('/calls/live', async (req, res) => {
  try {
    const live = presence.getLiveCalls();
    const ids = [...new Set(live.flatMap((c) => [c.callerId, c.calleeId]).filter(Boolean))];
    let usernames = {};
    if (ids.length) {
      const r = await pool.query(`SELECT id, username FROM users WHERE id = ANY($1::uuid[])`, [ids]);
      usernames = Object.fromEntries(r.rows.map((row) => [row.id, row.username]));
    }
    return res.json({
      data: live.map((c) => ({
        ...c,
        callerUsername: usernames[c.callerId] || 'Unknown',
        calleeUsername: usernames[c.calleeId] || 'Unknown',
      })),
    });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

module.exports = router;
