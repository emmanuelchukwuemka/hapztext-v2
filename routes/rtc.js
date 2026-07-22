const router = require('express').Router();
const pool = require('../db');
const authMw = require('../middleware/auth');
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

router.get('/token', authMw, async (req, res) => {
  const channel = (req.query.channel || '').toString().trim();
  const uid = parseInt(req.query.uid) || 0;
  const roleStr = (req.query.role || 'audience').toString().toLowerCase();
  const expireSeconds = Math.min(parseInt(req.query.expireSeconds) || 3600, 24 * 3600);

  if (!channel) return res.status(400).json({ errors: { detail: 'channel is required' } });

  const appId = process.env.AGORA_APP_ID;
  const appCertificate = process.env.AGORA_APP_CERTIFICATE;
  if (!appId || !appCertificate) {
    return res.status(500).json({ errors: { detail: 'Agora is not configured' } });
  }

  const role = roleStr === 'broadcaster' ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;
  const expireAt = Math.floor(Date.now() / 1000) + expireSeconds;
  const token = RtcTokenBuilder.buildTokenWithUid(appId, appCertificate, channel, uid, role, expireAt);

  return res.json({ data: { token, appId, channel, uid, expireAt } });
});

// POST /rtc/invite  { targetUserId, channel, callType: 'audio' | 'video' }
router.post('/invite', authMw, async (req, res) => {
  const { targetUserId, channel, callType } = req.body || {};
  if (!targetUserId || !channel) {
    return res.status(400).json({ errors: { detail: 'targetUserId and channel are required' } });
  }
  const type = (callType === 'video') ? 'video' : 'audio';
  try {
    // Enforce the callee's declared chat_mode: block the invite if they've
    // restricted themselves to text or voice notes only.
    const convR = await pool.query(
      `SELECT cp1.conversation_id AS id
       FROM conversation_participants cp1
       JOIN conversation_participants cp2
         ON cp1.conversation_id = cp2.conversation_id AND cp2.user_id = $2
       WHERE cp1.user_id = $1
         AND (SELECT COUNT(*) FROM conversation_participants WHERE conversation_id = cp1.conversation_id) = 2
       LIMIT 1`,
      [req.user.id, targetUserId]
    );
    const convId = convR.rows[0]?.id;
    if (convId) {
      const modeR = await pool.query(
        'SELECT chat_mode FROM conversation_user_settings WHERE conversation_id = $1 AND user_id = $2',
        [convId, targetUserId]
      );
      const targetMode = modeR.rows[0]?.chat_mode || 'mixed';
      if (targetMode === 'textOnly' || targetMode === 'voiceOnly') {
        const targetP = await pool.query('SELECT username FROM profiles WHERE user_id = $1', [targetUserId]);
        const targetName = targetP.rows[0]?.username || 'This user';
        const modeLabel = targetMode === 'textOnly' ? 'text messages' : 'voice notes';
        return res.status(422).json({
          errors: { detail: `This call won't go through — ${targetName} only accepts ${modeLabel}.` },
        });
      }
    }

    const callerP = await pool.query('SELECT username FROM profiles WHERE user_id = $1', [req.user.id]);
    const callerUsername = callerP.rows[0]?.username || 'Someone';
    const r = await pool.query(
      `INSERT INTO notifications (user_id, type, payload) VALUES ($1,'call_invite',$2) RETURNING *`,
      [targetUserId, JSON.stringify({
        actor_id: req.user.id,
        actor_username: callerUsername,
        channel,
        call_type: type,
        message: `${callerUsername} is calling you`,
      })]
    );
    return res.status(201).json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

module.exports = router;
