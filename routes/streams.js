const router = require('express').Router();
const authMw = require('../middleware/auth');

// In-memory stream registry (resets on server restart — sufficient for live sessions)
const activeStreams = new Map();

// POST /streams — register a new live stream
router.post('/', authMw, async (req, res) => {
  const { channelId, streamerUsername } = req.body;
  if (!channelId) return res.status(400).json({ errors: { detail: 'channelId required' } });
  activeStreams.set(channelId, {
    channelId,
    streamerId: req.user.id,
    streamerUsername: streamerUsername || 'Unknown',
    startedAt: new Date().toISOString(),
  });
  return res.json({ success: true });
});

// DELETE /streams/:channelId — remove a stream when it ends
router.delete('/:channelId', authMw, async (req, res) => {
  activeStreams.delete(req.params.channelId);
  return res.json({ success: true });
});

// GET /streams — list active streams
router.get('/', authMw, async (req, res) => {
  const streams = Array.from(activeStreams.values());
  return res.json({ data: { streams } });
});

module.exports = router;