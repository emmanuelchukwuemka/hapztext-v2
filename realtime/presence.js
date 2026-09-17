// Tracks which socket(s) belong to which logged-in user, and relays WebRTC
// call signaling (offer/answer/ICE/reject/end) directly between two users'
// sockets. This server never inspects or stores call audio/video — it only
// passes SDP/ICE messages through, so no Agora/TURN credentials are needed
// (STUN, configured client-side, is enough to traverse most NATs).
const jwt = require('jsonwebtoken');
const pool = require('../db');

const userSockets = new Map(); // userId -> Set<socket.id>
let ioRef = null;

// ─── Age safety ─────────────────────────────────────────────────────────────
// profiles.birth_date is stored as real 'YYYY-MM-DD' text from signup, so age
// can be computed for real — no separate date-of-birth column was needed.
async function getAge(userId) {
  try {
    const r = await pool.query(
      `SELECT DATE_PART('year', AGE(birth_date::date))::int AS age
       FROM profiles WHERE user_id = $1 AND birth_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'`,
      [userId]
    );
    return r.rows[0]?.age ?? null;
  } catch (e) {
    return null;
  }
}

// Minors (0-17) may only ever be matched with other minors, no more than 4
// years apart; adults (18+) only with other adults. A user with no birth_date
// on file defaults to the adult bucket — otherwise random calls would be
// unusable for the (likely large) share of accounts that never filled it in.
function isAgeCompatible(ageA, ageB) {
  const aMinor = ageA != null && ageA < 18;
  const bMinor = ageB != null && ageB < 18;
  if (aMinor !== bMinor) return false;
  if (aMinor && bMinor) return Math.abs(ageA - ageB) <= 4;
  return true;
}

function emitToAdmins(event, payload) {
  if (!ioRef) return;
  ioRef.to('admin_room').emit(event, payload);
}

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
    const [callerAge, calleeAge] = await Promise.all([getAge(callerId), getAge(calleeId)]);
    const ageAlert = !isAgeCompatible(callerAge, calleeAge);
    const ageAlertReason = !ageAlert
      ? null
      : callerAge != null && calleeAge != null
        ? `Minor (${Math.min(callerAge, calleeAge)}) matched with ${
            Math.max(callerAge, calleeAge) >= 18 ? 'Adult' : 'user'
          } (${Math.max(callerAge, calleeAge)})`
        : 'Age could not be verified for one or both participants';

    const r = await pool.query(
      `INSERT INTO calls
         (caller_id, callee_id, call_type, is_discover, status, caller_age, callee_age, age_alert, age_alert_reason)
       VALUES ($1,$2,$3,$4,'ringing',$5,$6,$7,$8) RETURNING id`,
      [callerId, calleeId, isVideo ? 'video' : 'voice', !!isDiscover, callerAge, calleeAge, ageAlert, ageAlertReason]
    );
    callRecords.set(callId, {
      dbId: r.rows[0].id,
      callerId,
      calleeId,
      callType: isVideo ? 'video' : 'voice',
      isDiscover: !!isDiscover,
      startedAt: Date.now(),
      ageAlert,
      ageAlertReason,
    });

    // The doc's single most critical safety requirement: push this to any
    // connected admin immediately so a human can end the call right away,
    // not just whenever someone happens to refresh the dashboard.
    if (ageAlert) {
      emitToAdmins('call:age_alert', {
        callId,
        dbId: r.rows[0].id,
        callerId,
        calleeId,
        callerAge,
        calleeAge,
        reason: ageAlertReason,
      });
      pool
        .query(
          `INSERT INTO admin_audit_logs (action, target_type, target_id, meta)
           VALUES ('AGE_ALERT', 'call', $1, $2)`,
          [r.rows[0].id, JSON.stringify({ callerId, calleeId, callerAge, calleeAge, reason: ageAlertReason })]
        )
        .catch(() => {});
    }
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
    dbId: rec.dbId,
    callerId: rec.callerId,
    calleeId: rec.calleeId,
    callType: rec.callType,
    isDiscover: rec.isDiscover,
    durationSeconds: Math.floor((Date.now() - rec.startedAt) / 1000),
    ageAlert: rec.ageAlert,
    ageAlertReason: rec.ageAlertReason,
  }));
}

// Admin-triggered "END IMMEDIATELY" — tells both participants' real sockets
// to hang up (not just marking the DB row dead), since the whole point of
// the critical-age-alert flow is stopping the call itself right now.
function adminEndCall(dbCallId, adminId, reason) {
  for (const [clientCallId, rec] of callRecords.entries()) {
    if (rec.dbId !== dbCallId) continue;
    sendToUser(rec.callerId, 'call_end', { callId: clientCallId, toId: rec.callerId, fromId: 'admin' });
    sendToUser(rec.calleeId, 'call_end', { callId: clientCallId, toId: rec.calleeId, fromId: 'admin' });
    pool
      .query(
        `UPDATE calls SET status = 'ended', ended_at = NOW(), end_reason = $2, ended_by = $3 WHERE id = $1`,
        [dbCallId, reason || 'admin_action', adminId]
      )
      .catch((e) => console.error('adminEndCall update error:', e.message));
    callRecords.delete(clientCallId);
    return true;
  }
  return false;
}

function attach(io) {
  ioRef = io;
  io.on('connection', (socket) => {
    socket.on('authenticate', async (token) => {
      try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        socket.data.userId = decoded.id;
        if (!userSockets.has(decoded.id)) userSockets.set(decoded.id, new Set());
        userSockets.get(decoded.id).add(socket.id);

        // Admins get a room so age-alerts and other safety events can be
        // pushed live instead of only appearing on the next dashboard poll.
        try {
          const r = await pool.query('SELECT is_admin FROM users WHERE id = $1', [decoded.id]);
          if (r.rows[0]?.is_admin) socket.join('admin_room');
        } catch (_) {}

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

      const restrictedR = await pool.query('SELECT calls_restricted FROM users WHERE id = $1', [userId]).catch(() => null);
      if (restrictedR?.rows[0]?.calls_restricted) {
        socket.emit('call_unavailable', { reason: 'Random calls have been restricted on this account.' });
        return;
      }

      const myAge = await getAge(userId);

      // Never just take whoever's next in line — search for the longest-
      // waiting candidate that's actually safe to pair with. Age safety is
      // enforced here at the match itself, not just flagged after the fact.
      let partnerIdx = -1;
      let partner = null;
      for (let i = 0; i < discoverQueue.length; i++) {
        const candidate = discoverQueue[i];
        if (candidate.userId === userId) continue;
        if (isAgeCompatible(myAge, candidate.age)) {
          partnerIdx = i;
          partner = candidate;
          break;
        }
      }

      if (partnerIdx === -1) {
        discoverQueue.push({ userId, isVideo, age: myAge });
        return;
      }
      discoverQueue.splice(partnerIdx, 1);

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

module.exports = { attach, sendToUser, getActiveUserCount, getLiveCalls, adminEndCall, emitToAdmins };
