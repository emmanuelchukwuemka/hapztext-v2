const router = require('express').Router();
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

module.exports = router;
