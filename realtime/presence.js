// Tracks which socket(s) belong to which logged-in user, so other parts of
// the backend (e.g. the /rtc/invite route) can push a real-time event
// straight to a specific user — this is what actually delivers an incoming
// call while the app is open, instead of relying on the callee to notice a
// notification and tap it manually.
const jwt = require('jsonwebtoken');

const userSockets = new Map(); // userId -> Set<socket.id>
let ioRef = null;

function attach(io) {
  ioRef = io;
  io.on('connection', (socket) => {
    socket.on('authenticate', (token) => {
      try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        socket.data.userId = decoded.id;
        if (!userSockets.has(decoded.id)) userSockets.set(decoded.id, new Set());
        userSockets.get(decoded.id).add(socket.id);
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
