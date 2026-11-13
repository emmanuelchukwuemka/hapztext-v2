const router = require('express').Router();
const pool = require('../db');
const authMw = require('../middleware/auth');
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');
const presence = require('../realtime/presence');

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
    const payload = {
      actor_id: req.user.id,
      actor_username: callerUsername,
      channel,
      call_type: type,
      message: `${callerUsername} is calling you`,
    };
    const r = await pool.query(
      `INSERT INTO notifications (user_id, type, payload) VALUES ($1,'call_invite',$2) RETURNING *`,
      [targetUserId, JSON.stringify(payload)]
    );
    // Deliver in real time if the callee's app is open right now — this is
    // what actually rings them, instead of relying on them noticing the
    // notification and tapping it manually.
    presence.sendToUser(targetUserId, 'incoming_call', payload);
    return res.status(201).json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

function formatCallDuration(seconds) {
  const s = Math.max(0, Math.round(seconds || 0));
  const m = Math.floor(s / 60);
  const r = s % 60;
  return `${m}:${r.toString().padStart(2, '0')}`;
}

// POST /rtc/log-call — called by the callee once a call ends, so missed and
// received calls show up in *their* activity feed. Before this, call_invite
// above was the only thing ever persisted — nothing recorded whether a call
// was actually answered, or for how long.
router.post('/log-call', authMw, async (req, res) => {
  const { callerId, callType, status, durationSeconds } = req.body || {};
  if (!callerId || !status) {
    return res.status(400).json({ errors: { detail: 'callerId and status are required' } });
  }
  try {
    const callerP = await pool.query('SELECT username FROM profiles WHERE user_id = $1', [callerId]);
    const callerUsername = callerP.rows[0]?.username || 'Someone';
    const type = callType === 'video' ? 'video' : 'audio';
    const missed = status === 'missed';
    const message = missed
      ? `Missed ${type === 'video' ? 'video call' : 'call'} from ${callerUsername}`
      : `${type === 'video' ? 'Video call' : 'Call'} with ${callerUsername} · ${formatCallDuration(durationSeconds)}`;
    const payload = {
      actor_id: callerId,
      actor_username: callerUsername,
      call_type: type,
      duration_seconds: Math.max(0, Math.round(durationSeconds || 0)),
      message,
    };
    const r = await pool.query(
      `INSERT INTO notifications (user_id, type, payload) VALUES ($1,$2,$3) RETURNING *`,
      [req.user.id, missed ? 'call_missed' : 'call_received', JSON.stringify(payload)]
    );
    return res.status(201).json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

module.exports = router;
