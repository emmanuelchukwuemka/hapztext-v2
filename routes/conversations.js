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
        const [partR, msgR, settingsR, otherSettingsR, unreadR] = await Promise.all([
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
          // Other participant's chat_mode — only meaningful for 1-on-1 chats.
          // This is what tells *this* user how the other person wants to be
          // contacted (their declared restriction), not the other way round.
          pool.query(
            `SELECT cus.chat_mode
             FROM conversation_participants cp
             LEFT JOIN conversation_user_settings cus
               ON cus.conversation_id = cp.conversation_id AND cus.user_id = cp.user_id
             WHERE cp.conversation_id = $1 AND cp.user_id <> $2`,
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
        const otherChatMode = otherSettingsR.rows.length === 1
          ? (otherSettingsR.rows[0].chat_mode || defaultSettings.chat_mode)
          : null;
        return {
          id: convId,
          participants: partR.rows,
          last_message: msgR.rows[0] || null,
          settings,
          other_chat_mode: otherChatMode,
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

    // A partial body (e.g. { chatMode: 'mixed' } from the quick-change menu)
    // must only touch the fields it actually sent — the previous version
    // unconditionally overwrote every column with a hardcoded default for
    // anything omitted, so changing just the chat mode silently reset the
    // theme/disappearing/auto-clear settings back to defaults every time.
    // COALESCE against the existing row (falling back to hardcoded defaults
    // only for a brand-new row) fixes that.
    const r = await pool.query(
      `INSERT INTO conversation_user_settings
        (conversation_id, user_id, pinned, muted, chat_mode, disappearing, auto_clear_enabled,
         auto_clear_start, auto_clear_end, theme_index, notification_tone)
       VALUES
        ($1,$2,
         COALESCE($3, $12), COALESCE($4, $13), COALESCE($5, $14), COALESCE($6, $15),
         COALESCE($7, $16), $8, $9, COALESCE($10, $17), $11)
       ON CONFLICT (conversation_id, user_id)
       DO UPDATE SET
        pinned = COALESCE($3, conversation_user_settings.pinned),
        muted = COALESCE($4, conversation_user_settings.muted),
        chat_mode = COALESCE($5, conversation_user_settings.chat_mode),
        disappearing = COALESCE($6, conversation_user_settings.disappearing),
        auto_clear_enabled = COALESCE($7, conversation_user_settings.auto_clear_enabled),
        auto_clear_start = COALESCE($8, conversation_user_settings.auto_clear_start),
        auto_clear_end = COALESCE($9, conversation_user_settings.auto_clear_end),
        theme_index = COALESCE($10, conversation_user_settings.theme_index),
        notification_tone = COALESCE($11, conversation_user_settings.notification_tone),
        updated_at = NOW()
       RETURNING pinned, muted, chat_mode, disappearing, auto_clear_enabled,
                 auto_clear_start, auto_clear_end, theme_index, notification_tone`,
      [
        req.params.convId,
        req.user.id,
        pinned ?? null,
        muted ?? null,
        chatMode ? normalizeChatMode(chatMode) : null,
        disappearing ? normalizeDisappearing(disappearing) : null,
        autoClearEnabled ?? null,
        autoClearStart ?? null,
        autoClearEnd ?? null,
        themeIndex ?? null,
        notificationTone ?? null,
        defaultSettings.pinned,
        defaultSettings.muted,
        defaultSettings.chat_mode,
        defaultSettings.disappearing,
        defaultSettings.auto_clear_enabled,
        defaultSettings.theme_index,
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

    // Opportunistic cleanup — no cron needed, expired rows just get swept the
    // next time anyone opens this conversation.
    await pool.query(
      'DELETE FROM messages WHERE conversation_id = $1 AND disappear_at IS NOT NULL AND disappear_at <= NOW()',
      [req.params.convId]
    );

    const r = await pool.query(
      `SELECT m.*, p.username AS previous_message_sender_username,
              p2.username AS previous_message_sender_username_2
       FROM messages m
       LEFT JOIN profiles p ON p.user_id = m.previous_message_sender_id
       LEFT JOIN profiles p2 ON p2.user_id = m.previous_message_sender_id_2
       WHERE m.conversation_id = $1
       ORDER BY m.created_at DESC LIMIT $2 OFFSET $3`,
      [req.params.convId, size, offset]
    );
    // A view-once media message stops being servable to anyone but its
    // sender the instant it's been consumed — the row stays for history,
    // just with media_url nulled out for the recipient.
    const rows = r.rows.map((row) => {
      if (row.view_once && row.view_once_consumed_at && row.sender_id !== req.user.id) {
        return { ...row, media_url: null };
      }
      return row;
    });
    return res.json({ data: { result: rows } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /conversations/:convId/messages
const disappearingDurationMs = {
  fiveSeconds: 5 * 1000,
  oneHour: 60 * 60 * 1000,
  oneDay: 24 * 60 * 60 * 1000,
};

router.post('/:convId/messages', authMw, async (req, res) => {
  const { text, type, mediaUrl, isReply, previousMessageId, previousMessageId2, viewOnce, disappearing } = req.body;
  try {
    const partR = await pool.query(
      'SELECT user_id FROM conversation_participants WHERE conversation_id = $1',
      [req.params.convId]
    );
    if (!partR.rows.some((row) => row.user_id === req.user.id))
      return res.status(403).json({ errors: { detail: 'Not a participant' } });

    // Enforce the recipient's declared chat_mode for 1-on-1 conversations
    // (skip for group chats — no single "the recipient" to check against).
    const others = partR.rows.map((row) => row.user_id).filter((id) => id !== req.user.id);
    if (others.length === 1) {
      const modeR = await pool.query(
        'SELECT chat_mode FROM conversation_user_settings WHERE conversation_id = $1 AND user_id = $2',
        [req.params.convId, others[0]]
      );
      const recipientMode = modeR.rows[0]?.chat_mode || 'mixed';
      const msgType = (type || 'text').toLowerCase();
      const blocked =
        recipientMode === 'callsOnly' ||
        (recipientMode === 'textOnly' && msgType !== 'text') ||
        (recipientMode === 'voiceOnly' && msgType !== 'audio');
      if (blocked) {
        const recipientP = await pool.query('SELECT username FROM profiles WHERE user_id = $1', [others[0]]);
        const recipientName = recipientP.rows[0]?.username || 'This user';
        const modeLabel =
          { textOnly: 'text messages', voiceOnly: 'voice notes', callsOnly: 'calls' }[recipientMode] ||
          recipientMode;
        return res.status(422).json({
          errors: { detail: `This won't be delivered — ${recipientName} only accepts ${modeLabel}.` },
        });
      }
    }

    // Snapshot the quoted message(s) server-side (not trusting whatever the
    // client claims it said) so the reply preview survives edits/deletes and
    // reloads on any device. Up to 2 quotes (multi-reply).
    async function snapshotQuote(id) {
      if (!id) return { content: null, senderId: null };
      const prevR = await pool.query(
        'SELECT sender_id, message_type, text_content FROM messages WHERE id = $1 AND conversation_id = $2',
        [id, req.params.convId]
      );
      const prev = prevR.rows[0];
      if (!prev) return { content: null, senderId: null };
      const typeLabel = { image: 'Photo', video: 'Video', audio: 'Voice Note' }[prev.message_type];
      return { content: typeLabel || prev.text_content || '', senderId: prev.sender_id };
    }
    const quote1 = isReply ? await snapshotQuote(previousMessageId) : { content: null, senderId: null };
    const quote2 = isReply ? await snapshotQuote(previousMessageId2) : { content: null, senderId: null };

    const disappearMs = disappearingDurationMs[disappearing];
    const disappearAt = disappearMs ? new Date(Date.now() + disappearMs) : null;

    const r = await pool.query(
      `INSERT INTO messages
         (conversation_id, sender_id, message_type, text_content, media_url, is_reply,
          previous_message_id, previous_message_content, previous_message_sender_id,
          previous_message_id_2, previous_message_content_2, previous_message_sender_id_2,
          view_once, disappear_at, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,'sent') RETURNING *`,
      [req.params.convId, req.user.id,
       type || 'text', text || '',
       mediaUrl || null,
       isReply || false,
       previousMessageId || null,
       quote1.content,
       quote1.senderId,
       previousMessageId2 || null,
       quote2.content,
       quote2.senderId,
       viewOnce === true,
       disappearAt]
    );

    const actorR = await pool.query('SELECT username FROM profiles WHERE user_id = $1', [req.user.id]);
    const actorUsername = actorR.rows[0]?.username || 'Someone';
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

// DELETE /conversations/:convId/messages/:messageId — sender only, matching
// the long-press "Delete" menu (which only ever offers this on your own
// messages) and the auto-clear sweep (which only deletes its own out-of-
// window sends server-side for the same reason).
router.delete('/:convId/messages/:messageId', authMw, async (req, res) => {
  try {
    const r = await pool.query(
      'DELETE FROM messages WHERE id = $1 AND conversation_id = $2 AND sender_id = $3 RETURNING id',
      [req.params.messageId, req.params.convId, req.user.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'Message not found' } });
    return res.json({ success: true });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /conversations/:convId/messages/:messageId/view-once
// Called the instant the recipient actually opens a view-once photo/video.
// Stamps it consumed so GET /messages stops returning the media_url to
// anyone but the sender from that point on — real one-time viewing, not
// just a local "already tapped" flag that resets on reload.
router.post('/:convId/messages/:messageId/view-once', authMw, async (req, res) => {
  try {
    const check = await pool.query(
      'SELECT 1 FROM conversation_participants WHERE conversation_id = $1 AND user_id = $2',
      [req.params.convId, req.user.id]
    );
    if (!check.rows.length)
      return res.status(403).json({ errors: { detail: 'Not a participant' } });

    const r = await pool.query(
      `UPDATE messages
       SET view_once_consumed_at = NOW()
       WHERE id = $1 AND conversation_id = $2 AND view_once = TRUE
         AND sender_id != $3 AND view_once_consumed_at IS NULL
       RETURNING media_url`,
      [req.params.messageId, req.params.convId, req.user.id]
    );
    if (!r.rows.length) {
      // Either not a view-once message, already consumed, or the sender
      // trying to "view" their own send — nothing to reveal in any case.
      return res.status(410).json({ errors: { detail: 'No longer available' } });
    }
    return res.json({ success: true, data: { mediaUrl: r.rows[0].media_url } });
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
