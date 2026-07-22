const router = require('express').Router();
const pool = require('../db');
const authMw = require('../middleware/auth');

const normalizeTag = (t) => (t || '').toLowerCase().replace(/^#+/, '').trim();
const normalizeMention = (m) => (m || '').toLowerCase().replace(/^@+/, '').trim();

const extractHashtags = (text) => {
  const s = (text || '').toString();
  const set = new Set();
  const re = /#([a-zA-Z0-9_]+)/g;
  let m;
  while ((m = re.exec(s)) !== null) set.add(normalizeTag(m[1]));
  return Array.from(set).filter(Boolean);
};

const extractMentions = (text) => {
  const s = (text || '').toString();
  const set = new Set();
  const re = /@([a-zA-Z0-9_]+)/g;
  let m;
  while ((m = re.exec(s)) !== null) set.add(normalizeMention(m[1]));
  return Array.from(set).filter(Boolean);
};

async function syncHashtags(postId, tags) {
  const oldR = await pool.query('SELECT tag FROM post_hashtags WHERE post_id = $1', [postId]);
  const oldTags = oldR.rows.map((r) => r.tag);
  const newTags = Array.from(new Set((tags || []).map(normalizeTag).filter(Boolean)));

  await pool.query('DELETE FROM post_hashtags WHERE post_id = $1', [postId]);

  for (const tag of newTags) {
    await pool.query('INSERT INTO hashtags (tag) VALUES ($1) ON CONFLICT DO NOTHING', [tag]);
    await pool.query('INSERT INTO post_hashtags (post_id, tag) VALUES ($1,$2) ON CONFLICT DO NOTHING', [
      postId,
      tag,
    ]);
  }

  const affected = Array.from(new Set([...oldTags, ...newTags]));
  for (const tag of affected) {
    await pool.query(
      `UPDATE hashtags h SET usage_count = c.cnt, updated_at = NOW()
       FROM (SELECT COUNT(*)::int AS cnt FROM post_hashtags WHERE tag = $1) c
       WHERE h.tag = $1`,
      [tag]
    );
  }
}

async function syncMentionsAndNotify(postId, mentions, actorId, actorUsername) {
  await pool.query('DELETE FROM post_mentions WHERE post_id = $1', [postId]);
  const usernames = Array.from(new Set((mentions || []).map(normalizeMention).filter(Boolean)));
  if (!usernames.length) return;

  const usersR = await pool.query('SELECT id, username FROM users WHERE LOWER(username) = ANY($1)', [
    usernames,
  ]);
  for (const u of usersR.rows) {
    await pool.query(
      `INSERT INTO post_mentions (post_id, mentioned_user_id, mentioned_username)
       VALUES ($1,$2,$3) ON CONFLICT DO NOTHING`,
      [postId, u.id, u.username]
    );
    if (u.id !== actorId) {
      await pool.query(
        `INSERT INTO notifications (user_id, type, payload) VALUES ($1,'mention',$2)`,
        [
          u.id,
          JSON.stringify({
            actor_id: actorId,
            actor_username: actorUsername,
            post_id: postId,
            message: `${actorUsername} mentioned you`,
          }),
        ]
      );
    }
  }
}

async function enrichPostsBase(posts, userId) {
  if (!posts.length) return [];
  const ids = posts.map((p) => p.id);

  const [mediaR, reactR, replyR, hashR, mentionR, repostR] = await Promise.all([
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
    pool.query('SELECT post_id, tag FROM post_hashtags WHERE post_id = ANY($1)', [ids]),
    pool.query('SELECT post_id, mentioned_username FROM post_mentions WHERE post_id = ANY($1)', [ids]),
    pool.query(
      `SELECT repost_of, COUNT(*)::int AS cnt FROM posts
       WHERE repost_of = ANY($1) GROUP BY repost_of`,
      [ids]
    ),
  ]);

  const mediaMap = {},
    reactionMap = {},
    replyMap = {},
    hashMap = {},
    mentionMap = {},
    repostMap = {};
  for (const m of mediaR.rows) {
    if (!mediaMap[m.post_id]) mediaMap[m.post_id] = [];
    mediaMap[m.post_id].push(m);
  }
  for (const r of reactR.rows) reactionMap[r.post_id] = r.reaction;
  for (const r of replyR.rows) replyMap[r.previous_post_id] = r.cnt;
  for (const r of hashR.rows) {
    if (!hashMap[r.post_id]) hashMap[r.post_id] = [];
    hashMap[r.post_id].push(r.tag);
  }
  for (const r of mentionR.rows) {
    if (!mentionMap[r.post_id]) mentionMap[r.post_id] = [];
    mentionMap[r.post_id].push(r.mentioned_username);
  }
  for (const r of repostR.rows) repostMap[r.repost_of] = r.cnt;

  return posts.map((p) => ({
    ...p,
    media_files: mediaMap[p.id] || [],
    current_user_reaction: reactionMap[p.id] || null,
    reply_count: replyMap[p.id] || 0,
    hashtags: hashMap[p.id] || [],
    mentions: mentionMap[p.id] || [],
    repost_count: repostMap[p.id] || 0,
  }));
}

async function enrichPosts(posts, userId) {
  const base = await enrichPostsBase(posts, userId);
  const repostIds = Array.from(
    new Set(base.map((p) => p.repost_of).filter((x) => x && x !== null))
  );
  if (!repostIds.length) return base;

  const origR = await pool.query('SELECT * FROM posts WHERE id = ANY($1)', [repostIds]);
  const enrichedOrig = await enrichPostsBase(origR.rows, userId);
  const origMap = {};
  for (const p of enrichedOrig) origMap[p.id] = p;

  return base.map((p) => ({
    ...p,
    repost_of_post: p.repost_of ? origMap[p.repost_of] || null : null,
  }));
}

const getUsername = async (userId) => {
  const r = await pool.query('SELECT username FROM users WHERE id = $1', [userId]);
  return r.rows[0]?.username || '';
};

router.get('/hashtags/trending', authMw, async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit) || 20, 50);
  try {
    const r = await pool.query(
      'SELECT tag, usage_count FROM hashtags ORDER BY usage_count DESC, updated_at DESC LIMIT $1',
      [limit]
    );
    return res.json({ data: { result: r.rows } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.get('/hashtags/:tag', authMw, async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const offset = (page - 1) * 20;
  const tag = normalizeTag(req.params.tag);
  try {
    const r = await pool.query(
      `SELECT p.* FROM post_hashtags ph
       JOIN posts p ON p.id = ph.post_id
       WHERE ph.tag = $1 AND p.is_reply = FALSE AND ((p.scheduled_at IS NULL AND p.is_published = TRUE) OR (p.scheduled_at IS NOT NULL AND p.scheduled_at <= NOW()))
       ORDER BY p.created_at DESC LIMIT 20 OFFSET $2`,
      [tag, offset]
    );
    const enriched = await enrichPosts(r.rows, req.user.id);
    return res.json({ data: { result: enriched, previous_posts_data: null, next_posts_data: null } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// GET /posts  (feed)
router.get('/', authMw, async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const feedType = req.query.feedType || 'latest';
  const q = (req.query.query || '').trim();
  const offset = (page - 1) * 20;

  let order = 'created_at DESC';
  if (feedType === 'popular' || feedType === 'most_liked') order = 'like_count DESC';
  if (feedType === 'most_shared') order = 'share_count DESC';
  if (feedType === 'most_commented') order = 'reply_count_calc DESC';
  if (feedType === 'trending') order = '(like_count * 2 + share_count * 3 + reply_count_calc * 2) DESC';

  const params = [20, offset];
  let extra = '';
  let join = '';
  let replyJoin = '';
  let selectCols = 'posts.*';
  if (q && q.startsWith('#')) {
    params.push(normalizeTag(q));
    join = ` JOIN post_hashtags ph ON ph.post_id = posts.id`;
    extra = ` AND ph.tag = $${params.length}`;
  } else if (q) {
    params.push(`%${q}%`);
    extra = ` AND text_content ILIKE $${params.length}`;
  }

  try {
    if (feedType === 'most_commented' || feedType === 'trending') {
      selectCols = 'posts.*, COALESCE(rc.cnt,0) AS reply_count_calc';
      replyJoin = ` LEFT JOIN (
          SELECT previous_post_id, COUNT(*)::int AS cnt
          FROM posts
          WHERE is_reply = TRUE AND is_published = TRUE
          GROUP BY previous_post_id
        ) rc ON rc.previous_post_id = posts.id`;
    }
    const r = await pool.query(
      `SELECT ${selectCols} FROM posts${join}${replyJoin}
       WHERE posts.is_reply = FALSE AND ((posts.scheduled_at IS NULL AND posts.is_published = TRUE) OR (posts.scheduled_at IS NOT NULL AND posts.scheduled_at <= NOW()))${extra}
       ORDER BY ${order} LIMIT $1 OFFSET $2`,
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
      `SELECT * FROM posts
       WHERE sender_id = $1 AND is_reply = FALSE AND ((scheduled_at IS NULL AND is_published = TRUE) OR (scheduled_at IS NOT NULL AND scheduled_at <= NOW()))
       ORDER BY created_at DESC LIMIT 20 OFFSET $2`,
      [req.params.userId, offset]
    );
    const enriched = await enrichPosts(r.rows, req.user.id);
    return res.json({ data: { result: enriched, previous_posts_data: null, next_posts_data: null } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// GET /posts/:postId  (single post, e.g. deep-link from a notification)
router.get('/:postId', authMw, async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM posts WHERE id = $1', [req.params.postId]);
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'Post not found' } });
    const enriched = await enrichPosts(r.rows, req.user.id);
    return res.json({ data: enriched[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// GET /posts/:postId/comments
router.get('/:postId/comments', authMw, async (req, res) => {
  try {
    const r = await pool.query(
      'SELECT * FROM posts WHERE is_reply = TRUE AND previous_post_id = $1 AND is_published = TRUE ORDER BY created_at DESC',
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
  const { textContent, backgroundColor, scheduledAt } = req.body;
  try {
    const username = await getUsername(req.user.id);
    const r = await pool.query(
      `INSERT INTO posts (sender_id, sender_username, post_format, text_content, background_color, is_reply, is_published, scheduled_at)
       VALUES ($1,$2,'text',$3,$4,FALSE,TRUE,$5) RETURNING *`,
      [req.user.id, username, textContent || '', backgroundColor || null, scheduledAt || null]
    );
    const post = r.rows[0];
    await syncHashtags(post.id, extractHashtags(textContent));
    await syncMentionsAndNotify(post.id, extractMentions(textContent), req.user.id, username);
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
    await syncHashtags(post.id, extractHashtags(caption));
    await syncMentionsAndNotify(post.id, extractMentions(caption), req.user.id, username);
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
    await syncHashtags(post.id, extractHashtags(caption));
    await syncMentionsAndNotify(post.id, extractMentions(caption), req.user.id, username);
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
    const created = r.rows[0];
    await syncHashtags(created.id, extractHashtags(comment));
    await syncMentionsAndNotify(created.id, extractMentions(comment), req.user.id, username);
    // Notify post owner (not self)
    const postR = await pool.query('SELECT sender_id FROM posts WHERE id=$1', [postId]);
    const ownerId = postR.rows[0]?.sender_id;
    if (ownerId && ownerId !== req.user.id) {
      await pool.query(
        `INSERT INTO notifications (user_id, type, payload) VALUES ($1,'comment',$2)`,
        [ownerId, JSON.stringify({ actor_id: req.user.id, actor_username: username, post_id: postId, message: `${username} commented on your post` })]
      );
    }
    return res.status(201).json({ data: created });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.put('/:postId/comments/:commentId', authMw, async (req, res) => {
  const { comment } = req.body;
  try {
    const username = await getUsername(req.user.id);
    const r = await pool.query(
      `UPDATE posts SET text_content = $1
       WHERE id = $2 AND sender_id = $3 AND is_reply = TRUE AND previous_post_id = $4
       RETURNING *`,
      [comment || '', req.params.commentId, req.user.id, req.params.postId]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'Comment not found' } });
    const updated = r.rows[0];
    await syncHashtags(updated.id, extractHashtags(comment));
    await syncMentionsAndNotify(updated.id, extractMentions(comment), req.user.id, username);
    return res.json({ data: updated });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

router.post('/:postId/repost', authMw, async (req, res) => {
  const { comment, scheduledAt } = req.body;
  try {
    const username = await getUsername(req.user.id);
    const r = await pool.query(
      `INSERT INTO posts (sender_id, sender_username, post_format, text_content, is_reply, is_published, scheduled_at, repost_of)
       VALUES ($1,$2,'repost',$3,FALSE,TRUE,$4,$5) RETURNING *`,
      [req.user.id, username, comment || '', scheduledAt || null, req.params.postId]
    );
    const post = r.rows[0];
    await syncHashtags(post.id, extractHashtags(comment));
    await syncMentionsAndNotify(post.id, extractMentions(comment), req.user.id, username);
    const enriched = await enrichPosts([post], req.user.id);
    return res.status(201).json({ data: enriched[0] });
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
