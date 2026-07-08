const router = require('express').Router();
const pool = require('../db');
const authMw = require('../middleware/auth');

async function enrichPosts(posts, userId) {
  if (!posts.length) return [];
  const ids = posts.map((p) => p.id);

  const [mediaR, reactR, replyR] = await Promise.all([
    pool.query('SELECT * FROM media_files WHERE post_id = ANY($1)', [ids]),
    pool.query(
      'SELECT post_id, reaction FROM post_reactions WHERE user_id = $1 AND post_id = ANY($2)',
      [userId, ids]
    ),
    pool.query(
      `SELECT previous_post_id, COUNT(*)::int AS cnt FROM posts
       WHERE previous_post_id = ANY($1) AND is_reply = TRUE GROUP BY previous_post_id`,
      [ids]
    ),
  ]);

  const mediaMap = {}, reactionMap = {}, replyMap = {};
  for (const m of mediaR.rows) {
    if (!mediaMap[m.post_id]) mediaMap[m.post_id] = [];
    mediaMap[m.post_id].push(m);
  }
  for (const r of reactR.rows) reactionMap[r.post_id] = r.reaction;
  for (const r of replyR.rows) replyMap[r.previous_post_id] = r.cnt;

  return posts.map((p) => ({
    ...p,
    media_files: mediaMap[p.id] || [],
    current_user_reaction: reactionMap[p.id] || null,
    reply_count: replyMap[p.id] || 0,
  }));
}

const getUsername = async (userId) => {
  const r = await pool.query('SELECT username FROM users WHERE id = $1', [userId]);
  return r.rows[0]?.username || '';
};

