// Socket.IO realtime layer for livestream comments/gifts/reactions/viewer counts.
// Each stream gets a room named `stream:<channelId>`. Viewer count excludes
// the streamer's own socket.

module.exports = function attachLivestreamRealtime(io) {
  // channelId -> streamer socket.id (undefined if unknown/viewer-only room)
  const streamerBySocket = new Map(); // socket.id -> channelId (as broadcaster)

  const roomName = (channelId) => `stream:${channelId}`;

  function viewerCount(channelId) {
    const room = io.sockets.adapter.rooms.get(roomName(channelId));
    if (!room) return 0;
    let count = room.size;
    for (const socketId of room) {
      if (streamerBySocket.get(socketId) === channelId) count -= 1;
    }
    return Math.max(count, 0);
  }

  function broadcastViewerCount(channelId) {
    io.to(roomName(channelId)).emit('viewer_count_update', {
      viewer_count: viewerCount(channelId),
    });
  }

  io.on('connection', (socket) => {
    socket.on('join_stream', ({ channelId, username, isStreamer }) => {
      if (!channelId) return;
      socket.data.channelId = channelId;
      socket.data.username = username || 'Someone';
      socket.join(roomName(channelId));
      if (isStreamer) streamerBySocket.set(socket.id, channelId);
      socket.to(roomName(channelId)).emit('viewer_joined', {
        username: socket.data.username,
      });
      broadcastViewerCount(channelId);
    });

    socket.on('leave_stream', () => {
      const channelId = socket.data.channelId;
      if (!channelId) return;
      socket.leave(roomName(channelId));
      streamerBySocket.delete(socket.id);
      socket.to(roomName(channelId)).emit('viewer_left', {
        username: socket.data.username,
      });
      broadcastViewerCount(channelId);
      socket.data.channelId = null;
    });

    socket.on('send_comment', ({ channelId, text, comment_type, duration }) => {
      if (!channelId || !text) return;
      socket.to(roomName(channelId)).emit('new_comment', {
        username: socket.data.username || 'Someone',
        text,
        comment_type: comment_type || 'text',
        duration: duration || '',
      });
    });

    socket.on('send_gift', ({ channelId, gift_type }) => {
      if (!channelId) return;
      socket.to(roomName(channelId)).emit('new_comment', {
        username: socket.data.username || 'Someone',
        text: `sent ${gift_type || 'a gift'}`,
        comment_type: 'gift',
      });
    });

    socket.on('send_reaction', ({ channelId, emoji }) => {
      if (!channelId) return;
      socket.to(roomName(channelId)).emit('new_comment', {
        username: socket.data.username || 'Someone',
        text: `reacted ${emoji || ''}`.trim(),
        comment_type: 'text',
      });
    });

    socket.on('disconnect', () => {
      const channelId = socket.data.channelId;
      if (!channelId) return;
      streamerBySocket.delete(socket.id);
      socket.to(roomName(channelId)).emit('viewer_left', {
        username: socket.data.username,
      });
      broadcastViewerCount(channelId);
    });
  });
};
