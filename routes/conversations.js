const router = require('express').Router();
const pool = require('../db');
const authMw = require('../middleware/auth');
const { v4: uuidv4 } = require('uuid');

const defaultSettings = {
  pinned: false,
  muted: false,
  chat_mode: 'mixed',
  disappearing: 'off',
  auto_clear_enabled: false,
  auto_clear_start: null,
  auto_clear_end: null,
  theme_index: 0,
  notification_tone: null,
};

const normalizeChatMode = (v) => {
  const s = (v || '').toString().toLowerCase();
  if (s.includes('text')) return 'textOnly';
  if (s.includes('voice')) return 'voiceOnly';
  if (s.includes('call')) return 'callsOnly';
  return 'mixed';
};

const normalizeDisappearing = (v) => {
  const s = (v || '').toString().toLowerCase();
  if (s.includes('five')) return 'fiveSeconds';
  if (s.includes('hour')) return 'oneHour';
  if (s.includes('day')) return 'oneDay';
  return 'off';
};

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
        const [partR, msgR, settingsR, unreadR] = await Promise.all([
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
          pool.query(
            `SELECT pinned, muted, chat_mode, disappearing, auto_clear_enabled,
                    auto_clear_start, auto_clear_end, theme_index, notification_tone
             FROM conversation_user_settings
             WHERE conversation_id = $1 AND user_id = $2`,
            [convId, req.user.id]
          ),
          pool.query(
            `SELECT COUNT(*)::int AS cnt
             FROM messages m
             WHERE m.conversation_id = $1
               AND m.sender_id <> $2
               AND NOT EXISTS (
                 SELECT 1 FROM message_reads mr
                 WHERE mr.message_id = m.id AND mr.user_id = $2
               )`,
            [convId, req.user.id]
          ),
        ]);
        const settings = settingsR.rows[0] || defaultSettings;
        return {
          id: convId,
          participants: partR.rows,
          last_message: msgR.rows[0] || null,
          settings,
          unread: unreadR.rows[0]?.cnt || 0,
        };
      })
    );

    return res.json({ data: { result } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// GET /conversations/:convId/settings
router.get('/:convId/settings', authMw, async (req, res) => {
  try {
    const check = await pool.query(
      'SELECT 1 FROM conversation_participants WHERE conversation_id = $1 AND user_id = $2',
      [req.params.convId, req.user.id]
    );
    if (!check.rows.length)
      return res.status(403).json({ errors: { detail: 'Not a participant' } });

    const r = await pool.query(
      `SELECT pinned, muted, chat_mode, disappearing, auto_clear_enabled,
              auto_clear_start, auto_clear_end, theme_index, notification_tone
       FROM conversation_user_settings
       WHERE conversation_id = $1 AND user_id = $2`,
      [req.params.convId, req.user.id]
    );
    return res.json({ data: r.rows[0] || defaultSettings });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// PUT /conversations/:convId/settings
router.put('/:convId/settings', authMw, async (req, res) => {
  const {
    pinned,
    muted,
    chatMode,
    disappearing,
    autoClearEnabled,
    autoClearStart,
    autoClearEnd,
    themeIndex,
    notificationTone,
  } = req.body || {};
  try {
    const check = await pool.query(
      'SELECT 1 FROM conversation_participants WHERE conversation_id = $1 AND user_id = $2',
      [req.params.convId, req.user.id]
    );
    if (!check.rows.length)
      return res.status(403).json({ errors: { detail: 'Not a participant' } });

    const r = await pool.query(
      `INSERT INTO conversation_user_settings
        (conversation_id, user_id, pinned, muted, chat_mode, disappearing, auto_clear_enabled,
         auto_clear_start, auto_clear_end, theme_index, notification_tone)
       VALUES
        ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
       ON CONFLICT (conversation_id, user_id)
       DO UPDATE SET
        pinned = EXCLUDED.pinned,
        muted = EXCLUDED.muted,
        chat_mode = EXCLUDED.chat_mode,
        disappearing = EXCLUDED.disappearing,
        auto_clear_enabled = EXCLUDED.auto_clear_enabled,
        auto_clear_start = EXCLUDED.auto_clear_start,
        auto_clear_end = EXCLUDED.auto_clear_end,
        theme_index = EXCLUDED.theme_index,
        notification_tone = EXCLUDED.notification_tone,
        updated_at = NOW()
       RETURNING pinned, muted, chat_mode, disappearing, auto_clear_enabled,
                 auto_clear_start, auto_clear_end, theme_index, notification_tone`,
      [
        req.params.convId,
        req.user.id,
        pinned ?? defaultSettings.pinned,
        muted ?? defaultSettings.muted,
        normalizeChatMode(chatMode || defaultSettings.chat_mode),
        normalizeDisappearing(disappearing || defaultSettings.disappearing),
        autoClearEnabled ?? defaultSettings.auto_clear_enabled,
        autoClearStart ?? defaultSettings.auto_clear_start,
        autoClearEnd ?? defaultSettings.auto_clear_end,
        themeIndex ?? defaultSettings.theme_index,
        notificationTone ?? defaultSettings.notification_tone,
      ]
    );
    return res.json({ success: true, data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /conversations  (find-or-create for 1-on-1; always create for group)
router.post('/', authMw, async (req, res) => {
  const { participantIds, phoneNumber } = req.body;
  try {
    let ids = [...new Set([...(participantIds || []), req.user.id])];
    if (phoneNumber && (!participantIds || !participantIds.length)) {
      const pr = await pool.query('SELECT user_id FROM profiles WHERE phone_number = $1 LIMIT 1', [
        phoneNumber,
      ]);
      const otherId = pr.rows[0]?.user_id;
      if (!otherId) return res.status(404).json({ errors: { detail: 'User not found' } });
      ids = [...new Set([req.user.id, otherId])];
    }

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

    const [actorR, participantsR] = await Promise.all([
      pool.query('SELECT username FROM profiles WHERE user_id = $1', [req.user.id]),
      pool.query('SELECT user_id FROM conversation_participants WHERE conversation_id = $1', [
        req.params.convId,
      ]),
    ]);
    const actorUsername = actorR.rows[0]?.username || 'Someone';
    const others = participantsR.rows.map((x) => x.user_id).filter((id) => id !== req.user.id);
    for (const userId of others) {
      await pool.query(`INSERT INTO notifications (user_id, type, payload) VALUES ($1,'chat_message',$2)`, [
        userId,
        JSON.stringify({
          actor_id: req.user.id,
          actor_username: actorUsername,
          conversation_id: req.params.convId,
          message_id: r.rows[0].id,
          message: `${actorUsername} sent you a message`,
        }),
      ]);
    }
    return res.json({ success: true, data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// PUT /conversations/:convId/messages/:messageId  (edit)
router.put('/:convId/messages/:messageId', authMw, async (req, res) => {
  const { text } = req.body || {};
  try {
    const check = await pool.query(
      'SELECT 1 FROM conversation_participants WHERE conversation_id = $1 AND user_id = $2',
      [req.params.convId, req.user.id]
    );
    if (!check.rows.length)
      return res.status(403).json({ errors: { detail: 'Not a participant' } });

    const r = await pool.query(
      `UPDATE messages
       SET text_content = $1, edited_at = NOW(), updated_at = NOW()
       WHERE id = $2 AND conversation_id = $3 AND sender_id = $4
       RETURNING *`,
      [text || '', req.params.messageId, req.params.convId, req.user.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'Message not found' } });
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
        `INSERT INTO message_reads (message_id, user_id)
         SELECT UNNEST($1::uuid[]), $2
         ON CONFLICT DO NOTHING`,
        [messageIds, req.user.id]
      );
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
