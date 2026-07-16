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
