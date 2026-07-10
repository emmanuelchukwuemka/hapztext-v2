const router = require('express').Router();
const pool = require('../db');
const authMw = require('../middleware/auth');

// GET /people/search?q=
router.get('/search', authMw, async (req, res) => {
  const q = (req.query.q || '').trim();
  if (!q) return res.json({ data: { users: [] } });
  try {
    const r = await pool.query(
      `SELECT p.*,
        (SELECT COUNT(*)::int FROM user_follows WHERE following_id = p.user_id) AS follower_count,
        (SELECT COUNT(*)::int FROM user_follows WHERE follower_id = p.user_id) AS following_count
       FROM profiles p WHERE p.username ILIKE $1 LIMIT 20`,
      [`%${q}%`]
    );
    const users = r.rows.map((p) => ({
      id: p.user_id,
      username: p.username,
      email: p.email,
      profile_picture: p.profile_picture,
      follower_count: p.follower_count,
      following_count: p.following_count,
      mention_count: 0,
      is_email_verified: true,
      created_at: p.created_at,
      updated_at: p.updated_at,
    }));
    return res.json({ data: { users } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// GET /people/profiles
router.get('/profiles', authMw, async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const size = parseInt(req.query.page_size) || 20;
  const offset = (page - 1) * size;
  try {
    const r = await pool.query(
      `SELECT p.*,
        (SELECT COUNT(*)::int FROM user_follows WHERE following_id = p.user_id) AS follower_count,
        (SELECT COUNT(*)::int FROM user_follows WHERE follower_id = p.user_id) AS following_count,
        (SELECT COUNT(*)::int FROM posts WHERE sender_id = p.user_id AND is_reply = FALSE AND is_published = TRUE) AS post_count
       FROM profiles p ORDER BY p.updated_at DESC LIMIT $1 OFFSET $2`,
      [size, offset]
    );
    return res.json({ data: { result: r.rows, previous_profiles_data: null, next_profiles_data: null } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// GET /people/friends
router.get('/friends', authMw, async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT p.* FROM user_follows f1
       JOIN user_follows f2 ON f1.following_id = f2.follower_id AND f2.following_id = f1.follower_id
       JOIN profiles p ON p.user_id = f1.following_id
       WHERE f1.follower_id = $1`,
      [req.user.id]
    );
    return res.json({ data: { friends: r.rows } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// GET /people/followers/:userId
router.get('/followers/:userId', authMw, async (req, res) => {
  try {
    const r = await pool.query(
      'SELECT p.* FROM user_follows f JOIN profiles p ON p.user_id = f.follower_id WHERE f.following_id = $1',
      [req.params.userId]
    );
    return res.json({ data: { followers: r.rows } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// GET /people/followings/:userId
router.get('/followings/:userId', authMw, async (req, res) => {
  try {
    const r = await pool.query(
      'SELECT p.* FROM user_follows f JOIN profiles p ON p.user_id = f.following_id WHERE f.follower_id = $1',
      [req.params.userId]
    );
    return res.json({ data: { followings: r.rows } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// GET /people/user/:userId
router.get('/user/:userId', authMw, async (req, res) => {
  try {
    const uid = req.params.userId;
    const [profileR, followerR, followingR, postR] = await Promise.all([
      pool.query('SELECT * FROM profiles WHERE user_id = $1', [uid]),
      pool.query('SELECT COUNT(*)::int AS cnt FROM user_follows WHERE following_id = $1', [uid]),
      pool.query('SELECT COUNT(*)::int AS cnt FROM user_follows WHERE follower_id = $1', [uid]),
      pool.query("SELECT COUNT(*)::int AS cnt FROM posts WHERE sender_id = $1 AND is_reply = FALSE AND is_published = TRUE", [uid]),
    ]);
    const profile = profileR.rows[0] || { user_id: uid };
    return res.json({ data: {
      ...profile,
      follower_count: followerR.rows[0]?.cnt ?? 0,
      following_count: followingR.rows[0]?.cnt ?? 0,
      post_count: postR.rows[0]?.cnt ?? 0,
    }});
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /people/follow/:userId
router.post('/follow/:userId', authMw, async (req, res) => {
  const targetId = req.params.userId;
  if (targetId === req.user.id)
    return res.status(400).json({ errors: { detail: 'Cannot follow yourself' } });
  try {
    await pool.query(
      'INSERT INTO user_follows (follower_id, following_id) VALUES ($1,$2) ON CONFLICT DO NOTHING',
      [req.user.id, targetId]
    );
    // Notify the followed user
    const followerP = await pool.query('SELECT username FROM profiles WHERE user_id=$1', [req.user.id]);
    const followerUsername = followerP.rows[0]?.username || 'Someone';
    await pool.query(
      `INSERT INTO notifications (user_id, type, payload) VALUES ($1,'follow',$2)`,
      [targetId, JSON.stringify({ actor_id: req.user.id, actor_username: followerUsername, message: `${followerUsername} followed you` })]
    );
    return res.status(201).json({ message: 'Now following', data: {} });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// DELETE /people/follow/:userId
router.delete('/follow/:userId', authMw, async (req, res) => {
  try {
    await pool.query(
      'DELETE FROM user_follows WHERE follower_id = $1 AND following_id = $2',
      [req.user.id, req.params.userId]
    );
    return res.json({ message: 'Unfollowed', data: {} });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

module.exports = router;