// GET /posts  (feed)
router.get('/', authMw, async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const feedType = req.query.feedType || 'latest';
  const q = (req.query.query || '').trim();
  const offset = (page - 1) * 20;

  let order = 'created_at DESC';
  if (feedType === 'popular') order = 'like_count DESC';
  if (feedType === 'trending') order = 'share_count DESC';

  const params = [20, offset];
  let extra = '';
  if (q) {
    params.push(`%${q}%`);
    extra = ` AND text_content ILIKE $${params.length}`;
  }

  try {
    const r = await pool.query(
      `SELECT * FROM posts WHERE is_reply = FALSE${extra} ORDER BY ${order} LIMIT $1 OFFSET $2`,
      params
    );
    const enriched = await enrichPosts(r.rows, req.user.id);
    return res.json({ data: { result: enriched, previous_posts_data: null, next_posts_data: null } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// GET /posts/notifications
router.get('/notifications', authMw, async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const offset = (page - 1) * 20;
  try {
    const r = await pool.query(
      'SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT 20 OFFSET $2',
      [req.user.id, offset]
    );
    return res.json({
      data: { result: r.rows, previous_notifications_data: null, next_notifications_data: null },
    });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// GET /posts/user/:userId
router.get('/user/:userId', authMw, async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const offset = (page - 1) * 20;
  try {
    const r = await pool.query(
      'SELECT * FROM posts WHERE sender_id = $1 AND is_reply = FALSE ORDER BY created_at DESC LIMIT 20 OFFSET $2',
      [req.params.userId, offset]
    );
    const enriched = await enrichPosts(r.rows, req.user.id);
    return res.json({ data: { result: enriched, previous_posts_data: null, next_posts_data: null } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// GET /posts/:postId/comments
router.get('/:postId/comments', authMw, async (req, res) => {
  try {
    const r = await pool.query(
      'SELECT * FROM posts WHERE is_reply = TRUE AND previous_post_id = $1 ORDER BY created_at DESC',
      [req.params.postId]
    );
    const enriched = await enrichPosts(r.rows, req.user.id);
    return res.json({ data: { result: enriched, previous_replies_data: null, next_replies_data: null } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// GET /posts/:postId/reactions
router.get('/:postId/reactions', authMw, async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT pr.*, p.username FROM post_reactions pr
       LEFT JOIN profiles p ON p.user_id = pr.user_id
       WHERE pr.post_id = $1 ORDER BY pr.created_at DESC`,
      [req.params.postId]
    );
    return res.json({ data: r.rows });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /posts/text
router.post('/text', authMw, async (req, res) => {
  const { textContent, scheduledAt } = req.body;
  try {
    const username = await getUsername(req.user.id);
    const r = await pool.query(
      `INSERT INTO posts (sender_id, sender_username, post_format, text_content, is_reply, is_published, scheduled_at)
       VALUES ($1,$2,'text',$3,FALSE,TRUE,$4) RETURNING *`,
      [req.user.id, username, textContent || '', scheduledAt || null]
    );
    return res.status(201).json({ data: { ...r.rows[0], media_files: [] } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /posts/image  (Flutter uploads to Cloudinary and passes imageUrls)
router.post('/image', authMw, async (req, res) => {
  const { caption, imageUrls, scheduledAt } = req.body;
  try {
    const username = await getUsername(req.user.id);
    const r = await pool.query(
      `INSERT INTO posts (sender_id, sender_username, post_format, text_content, is_reply, is_published, scheduled_at)
       VALUES ($1,$2,'image',$3,FALSE,TRUE,$4) RETURNING *`,
      [req.user.id, username, caption || '', scheduledAt || null]
    );
    const post = r.rows[0];
    const mediaFiles = [];
    for (const url of imageUrls || []) {
      const mr = await pool.query(
        'INSERT INTO media_files (post_id, media_type, image_file) VALUES ($1,$2,$3) RETURNING *',
        [post.id, 'image', url]
      );
      mediaFiles.push(mr.rows[0]);
    }
    return res.status(201).json({ data: { ...post, media_files: mediaFiles } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /posts/audio
router.post('/audio', authMw, async (req, res) => {
  const { audioUrl, scheduledAt } = req.body;
  try {
    const username = await getUsername(req.user.id);
    const r = await pool.query(
      `INSERT INTO posts (sender_id, sender_username, post_format, text_content, audio_content, is_reply, is_published, scheduled_at)
       VALUES ($1,$2,'audio','',$3,FALSE,TRUE,$4) RETURNING *`,
      [req.user.id, username, audioUrl, scheduledAt || null]
    );
    const post = r.rows[0];
    const mr = await pool.query(
      'INSERT INTO media_files (post_id, media_type, audio_file) VALUES ($1,$2,$3) RETURNING *',
      [post.id, 'audio', audioUrl]
    );
    return res.status(201).json({ data: { ...post, media_files: [mr.rows[0]] } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /posts/video
router.post('/video', authMw, async (req, res) => {
  const { videoUrl, caption, scheduledAt } = req.body;
  try {
    const username = await getUsername(req.user.id);
    const r = await pool.query(
      `INSERT INTO posts (sender_id, sender_username, post_format, text_content, video_content, is_reply, is_published, scheduled_at)
       VALUES ($1,$2,'video',$3,$4,FALSE,TRUE,$5) RETURNING *`,
      [req.user.id, username, caption || '', videoUrl, scheduledAt || null]
    );
    const post = r.rows[0];
    const mr = await pool.query(
      'INSERT INTO media_files (post_id, media_type, video_file) VALUES ($1,$2,$3) RETURNING *',
      [post.id, 'video', videoUrl]
    );
    return res.status(201).json({ data: { ...post, media_files: [mr.rows[0]] } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /posts/:postId/comments
router.post('/:postId/comments', authMw, async (req, res) => {
  const { comment, audioUrl } = req.body;
  const postId = req.params.postId;
  try {
    const username = await getUsername(req.user.id);
    const r = await pool.query(
      `INSERT INTO posts (sender_id, sender_username, post_format, text_content, audio_content, is_reply, previous_post_id, is_published)
       VALUES ($1,$2,$3,$4,$5,TRUE,$6,TRUE) RETURNING *`,
      [req.user.id, username,
       audioUrl ? 'audio' : 'text',
       comment || '',
       audioUrl || null,
       postId]
    );
    // Notify post owner (not self)
    const postR = await pool.query('SELECT sender_id FROM posts WHERE id=$1', [postId]);
    const ownerId = postR.rows[0]?.sender_id;
    if (ownerId && ownerId !== req.user.id) {
      await pool.query(
        `INSERT INTO notifications (user_id, type, payload) VALUES ($1,'comment',$2)`,
        [ownerId, JSON.stringify({ actor_id: req.user.id, actor_username: username, post_id: postId, message: `${username} commented on your post` })]
      );
    }
    return res.status(201).json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /posts/:postId/react
router.post('/:postId/react', authMw, async (req, res) => {
  const { reaction } = req.body;
  const postId = req.params.postId;
  try {
    const ex = await pool.query(
      'SELECT reaction FROM post_reactions WHERE post_id = $1 AND user_id = $2',
      [postId, req.user.id]
    );
    const wasReacted = ex.rows.length > 0 && ex.rows[0].reaction === reaction;
    if (wasReacted) {
      await pool.query(
        'DELETE FROM post_reactions WHERE post_id = $1 AND user_id = $2',
        [postId, req.user.id]
      );
    } else {
      await pool.query(
        `INSERT INTO post_reactions (post_id, user_id, reaction) VALUES ($1,$2,$3)
         ON CONFLICT (post_id, user_id) DO UPDATE SET reaction = $3`,
        [postId, req.user.id, reaction]
      );
      // Notify post owner (not self)
      const postR = await pool.query('SELECT sender_id FROM posts WHERE id=$1', [postId]);
      const ownerId = postR.rows[0]?.sender_id;
      if (ownerId && ownerId !== req.user.id) {
        const actorP = await pool.query('SELECT username FROM profiles WHERE user_id=$1', [req.user.id]);
        const actorUsername = actorP.rows[0]?.username || 'Someone';
        await pool.query(
          `INSERT INTO notifications (user_id, type, payload) VALUES ($1,'reaction',$2)`,
          [ownerId, JSON.stringify({ actor_id: req.user.id, actor_username: actorUsername, post_id: postId, reaction, message: `${actorUsername} reacted ${reaction} to your post` })]
        );
      }
    }
    const cnt = await pool.query(
      'SELECT COUNT(*)::int AS count FROM post_reactions WHERE post_id = $1',
      [postId]
    );
    await pool.query('UPDATE posts SET like_count = $1 WHERE id = $2', [cnt.rows[0].count, postId]);
    return res.status(201).json({ message: 'Reaction updated', data: {} });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /posts/:postId/share
router.post('/:postId/share', authMw, async (req, res) => {
  try {
    await pool.query('UPDATE posts SET share_count = share_count + 1 WHERE id = $1', [req.params.postId]);
    return res.status(201).json({ message: 'Post shared', data: {} });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// DELETE /posts/:postId
router.delete('/:postId', authMw, async (req, res) => {
  try {
    await pool.query(
      'DELETE FROM posts WHERE id = $1 AND sender_id = $2',
      [req.params.postId, req.user.id]
    );
    return res.json({ message: 'Post deleted successfully', data: {} });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

module.exports = router;
