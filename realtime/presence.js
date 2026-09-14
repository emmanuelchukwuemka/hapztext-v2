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

// "Discover" random-match queue: whoever is waiting longest gets paired with
// the next person who joins. Purely in-memory — a match is just an
// introduction; the actual call still goes over the same WebRTC signaling
// above, so no separate media relay is needed here.
const discoverQueue = []; // [{ userId, isVideo }]

function removeFromDiscoverQueue(userId) {
  const idx = discoverQueue.findIndex((w) => w.userId === userId);
  if (idx !== -1) discoverQueue.splice(idx, 1);
}

// Call history — presence.js never persisted anything before (pure signaling
// relay), so an admin dashboard had zero real data to show for calls. This
// map bridges the client's own callId (a timestamp-based string, not a UUID)
// to the real `calls` row it corresponds to.
const callRecords = new Map(); // clientCallId -> { dbId, callerId, calleeId, callType, isDiscover, startedAt }

async function logCallStart({ callId, callerId, calleeId, isVideo, isDiscover }) {
  try {
    const r = await pool.query(
      `INSERT INTO calls (caller_id, callee_id, call_type, is_discover, status)
       VALUES ($1,$2,$3,$4,'ringing') RETURNING id`,
      [callerId, calleeId, isVideo ? 'video' : 'voice', !!isDiscover]
    );
    callRecords.set(callId, {
      dbId: r.rows[0].id,
      callerId,
      calleeId,
      callType: isVideo ? 'video' : 'voice',
      isDiscover: !!isDiscover,
      startedAt: Date.now(),
    });
  } catch (e) {
    console.error('call log start error:', e.message);
  }
}

async function logCallUpdate(callId, status, { connected = false, ended = false } = {}) {
  const rec = callRecords.get(callId);
  if (!rec) return;
  try {
    const sets = ['status = $2'];
    if (connected) sets.push('connected_at = NOW()');
    if (ended) sets.push('ended_at = NOW()');
    await pool.query(`UPDATE calls SET ${sets.join(', ')} WHERE id = $1`, [rec.dbId, status]);
  } catch (e) {
    console.error('call log update error:', e.message);
  }
  if (ended) callRecords.delete(callId);
}

// Read-only accessors for the admin dashboard (routes/admin.js) — kept here
// instead of querying the DB for "live" state since in-progress calls only
// really exist in this module's memory until they end.
function getActiveUserCount() {
  return userSockets.size;
}

function getLiveCalls() {
  return Array.from(callRecords.entries()).map(([callId, rec]) => ({
    callId,
    callerId: rec.callerId,
    calleeId: rec.calleeId,
    callType: rec.callType,
    isDiscover: rec.isDiscover,
    durationSeconds: Math.floor((Date.now() - rec.startedAt) / 1000),
  }));
}

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
      removeFromDiscoverQueue(userId);
    });

    // ─── Discover random-match queue ─────────────────────────────────
    socket.on('discover_join', async (data) => {
      const userId = socket.data.userId;
      if (!userId) return;
      removeFromDiscoverQueue(userId);
      const isVideo = data?.isVideo !== false;

      const partnerIdx = discoverQueue.findIndex((w) => w.userId !== userId);
      if (partnerIdx === -1) {
        discoverQueue.push({ userId, isVideo });
        return;
      }
      const partner = discoverQueue.splice(partnerIdx, 1)[0];

      try {
        const [meRes, partnerRes] = await Promise.all([
          pool.query('SELECT username, profile_picture FROM profiles WHERE user_id = $1', [userId]),
          pool.query('SELECT username, profile_picture FROM profiles WHERE user_id = $1', [partner.userId]),
        ]);
        const me = meRes.rows[0] || {};
        const them = partnerRes.rows[0] || {};

        sendToUser(partner.userId, 'discover_matched', {
          matchedUserId: userId,
          matchedUsername: me.username || 'Someone',
          matchedProfilePicture: me.profile_picture || null,
          isCaller: true,
        });
        socket.emit('discover_matched', {
          matchedUserId: partner.userId,
          matchedUsername: them.username || 'Someone',
          matchedProfilePicture: them.profile_picture || null,
          isCaller: false,
        });
      } catch (e) {
        console.error('discover_join match error:', e.message);
        // Put both back so neither is stranded on a failed match attempt
        discoverQueue.push(partner);
      }
    });

    socket.on('discover_leave', () => {
      const userId = socket.data.userId;
      if (!userId) return;
      removeFromDiscoverQueue(userId);
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
        // Log the dial attempt regardless of outcome — a real admin metric
        // counts missed/rejected calls too, not just ones that connected.
        await logCallStart({
          callId: data.callId,
          callerId: fromId,
          calleeId: data.toId,
          isVideo: data.isVideo === true,
          isDiscover: data.isDiscover === true,
        });

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
          logCallUpdate(data.callId, 'unavailable', { ended: true });
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
      if (data.callId) logCallUpdate(data.callId, 'active', { connected: true });
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
      if (data.callId) logCallUpdate(data.callId, 'rejected', { ended: true });
    });

    socket.on('call_end', (data) => {
      const fromId = socket.data.userId;
      if (!fromId || !data || !data.toId) return;
      sendToUser(data.toId, 'call_end', { ...data, fromId });
      if (data.callId) logCallUpdate(data.callId, 'ended', { ended: true });
    });

    // Floating emoji reactions during a call — purely cosmetic, so this is a
    // best-effort relay with no persistence, same shape as ICE relaying.
    socket.on('call_reaction', (data) => {
      const fromId = socket.data.userId;
      if (!fromId || !data || !data.toId || !data.emoji) return;
      sendToUser(data.toId, 'call_reaction', { ...data, fromId });
    });

    // Mini text chat shown alongside a Discover call — not stored, just
    // relayed live between the two matched participants.
    socket.on('discover_message', (data) => {
      const fromId = socket.data.userId;
      if (!fromId || !data || !data.toId || !data.text) return;
      sendToUser(data.toId, 'discover_message', { ...data, fromId });
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

module.exports = { attach, sendToUser, getActiveUserCount, getLiveCalls };
