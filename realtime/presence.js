// Tracks which socket(s) belong to which logged-in user, and relays WebRTC
// call signaling (offer/answer/ICE/reject/end) directly between two users'
// sockets. This server never inspects or stores call audio/video — it only
// passes SDP/ICE messages through, so no Agora/TURN credentials are needed
// (STUN, configured client-side, is enough to traverse most NATs).
const jwt = require('jsonwebtoken');
const pool = require('../db');

const userSockets = new Map(); // userId -> Set<socket.id>
let ioRef = null;

// A call_offer for someone who isn't connected right now (locked/backgrounded
// app, brief network drop) is held here so it can be redelivered the instant
// that device reconnects, instead of being lost the moment the first relay
// attempt finds no live socket.
const pendingCallOffers = new Map(); // userId -> { data, expiresAt }
const CALL_RING_TIMEOUT_MS = 5 * 60 * 1000;

function attach(io) {
  ioRef = io;
  io.on('connection', (socket) => {
    socket.on('authenticate', (token) => {
      try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        socket.data.userId = decoded.id;
        if (!userSockets.has(decoded.id)) userSockets.set(decoded.id, new Set());
        userSockets.get(decoded.id).add(socket.id);

        const pending = pendingCallOffers.get(decoded.id);
        if (pending) {
          pendingCallOffers.delete(decoded.id);
          if (pending.expiresAt > Date.now()) {
            socket.emit('call_offer', pending.data);
          }
        }
      } catch (e) {
        // invalid/expired token — leave socket unauthenticated, no crash
      }
    });

    socket.on('disconnect', () => {
      const userId = socket.data.userId;
      if (!userId) return;
      const set = userSockets.get(userId);
      if (set) {
        set.delete(socket.id);
        if (set.size === 0) userSockets.delete(userId);
      }
    });

    // ─── WebRTC call signaling ────────────────────────────────────────
    socket.on('call_offer', async (data) => {
      const fromId = socket.data.userId;
      if (!fromId || !data || !data.toId || !data.callId) return;
      try {
        // Enforce the callee's declared chat_mode the same way the old
        // REST /rtc/invite endpoint did.
        if (data.conversationId) {
          const modeR = await pool.query(
            'SELECT chat_mode FROM conversation_user_settings WHERE conversation_id = $1 AND user_id = $2',
            [data.conversationId, data.toId]
          );
          const targetMode = modeR.rows[0]?.chat_mode || 'mixed';
          if (targetMode === 'textOnly' || targetMode === 'voiceOnly') {
            const targetP = await pool.query('SELECT username FROM profiles WHERE user_id = $1', [data.toId]);
            const targetName = targetP.rows[0]?.username || 'This user';
            const modeLabel = targetMode === 'textOnly' ? 'text messages' : 'voice notes';
            socket.emit('call_unavailable', {
              callId: data.callId,
              toId: data.toId,
              reason: `${targetName} only accepts ${modeLabel}.`,
            });
            return;
          }
        }

        const payload = { ...data, fromId };
        const targetSet = userSockets.get(data.toId);
        if (!targetSet || !targetSet.size) {
          pendingCallOffers.set(data.toId, {
            data: payload,
            expiresAt: Date.now() + CALL_RING_TIMEOUT_MS,
          });
          socket.emit('call_unavailable', {
            callId: data.callId,
            toId: data.toId,
            reason: 'not connected right now',
          });
          return;
        }
        for (const socketId of targetSet) ioRef.to(socketId).emit('call_offer', payload);
      } catch (e) {
        console.error('call_offer relay error:', e.message);
      }
    });

    socket.on('call_answer', (data) => {
      const fromId = socket.data.userId;
      if (!fromId || !data || !data.toId) return;
      sendToUser(data.toId, 'call_answer', { ...data, fromId });
    });

    socket.on('call_ice_candidate', (data) => {
      const fromId = socket.data.userId;
      if (!fromId || !data || !data.toId) return;
      sendToUser(data.toId, 'call_ice_candidate', { ...data, fromId });
    });

    socket.on('call_reject', (data) => {
      const fromId = socket.data.userId;
      if (!fromId || !data || !data.toId) return;
      sendToUser(data.toId, 'call_reject', { ...data, fromId });
    });

    socket.on('call_end', (data) => {
      const fromId = socket.data.userId;
      if (!fromId || !data || !data.toId) return;
      sendToUser(data.toId, 'call_end', { ...data, fromId });
    });
  });
}

function sendToUser(userId, event, payload) {
  if (!ioRef) return;
  const set = userSockets.get(userId);
  if (!set || !set.size) return;
  for (const socketId of set) {
    ioRef.to(socketId).emit(event, payload);
  }
}

module.exports = { attach, sendToUser };
