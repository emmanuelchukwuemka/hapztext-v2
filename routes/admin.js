const router = require('express').Router();
const bcrypt = require('bcryptjs');
const pool = require('../db');
const authMw = require('../middleware/auth');
const adminMw = require('../middleware/adminAuth');
const { requirePermission } = require('../middleware/adminAuth');
const presence = require('../realtime/presence');

// Every route below requires a valid session AND is_admin = true.
router.use(authMw, adminMw);

// Every mutating action gets a row here — the doc's audit-log requirement.
// Fire-and-forget: an audit write failing must never block the actual action.
function logAudit(req, action, targetType, targetId, meta) {
  pool
    .query(
      `INSERT INTO admin_audit_logs (actor_id, actor_name, action, target_type, target_id, meta)
       VALUES ($1,$2,$3,$4,$5,$6)`,
      [req.user.id, req.admin?.username || null, action, targetType || null, String(targetId || ''), meta ? JSON.stringify(meta) : null]
    )
    .catch((e) => console.error('audit log error:', e.message));
}

router.get('/me', async (req, res) => {
  try {
    const r = await pool.query(
      'SELECT id, email, username, admin_role, admin_permissions FROM users WHERE id = $1',
      [req.user.id]
    );
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.get('/audit-log', requirePermission('staffManage'), async (req, res) => {
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const pageSize = Math.min(Math.max(parseInt(req.query.pageSize, 10) || 50, 1), 200);
  try {
    const r = await pool.query(
      `SELECT * FROM admin_audit_logs ORDER BY created_at DESC LIMIT $1 OFFSET $2`,
      [pageSize, (page - 1) * pageSize]
    );
    const countR = await pool.query(`SELECT COUNT(*)::int AS c FROM admin_audit_logs`);
    return res.json({ data: { result: r.rows, total: countR.rows[0].c, page, pageSize } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// ─── STAFF MANAGEMENT ───────────────────────────────────────────────────────
// Matches the permission flags actually enforced by requirePermission() below
// plus the full-access set schema.sql seeds for bootstrapped admins.
const ALL_PERMISSIONS = [
  'dashboardView',
  'reportsView', 'reportsIgnore', 'reportsWarn', 'reportsDelete',
  'usersView', 'usersWarn', 'usersSuspend', 'usersBan', 'usersLiftBan',
  'contentView', 'contentDelete',
  'trendingView', 'trendingBoost', 'trendingRemove',
  'callsView', 'callsEnd', 'callsRestrict',
  'settingsView', 'settingsEdit',
  'appealsView', 'appealsApprove', 'appealsDeny',
  'staffManage',
];

function sanitizePermissions(input) {
  const out = {};
  for (const key of ALL_PERMISSIONS) {
    if (input && input[key] === true) out[key] = true;
  }
  return out;
}

router.get('/staff', requirePermission('staffManage'), async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT id, email, username, admin_role, admin_permissions, created_at
       FROM users WHERE is_admin = TRUE ORDER BY created_at ASC`
    );
    return res.json({ data: r.rows });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// A staff member with staffManage can onboard other staff/auditors, but
// granting Master is restricted to an existing Master — that flag bypasses
// every permission check, so handing it out needs the strictest gate.
router.post('/staff', requirePermission('staffManage'), async (req, res) => {
  const { email, username, password, role } = req.body || {};
  const roleIn = role === 'master' || role === 'auditor' ? role : 'staff';
  if (roleIn === 'master' && req.admin.role !== 'master') {
    return res.status(403).json({ errors: { detail: 'Only a Master Admin can grant the Master role' } });
  }
  if (!email) return res.status(400).json({ errors: { detail: 'email is required' } });
  const permissions = sanitizePermissions(req.body?.permissions);
  try {
    const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email.toLowerCase().trim()]);
    let userId;
    if (existing.rows.length) {
      userId = existing.rows[0].id;
      await pool.query(
        `UPDATE users SET is_admin = TRUE, admin_role = $1, admin_permissions = $2 WHERE id = $3`,
        [roleIn, JSON.stringify(permissions), userId]
      );
    } else {
      if (!username || !password) {
        return res.status(400).json({ errors: { detail: 'username and password are required to create a new staff account' } });
      }
      const hash = await bcrypt.hash(password, 12);
      const r = await pool.query(
        `INSERT INTO users (email, username, password_hash, is_admin, admin_role, admin_permissions)
         VALUES ($1,$2,$3,TRUE,$4,$5) RETURNING id`,
        [email.toLowerCase().trim(), username.trim(), hash, roleIn, JSON.stringify(permissions)]
      );
      userId = r.rows[0].id;
    }
    logAudit(req, 'ADD_STAFF', 'user', userId, { email, role: roleIn });
    return res.json({ data: { id: userId } });
  } catch (e) {
    if (e.code === '23505') return res.status(400).json({ errors: { detail: 'Email or username already taken' } });
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.patch('/staff/:id', requirePermission('staffManage'), async (req, res) => {
  const role = req.body?.role;
  const roleIn = role === 'master' || role === 'auditor' ? role : 'staff';
  if (roleIn === 'master' && req.admin.role !== 'master') {
    return res.status(403).json({ errors: { detail: 'Only a Master Admin can grant the Master role' } });
  }
  try {
    const target = await pool.query('SELECT admin_role FROM users WHERE id = $1 AND is_admin = TRUE', [req.params.id]);
    if (!target.rows.length) return res.status(404).json({ errors: { detail: 'Staff member not found' } });
    if (target.rows[0].admin_role === 'master' && req.admin.role !== 'master') {
      return res.status(403).json({ errors: { detail: 'Only a Master Admin can modify another Master Admin' } });
    }
    const permissions = sanitizePermissions(req.body?.permissions);
    await pool.query(
      `UPDATE users SET admin_role = $1, admin_permissions = $2 WHERE id = $3`,
      [roleIn, JSON.stringify(permissions), req.params.id]
    );
    logAudit(req, 'UPDATE_STAFF', 'user', req.params.id, { role: roleIn });
    return res.json({ data: { updated: true } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.delete('/staff/:id', requirePermission('staffManage'), async (req, res) => {
  if (req.params.id === req.user.id) {
    return res.status(400).json({ errors: { detail: 'You cannot revoke your own admin access' } });
  }
  try {
    const target = await pool.query('SELECT admin_role FROM users WHERE id = $1 AND is_admin = TRUE', [req.params.id]);
    if (!target.rows.length) return res.status(404).json({ errors: { detail: 'Staff member not found' } });
    if (target.rows[0].admin_role === 'master' && req.admin.role !== 'master') {
      return res.status(403).json({ errors: { detail: 'Only a Master Admin can remove another Master Admin' } });
    }
    await pool.query(
      `UPDATE users SET is_admin = FALSE, admin_role = NULL, admin_permissions = '{}'::jsonb WHERE id = $1`,
      [req.params.id]
    );
    logAudit(req, 'REMOVE_STAFF', 'user', req.params.id);
    return res.json({ data: { removed: true } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// ─── DASHBOARD ────────────────────────────────────────────────────────────────

const pctChange = (curr, prev) => {
  if (prev > 0) return Math.round(((curr - prev) / prev) * 1000) / 10;
  return curr > 0 ? 100 : 0;
};

router.get('/stats/overview', requirePermission('dashboardView'), async (req, res) => {
  try {
    const q = (sql, params) => pool.query(sql, params).then((r) => r.rows[0].c);
    const [
      totalUsers, usersThis, usersPrev,
      totalPosts, postsThis, postsPrev,
      totalReports, reportsThis, reportsPrev,
      totalCalls, callsThis, callsPrev,
      pendingReports, bannedUsers, pendingAppeals,
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
      q(`SELECT COUNT(*)::int AS c FROM content_reports WHERE status = 'pending'`),
      q(`SELECT COUNT(*)::int AS c FROM users WHERE is_banned = TRUE`),
      q(`SELECT COUNT(*)::int AS c FROM appeals WHERE status = 'pending'`),
    ]);

    const live = presence.getLiveCalls();
    return res.json({
      data: {
        totalUsers, totalUsersChangePct: pctChange(usersThis, usersPrev),
        totalPosts, totalPostsChangePct: pctChange(postsThis, postsPrev),
        reportsReceived: totalReports, reportsChangePct: pctChange(reportsThis, reportsPrev),
        totalCalls, callsChangePct: pctChange(callsThis, callsPrev),
        activeNow: presence.getActiveUserCount(),
        pendingReports,
        pendingAppeals,
        bannedUsers,
        activeCalls: live.length,
        activeAgeAlerts: live.filter((c) => c.ageAlert).length,
      },
    });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.get('/stats/user-growth', requirePermission('dashboardView'), async (req, res) => {
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

router.get('/stats/content-distribution', requirePermission('dashboardView'), async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT post_format, COUNT(*)::int AS c FROM posts WHERE is_published = TRUE GROUP BY post_format`
    );
    return res.json({ data: r.rows.map((row) => ({ type: row.post_format, count: row.c })) });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.get('/stats/reports-by-type', requirePermission('dashboardView'), async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT reason, COUNT(*)::int AS c FROM content_reports GROUP BY reason ORDER BY c DESC`
    );
    return res.json({ data: r.rows.map((row) => ({ reason: row.reason, count: row.c })) });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// The doc's exact trending-score formula, computed live rather than via a
// separate cron job — always fresh, no stale trending_score column to drift.
const TRENDING_SCORE_SQL = `
  (p.like_count * 1 + COALESCE(pr.comment_count, 0) * 3 + p.share_count * 5 + p.trending_boost * 20)
  / GREATEST(EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 3600.0, 1)
`;

router.get('/dashboard/trending-top', requirePermission('dashboardView'), async (req, res) => {
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 5, 1), 50);
  try {
    const r = await pool.query(
      `SELECT p.id, p.sender_username, p.like_count, p.share_count,
              COALESCE(pr.comment_count, 0) AS comment_count,
              ${TRENDING_SCORE_SQL} AS score
       FROM posts p
       LEFT JOIN (SELECT post_id, COUNT(*)::int AS comment_count FROM post_reactions GROUP BY post_id) pr
              ON pr.post_id = p.id
       WHERE p.is_published = TRUE AND p.trending_excluded = FALSE
       ORDER BY score DESC LIMIT $1`,
      [limit]
    );
    return res.json({ data: r.rows.map((row) => ({ ...row, score: Math.round(row.score) })) });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// ─── REPORTS ──────────────────────────────────────────────────────────────────

async function resolveTarget(report) {
  try {
    if (report.target_type === 'user') {
      const r = await pool.query('SELECT username FROM users WHERE id = $1', [report.target_id]);
      return { username: r.rows[0]?.username || 'Unknown', contentType: report.content_type || 'profile' };
    }
    if (report.target_type === 'post') {
      const r = await pool.query('SELECT sender_username, post_format FROM posts WHERE id = $1', [report.target_id]);
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
    if (report.target_type === 'call') {
      const r = await pool.query(
        `SELECT cu.username FROM calls c JOIN users cu ON cu.id = c.caller_id WHERE c.id = $1`,
        [report.target_id]
      );
      return { username: r.rows[0]?.username || 'Unknown', contentType: report.content_type || 'random_call' };
    }
  } catch (e) {
    console.error('resolveTarget error:', e.message);
  }
  return { username: 'Unknown', contentType: report.content_type || 'other' };
}

// Matches user-content against banned_words/violation_rules live — an
// "auto-detected" callout without needing to intercept every post-creation
// endpoint separately.
async function computeAutoFlags(text) {
  if (!text) return [];
  const flags = [];
  try {
    const [wordsR, rulesR] = await Promise.all([
      pool.query('SELECT word FROM banned_words'),
      pool.query('SELECT name, pattern FROM violation_rules WHERE enabled = TRUE'),
    ]);
    const lower = text.toLowerCase();
    for (const { word } of wordsR.rows) {
      if (lower.includes(word.toLowerCase())) flags.push(`banned word: "${word}"`);
    }
    for (const { name, pattern } of rulesR.rows) {
      try {
        if (new RegExp(pattern, 'i').test(text)) flags.push(name);
      } catch (_) {} // an admin-authored bad regex must never crash the request
    }
  } catch (e) {
    console.error('computeAutoFlags error:', e.message);
  }
  return flags;
}

router.get('/reports', requirePermission('reportsView'), async (req, res) => {
  const status = req.query.status || null;
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const pageSize = Math.min(Math.max(parseInt(req.query.pageSize, 10) || 20, 1), 100);
  try {
    const r = await pool.query(
      `SELECT cr.*, u.username AS reporter_username,
              (SELECT COUNT(*)::int FROM content_reports cr2
                WHERE cr2.target_type = cr.target_type AND cr2.target_id = cr.target_id) AS total_reporters
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
        details: row.details,
        status: row.status,
        reporterUsername: row.reporter_username,
        totalReporters: row.total_reporters,
        autoFlags: await computeAutoFlags(row.details),
        createdAt: row.created_at,
        resolvedAt: row.resolved_at,
        targetType: row.target_type,
        targetId: row.target_id,
      }))
    );
    return res.json({ data: { result: rows, total: countR.rows[0].c, page, pageSize } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.get('/reports/:id/media', requirePermission('reportsView'), async (req, res) => {
  try {
    const r = await pool.query('SELECT target_type, target_id FROM content_reports WHERE id = $1', [req.params.id]);
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'Report not found' } });
    const { target_type, target_id } = r.rows[0];
    if (target_type !== 'post') return res.json({ data: { mediaUrl: null } });
    const p = await pool.query(
      'SELECT image_content, video_content, audio_content FROM posts WHERE id = $1',
      [target_id]
    );
    const row = p.rows[0] || {};
    let mediaUrl = row.image_content || row.video_content || row.audio_content || null;
    // Image posts store their URL in media_files, not posts.image_content — see /content above.
    if (!mediaUrl) {
      const mr = await pool.query(
        'SELECT image_file, video_file, audio_file FROM media_files WHERE post_id = $1 ORDER BY created_at LIMIT 1',
        [target_id]
      );
      const m = mr.rows[0] || {};
      mediaUrl = m.image_file || m.video_file || m.audio_file || null;
    }
    return res.json({ data: { mediaUrl } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.post('/reports/:id/ignore', requirePermission('reportsIgnore'), async (req, res) => {
  try {
    const r = await pool.query(
      `UPDATE content_reports SET status = 'dismissed', resolved_by = $1, resolved_at = NOW() WHERE id = $2 RETURNING *`,
      [req.user.id, req.params.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'Report not found' } });
    logAudit(req, 'IGNORE_REPORT', 'report', req.params.id);
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.post('/reports/:id/warn', requirePermission('reportsWarn'), async (req, res) => {
  try {
    const reportR = await pool.query('SELECT * FROM content_reports WHERE id = $1', [req.params.id]);
    if (!reportR.rows.length) return res.status(404).json({ errors: { detail: 'Report not found' } });
    const report = reportR.rows[0];
    const { username } = await resolveTarget(report);

    let targetUserId = report.target_type === 'user' ? report.target_id : null;
    if (report.target_type === 'post') {
      const p = await pool.query('SELECT sender_id FROM posts WHERE id = $1', [report.target_id]);
      targetUserId = p.rows[0]?.sender_id || null;
    }
    if (targetUserId) {
      await pool.query('UPDATE users SET warnings_count = warnings_count + 1 WHERE id = $1', [targetUserId]);
    }
    await pool.query(
      `UPDATE content_reports SET status = 'resolved', resolved_by = $1, resolved_at = NOW() WHERE id = $2`,
      [req.user.id, req.params.id]
    );
    logAudit(req, 'WARN_FROM_REPORT', 'report', req.params.id, { targetUserId, username });
    return res.json({ data: { warned: username, targetUserId } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// Kept for the dashboard's quick status dropdown (pending/under_review/
// resolved/dismissed) alongside the doc's more specific ignore/warn actions.
router.put('/reports/:id', requirePermission('reportsView'), async (req, res) => {
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
    logAudit(req, 'UPDATE_REPORT_STATUS', 'report', req.params.id, { status });
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// Top-level per the doc (DELETE /v1/admin/posts/:postId), reachable from a
// report's "Delete Post" action or the Content page.
router.delete('/posts/:id', requirePermission('reportsDelete'), async (req, res) => {
  try {
    const r = await pool.query('DELETE FROM posts WHERE id = $1 RETURNING id', [req.params.id]);
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'Post not found' } });
    logAudit(req, 'DELETE_POST', 'post', req.params.id);
    return res.json({ data: { deleted: true } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.post('/posts/:id/boost', requirePermission('trendingBoost'), async (req, res) => {
  try {
    const r = await pool.query(
      'UPDATE posts SET trending_boost = trending_boost + 1 WHERE id = $1 RETURNING id, trending_boost',
      [req.params.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'Post not found' } });
    logAudit(req, 'BOOST_POST', 'post', req.params.id);
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// ─── CONTENT ──────────────────────────────────────────────────────────────────

router.get('/content', requirePermission('contentView'), async (req, res) => {
  const type = req.query.type || null; // 'text' | 'image' | 'video' | 'audio'
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const pageSize = Math.min(Math.max(parseInt(req.query.pageSize, 10) || 24, 1), 100);
  try {
    const r = await pool.query(
      `SELECT id, sender_username, post_format, text_content, image_content, video_content, audio_content,
              like_count, share_count, created_at
       FROM posts
       WHERE is_published = TRUE AND ($1::text IS NULL OR post_format = $1)
       ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
      [type, pageSize, (page - 1) * pageSize]
    );
    const countR = await pool.query(
      `SELECT COUNT(*)::int AS c FROM posts WHERE is_published = TRUE AND ($1::text IS NULL OR post_format = $1)`,
      [type]
    );
    // Image posts (unlike video/audio) never write posts.image_content — the
    // upload route only stores their URLs in media_files, one row per image,
    // to support multi-image carousels. Merge those in so the admin panel
    // actually has something to render.
    const ids = r.rows.map((row) => row.id);
    const imagesByPost = {};
    if (ids.length) {
      const mediaR = await pool.query(
        `SELECT post_id, image_file FROM media_files
         WHERE post_id = ANY($1) AND image_file IS NOT NULL ORDER BY created_at`,
        [ids]
      );
      for (const { post_id, image_file } of mediaR.rows) {
        (imagesByPost[post_id] || (imagesByPost[post_id] = [])).push(image_file);
      }
    }
    const result = r.rows.map((row) => ({
      ...row,
      image_content: row.image_content || imagesByPost[row.id]?.[0] || null,
      image_files: imagesByPost[row.id] || (row.image_content ? [row.image_content] : []),
    }));
    return res.json({ data: { result, total: countR.rows[0].c, page, pageSize } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// ─── TRENDING ─────────────────────────────────────────────────────────────────

router.get('/trending', requirePermission('trendingView'), async (req, res) => {
  const period = req.query.period || '24h'; // '24h' | '7d' | '30d'
  const hours = period === '30d' ? 24 * 30 : period === '7d' ? 24 * 7 : 24;
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
  try {
    const r = await pool.query(
      `SELECT p.id, p.sender_username, p.post_format, p.like_count, p.share_count,
              COALESCE(pr.comment_count, 0) AS comment_count,
              ${TRENDING_SCORE_SQL} AS score, p.created_at
       FROM posts p
       LEFT JOIN (SELECT post_id, COUNT(*)::int AS comment_count FROM post_reactions GROUP BY post_id) pr
              ON pr.post_id = p.id
       WHERE p.is_published = TRUE AND p.trending_excluded = FALSE
         AND p.created_at >= NOW() - ($1 || ' hours')::interval
       ORDER BY score DESC LIMIT $2`,
      [hours, limit]
    );
    return res.json({ data: r.rows.map((row) => ({ ...row, score: Math.round(row.score) })) });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.post('/trending/:postId/remove', requirePermission('trendingRemove'), async (req, res) => {
  try {
    const r = await pool.query(
      'UPDATE posts SET trending_excluded = TRUE WHERE id = $1 RETURNING id',
      [req.params.postId]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'Post not found' } });
    logAudit(req, 'REMOVE_FROM_TRENDING', 'post', req.params.postId);
    return res.json({ data: { removed: true } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// ─── USERS ────────────────────────────────────────────────────────────────────

router.get('/users', requirePermission('usersView'), async (req, res) => {
  const search = (req.query.search || '').trim();
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const pageSize = Math.min(Math.max(parseInt(req.query.pageSize, 10) || 20, 1), 100);
  try {
    const r = await pool.query(
      `SELECT u.id, u.email, u.username, u.created_at, u.is_admin, u.is_banned, u.banned_reason,
              u.ban_expires_at, u.warnings_count, u.calls_restricted, u.calls_watched,
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

router.get('/users/flagged', requirePermission('callsView'), async (req, res) => {
  try {
    const r = await pool.query(`
      WITH call_counts AS (
        SELECT user_id, COUNT(*)::int AS total_calls FROM (
          SELECT caller_id AS user_id FROM calls
          UNION ALL
          SELECT callee_id AS user_id FROM calls WHERE callee_id IS NOT NULL
        ) x GROUP BY user_id
      ),
      report_counts AS (
        SELECT target_id::uuid AS user_id, COUNT(*)::int AS reports_received
        FROM content_reports WHERE target_type = 'user' GROUP BY target_id
      )
      SELECT u.id AS user_id, u.username, u.calls_watched,
             COALESCE(cc.total_calls, 0) AS total_calls,
             COALESCE(rc.reports_received, 0) AS reports_received
      FROM users u
      JOIN report_counts rc ON rc.user_id = u.id
      LEFT JOIN call_counts cc ON cc.user_id = u.id
      WHERE rc.reports_received > 0
      ORDER BY rc.reports_received DESC
      LIMIT 50
    `);
    const rows = r.rows.map((row) => {
      const rate = row.total_calls > 0 ? (row.reports_received / row.total_calls) * 100 : 100;
      return {
        userId: row.user_id,
        username: row.username,
        totalCalls: row.total_calls,
        reportsReceived: row.reports_received,
        reportRate: `${rate.toFixed(1)}%`,
        status: rate >= 15 ? 'High Risk' : 'Watching',
        watched: row.calls_watched,
      };
    });
    return res.json({ data: rows });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.get('/users/:id', requirePermission('usersView'), async (req, res) => {
  try {
    const [userR, postsR, reportsR, violationsR] = await Promise.all([
      pool.query(
        `SELECT u.id, u.email, u.username, u.created_at, u.is_admin, u.is_banned, u.banned_at, u.banned_reason,
                u.ban_expires_at, u.warnings_count, u.calls_restricted, u.calls_watched,
                p.first_name, p.last_name, p.bio, p.location, p.profile_picture
         FROM users u LEFT JOIN profiles p ON p.user_id = u.id WHERE u.id = $1`,
        [req.params.id]
      ),
      pool.query(`SELECT COUNT(*)::int AS c FROM posts WHERE sender_id = $1`, [req.params.id]),
      pool.query(
        `SELECT COUNT(*)::int AS c FROM content_reports WHERE target_type = 'user' AND target_id = $1`,
        [req.params.id]
      ),
      pool.query(
        `SELECT reason, status, created_at FROM content_reports
         WHERE target_type = 'user' AND target_id = $1 ORDER BY created_at DESC LIMIT 10`,
        [req.params.id]
      ),
    ]);
    if (!userR.rows.length) return res.status(404).json({ errors: { detail: 'User not found' } });
    return res.json({
      data: {
        ...userR.rows[0],
        postCount: postsR.rows[0].c,
        reportsAgainst: reportsR.rows[0].c,
        violations: violationsR.rows,
      },
    });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.post('/users/:id/warn', requirePermission('usersWarn'), async (req, res) => {
  try {
    const r = await pool.query(
      'UPDATE users SET warnings_count = warnings_count + 1 WHERE id = $1 RETURNING id, warnings_count',
      [req.params.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'User not found' } });
    logAudit(req, 'WARN_USER', 'user', req.params.id);
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.post('/users/:id/suspend', requirePermission('usersSuspend'), async (req, res) => {
  const days = parseInt(req.body?.days, 10);
  const reason = req.body?.reason || null;
  if (!days || days <= 0) return res.status(400).json({ errors: { detail: 'days (a positive integer) is required' } });
  try {
    const r = await pool.query(
      `UPDATE users
       SET is_banned = TRUE, banned_at = NOW(), banned_reason = $1, ban_expires_at = NOW() + ($2 || ' days')::interval
       WHERE id = $3 RETURNING id, is_banned, ban_expires_at`,
      [reason, days, req.params.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'User not found' } });
    logAudit(req, 'SUSPEND_USER', 'user', req.params.id, { days, reason });
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.post('/users/:id/ban', requirePermission('usersBan'), async (req, res) => {
  const { reason } = req.body || {};
  try {
    const r = await pool.query(
      `UPDATE users SET is_banned = TRUE, banned_at = NOW(), banned_reason = $1, ban_expires_at = NULL
       WHERE id = $2 RETURNING id, is_banned`,
      [reason || null, req.params.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'User not found' } });
    logAudit(req, 'BAN_USER', 'user', req.params.id, { reason });
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.post('/users/:id/lift-ban', requirePermission('usersLiftBan'), async (req, res) => {
  try {
    const r = await pool.query(
      `UPDATE users SET is_banned = FALSE, banned_at = NULL, banned_reason = NULL, ban_expires_at = NULL
       WHERE id = $1 RETURNING id, is_banned`,
      [req.params.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'User not found' } });
    logAudit(req, 'LIFT_BAN', 'user', req.params.id);
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// Kept as plain duplicates (not a Router#handle re-dispatch — that's not
// meant to be called recursively) so anything already wired to the earlier
// PUT-based paths keeps working while the frontend moves to the doc's POST
// paths above.
router.put('/users/:id/ban', requirePermission('usersBan'), async (req, res) => {
  const { reason } = req.body || {};
  try {
    const r = await pool.query(
      `UPDATE users SET is_banned = TRUE, banned_at = NOW(), banned_reason = $1, ban_expires_at = NULL
       WHERE id = $2 RETURNING id, is_banned`,
      [reason || null, req.params.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'User not found' } });
    logAudit(req, 'BAN_USER', 'user', req.params.id, { reason });
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});
router.put('/users/:id/unban', requirePermission('usersLiftBan'), async (req, res) => {
  try {
    const r = await pool.query(
      `UPDATE users SET is_banned = FALSE, banned_at = NULL, banned_reason = NULL, ban_expires_at = NULL
       WHERE id = $1 RETURNING id, is_banned`,
      [req.params.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'User not found' } });
    logAudit(req, 'LIFT_BAN', 'user', req.params.id);
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.post('/users/:id/restrict-random-calls', requirePermission('callsRestrict'), async (req, res) => {
  try {
    const r = await pool.query(
      'UPDATE users SET calls_restricted = TRUE WHERE id = $1 RETURNING id, calls_restricted',
      [req.params.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'User not found' } });
    logAudit(req, 'RESTRICT_RANDOM_CALLS', 'user', req.params.id);
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.post('/users/:id/watch-calls', requirePermission('callsRestrict'), async (req, res) => {
  try {
    const r = await pool.query(
      'UPDATE users SET calls_watched = TRUE WHERE id = $1 RETURNING id, calls_watched',
      [req.params.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'User not found' } });
    logAudit(req, 'WATCH_USER_CALLS', 'user', req.params.id);
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// ─── RANDOM CALLS ─────────────────────────────────────────────────────────────

router.get('/calls/active', requirePermission('callsView'), async (req, res) => {
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

router.get('/calls/history', requirePermission('callsView'), async (req, res) => {
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
  try {
    const r = await pool.query(
      `SELECT c.id, c.call_type, c.is_discover, c.status, c.started_at, c.connected_at, c.ended_at,
              c.reports_count, c.age_alert, c.age_alert_reason, c.end_reason,
              cu.username AS caller_username, ce.username AS callee_username
       FROM calls c
       JOIN users cu ON cu.id = c.caller_id
       LEFT JOIN users ce ON ce.id = c.callee_id
       WHERE c.status NOT IN ('ringing', 'active')
       ORDER BY c.started_at DESC
       LIMIT $1`,
      [limit]
    );
    return res.json({ data: r.rows });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// Backward-compatible alias for the previous dashboard "Recent calls" call —
// same query, not a re-dispatch through the router.
router.get('/calls/recent', requirePermission('callsView'), async (req, res) => {
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
  try {
    const r = await pool.query(
      `SELECT c.id, c.call_type, c.is_discover, c.status, c.started_at, c.connected_at, c.ended_at,
              c.reports_count, c.age_alert, c.age_alert_reason, c.end_reason,
              cu.username AS caller_username, ce.username AS callee_username
       FROM calls c
       JOIN users cu ON cu.id = c.caller_id
       LEFT JOIN users ce ON ce.id = c.callee_id
       WHERE c.status NOT IN ('ringing', 'active')
       ORDER BY c.started_at DESC
       LIMIT $1`,
      [limit]
    );
    return res.json({ data: r.rows });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.post('/calls/:id/end', requirePermission('callsEnd'), async (req, res) => {
  try {
    const ok = presence.adminEndCall(req.params.id, req.user.id, req.body?.reason || 'admin_action');
    if (!ok) return res.status(404).json({ errors: { detail: 'Call is not currently active' } });
    logAudit(req, 'END_CALL', 'call', req.params.id, { reason: req.body?.reason });
    return res.json({ data: { ended: true } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// ─── APPEALS ──────────────────────────────────────────────────────────────────

router.get('/appeals', requirePermission('appealsView'), async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT a.*, u.username FROM appeals a JOIN users u ON u.id = a.user_id
       ORDER BY a.created_at DESC LIMIT 100`
    );
    return res.json({ data: r.rows });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.post('/appeals/:id/approve', requirePermission('appealsApprove'), async (req, res) => {
  try {
    const r = await pool.query(
      `UPDATE appeals SET status = 'approved', reviewed_by = $1, reviewed_at = NOW(), review_notes = $2
       WHERE id = $3 RETURNING *`,
      [req.user.id, req.body?.notes || null, req.params.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'Appeal not found' } });
    // Approving an appeal lifts whatever ban prompted it — an appeal that
    // doesn't actually restore access isn't really "approved".
    await pool.query(
      `UPDATE users SET is_banned = FALSE, banned_at = NULL, banned_reason = NULL, ban_expires_at = NULL
       WHERE id = $1`,
      [r.rows[0].user_id]
    );
    logAudit(req, 'APPROVE_APPEAL', 'appeal', req.params.id);
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.post('/appeals/:id/deny', requirePermission('appealsDeny'), async (req, res) => {
  try {
    const r = await pool.query(
      `UPDATE appeals SET status = 'denied', reviewed_by = $1, reviewed_at = NOW(), review_notes = $2
       WHERE id = $3 RETURNING *`,
      [req.user.id, req.body?.notes || null, req.params.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'Appeal not found' } });
    logAudit(req, 'DENY_APPEAL', 'appeal', req.params.id);
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// ─── SETTINGS ─────────────────────────────────────────────────────────────────

router.get('/settings', requirePermission('settingsView'), async (req, res) => {
  try {
    const r = await pool.query('SELECT key, value FROM app_settings');
    return res.json({ data: Object.fromEntries(r.rows.map((row) => [row.key, row.value])) });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.patch('/settings', requirePermission('settingsEdit'), async (req, res) => {
  const entries = Object.entries(req.body || {});
  if (!entries.length) return res.status(400).json({ errors: { detail: 'No settings provided' } });
  try {
    for (const [key, value] of entries) {
      await pool.query(
        `INSERT INTO app_settings (key, value, updated_by) VALUES ($1,$2,$3)
         ON CONFLICT (key) DO UPDATE SET value = $2, updated_by = $3, updated_at = NOW()`,
        [key, JSON.stringify(value), req.user.id]
      );
    }
    logAudit(req, 'UPDATE_SETTINGS', 'settings', null, { keys: entries.map(([k]) => k) });
    return res.json({ data: { saved: true } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.get('/banned-words', requirePermission('settingsView'), async (req, res) => {
  try {
    const r = await pool.query('SELECT word FROM banned_words ORDER BY created_at');
    return res.json({ data: r.rows.map((row) => row.word) });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.post('/banned-words', requirePermission('settingsEdit'), async (req, res) => {
  const word = (req.body?.word || '').trim().toLowerCase();
  if (!word) return res.status(400).json({ errors: { detail: 'word is required' } });
  try {
    await pool.query(
      'INSERT INTO banned_words (word, created_by) VALUES ($1,$2) ON CONFLICT (word) DO NOTHING',
      [word, req.user.id]
    );
    logAudit(req, 'ADD_BANNED_WORD', 'banned_word', word);
    return res.json({ data: { word } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.delete('/banned-words/:word', requirePermission('settingsEdit'), async (req, res) => {
  try {
    await pool.query('DELETE FROM banned_words WHERE word = $1', [req.params.word.toLowerCase()]);
    logAudit(req, 'REMOVE_BANNED_WORD', 'banned_word', req.params.word);
    return res.json({ data: { removed: true } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.get('/rules', requirePermission('settingsView'), async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM violation_rules ORDER BY created_at');
    return res.json({ data: r.rows });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.post('/rules', requirePermission('settingsEdit'), async (req, res) => {
  const { name, pattern, action, strikes } = req.body || {};
  if (!name || !pattern) return res.status(400).json({ errors: { detail: 'name and pattern are required' } });
  try {
    const r = await pool.query(
      `INSERT INTO violation_rules (name, pattern, action, strikes, created_by)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [name, pattern, action || 'Auto-flag', strikes || 1, req.user.id]
    );
    logAudit(req, 'ADD_VIOLATION_RULE', 'violation_rule', r.rows[0].id, { name, pattern });
    return res.json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.delete('/rules/:id', requirePermission('settingsEdit'), async (req, res) => {
  try {
    await pool.query('DELETE FROM violation_rules WHERE id = $1', [req.params.id]);
    logAudit(req, 'REMOVE_VIOLATION_RULE', 'violation_rule', req.params.id);
    return res.json({ data: { removed: true } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

module.exports = router;
