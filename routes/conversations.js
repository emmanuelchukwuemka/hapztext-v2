const router = require('express').Router();
const pool = require('../db');
const authMw = require('../middleware/auth');
const { v4: uuidv4 } = require('uuid');

// GET /conversations
router.get('/', authMw, async (req, res) => {
  try {
    const cpR = await pool.query(
      'SELECT conversation_id FROM conversation_participants WHERE user_id = $1',
      [req.user.id]
    );
    const convIds = cpR.rows.map((r) => r.conversation_id);
    if (!convIds.length) return res.json({ data: { result: [] } });

    const result = await Promise.all(
      convIds.map(async (convId) => {
        const [partR, msgR] = await Promise.all([
          pool.query(
            `SELECT p.user_id AS id, p.username, p.profile_picture
             FROM conversation_participants cp
             JOIN profiles p ON p.user_id = cp.user_id
             WHERE cp.conversation_id = $1`,
            [convId]
          ),
          pool.query(
            'SELECT * FROM messages WHERE conversation_id = $1 ORDER BY created_at DESC LIMIT 1',
            [convId]
          ),
        ]);
        return {
          id: convId,
          participants: partR.rows,
          last_message: msgR.rows[0] || null,
        };
      })
    );

    return res.json({ data: { result } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /conversations  (find-or-create for 1-on-1; always create for group)
router.post('/', authMw, async (req, res) => {
  const { participantIds } = req.body;
  try {
    const ids = [...new Set([...(participantIds || []), req.user.id])];

    // For 1-on-1 chats, find an existing conversation with exactly these two users
    if (ids.length === 2) {
      const existing = await pool.query(
        `SELECT cp1.conversation_id AS id
         FROM conversation_participants cp1
         JOIN conversation_participants cp2
           ON cp1.conversation_id = cp2.conversation_id AND cp2.user_id = $2
         WHERE cp1.user_id = $1
           AND (SELECT COUNT(*) FROM conversation_participants
                WHERE conversation_id = cp1.conversation_id) = 2
         LIMIT 1`,
        [ids[0], ids[1]]
      );
      if (existing.rows.length) {
        return res.json({ success: true, data: { id: existing.rows[0].id }, existing: true });
      }
    }

    const convId = uuidv4();
    await pool.query(
      'INSERT INTO conversations (id, created_by) VALUES ($1,$2)',
      [convId, req.user.id]
    );
    for (const id of ids) {
      await pool.query(
        'INSERT INTO conversation_participants (conversation_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING',
        [convId, id]
      );
    }
    return res.json({ success: true, data: { id: convId } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// GET /conversations/:convId/messages
router.get('/:convId/messages', authMw, async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const size = parseInt(req.query.page_size) || 50;
  const offset = (page - 1) * size;
  try {
    const check = await pool.query(
      'SELECT 1 FROM conversation_participants WHERE conversation_id = $1 AND user_id = $2',
      [req.params.convId, req.user.id]
    );
    if (!check.rows.length)
      return res.status(403).json({ errors: { detail: 'Not a participant' } });

    const r = await pool.query(
      'SELECT * FROM messages WHERE conversation_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3',
      [req.params.convId, size, offset]
    );
    return res.json({ data: { result: r.rows } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /conversations/:convId/messages
router.post('/:convId/messages', authMw, async (req, res) => {
  const { text, type, mediaUrl, isReply, previousMessageId } = req.body;
  try {
    const check = await pool.query(
      'SELECT 1 FROM conversation_participants WHERE conversation_id = $1 AND user_id = $2',
      [req.params.convId, req.user.id]
    );
    if (!check.rows.length)
      return res.status(403).json({ errors: { detail: 'Not a participant' } });

    const r = await pool.query(
      `INSERT INTO messages
         (conversation_id, sender_id, message_type, text_content, media_url, is_reply, previous_message_id, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,'sent') RETURNING *`,
      [req.params.convId, req.user.id,
       type || 'text', text || '',
       mediaUrl || null,
       isReply || false,
       previousMessageId || null]
    );
    return res.json({ success: true, data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// PUT /conversations/:convId/messages/read
router.put('/:convId/messages/read', authMw, async (req, res) => {
  const { messageIds } = req.body;
  try {
    if (messageIds?.length) {
      await pool.query(
        'UPDATE messages SET status = $1 WHERE id = ANY($2) AND conversation_id = $3',
        ['read', messageIds, req.params.convId]
      );
    }
    return res.json({ success: true });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

module.exports = router;
