const router = require('express').Router();
const pool = require('../db');
const authMw = require('../middleware/auth');
const { v4: uuidv4 } = require('uuid');

const EDIT_WINDOW_SQL = "INTERVAL '20 minutes'";
const COMMENT_WINDOW_MS = 3 * 24 * 60 * 60 * 1000;

// GET /events?category=Sports — active (not cancelled/expired) events,
// newest first, with attendee count + this user's join/host state.
router.get('/', authMw, async (req, res) => {
  try {
    const category = (req.query.category || '').toString();
    const params = [req.user.id];
    let where = `e.cancelled_at IS NULL AND (e.expires_at IS NULL OR e.expires_at > NOW())`;
    if (category && category.toLowerCase() !== 'all') {
      params.push(category);
      where += ` AND e.category = $${params.length}`;
    }
    const r = await pool.query(
      `SELECT e.*,
              hp.username AS host_username,
              (SELECT COUNT(*) FROM event_attendees ea WHERE ea.event_id = e.id) AS guest_count,
              EXISTS(SELECT 1 FROM event_attendees ea WHERE ea.event_id = e.id AND ea.user_id = $1) AS joined,
              (e.host_id = $1) AS is_host,
              -- Events this host ran *before* this one — excludes the row
              -- itself, so a brand-new host's first event correctly reads 0
              -- instead of counting itself as "1 hosted before".
              (SELECT COUNT(*) FROM events e2
                WHERE e2.host_id = e.host_id AND e2.cancelled_at IS NULL AND e2.created_at < e.created_at) AS host_events_hosted,
              (SELECT AVG(rating)::FLOAT FROM event_ratings er WHERE er.event_id = e.id) AS avg_rating,
              (SELECT rating FROM event_ratings er WHERE er.event_id = e.id AND er.user_id = $1) AS my_rating,
              (hu.banned_at IS NOT NULL) AS host_was_suspended,
              COALESCE(hu.warnings_count, 0) AS host_warnings_count
       FROM events e
       LEFT JOIN profiles hp ON hp.user_id = e.host_id
       LEFT JOIN users hu ON hu.id = e.host_id
       WHERE ${where}
       ORDER BY e.created_at DESC
       LIMIT 100`,
      params
    );
    return res.json({ data: { events: r.rows } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /events — create + auto-join the host
router.post('/', authMw, async (req, res) => {
  const { title, category, areaName, guestsLimit, closesInMinutes, expiresInHours, isGuestListPublic } = req.body;
  if (!title || !areaName) {
    return res.status(400).json({ errors: { detail: 'title and areaName are required' } });
  }
  try {
    const closesAt = closesInMinutes ? new Date(Date.now() + closesInMinutes * 60 * 1000) : null;
    const expiresAt = expiresInHours ? new Date(Date.now() + expiresInHours * 60 * 60 * 1000) : null;
    const r = await pool.query(
      `INSERT INTO events (host_id, title, category, area_name, guests_limit, is_guest_list_public, closes_at, expires_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [req.user.id, title, category || 'Other', areaName, guestsLimit || null,
       isGuestListPublic !== false, closesAt, expiresAt]
    );
    const event = r.rows[0];
    await pool.query(
      `INSERT INTO event_attendees (event_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
      [event.id, req.user.id]
    );
    return res.json({ success: true, data: event });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /events/:id/join — RSVP
router.post('/:id/join', authMw, async (req, res) => {
  try {
    const evR = await pool.query('SELECT guests_limit FROM events WHERE id = $1 AND cancelled_at IS NULL', [req.params.id]);
    if (!evR.rows.length) return res.status(404).json({ errors: { detail: 'Event not found' } });
    const limit = evR.rows[0].guests_limit;
    if (limit) {
      const countR = await pool.query('SELECT COUNT(*) FROM event_attendees WHERE event_id = $1', [req.params.id]);
      if (parseInt(countR.rows[0].count, 10) >= limit) {
        return res.status(409).json({ errors: { detail: 'This event is full' } });
      }
    }
    await pool.query(
      'INSERT INTO event_attendees (event_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING',
      [req.params.id, req.user.id]
    );
    const countR = await pool.query('SELECT COUNT(*) FROM event_attendees WHERE event_id = $1', [req.params.id]);
    return res.json({ success: true, data: { guestCount: parseInt(countR.rows[0].count, 10) } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// DELETE /events/:id/join — un-RSVP
router.delete('/:id/join', authMw, async (req, res) => {
  try {
    await pool.query('DELETE FROM event_attendees WHERE event_id = $1 AND user_id = $2', [req.params.id, req.user.id]);
    return res.json({ success: true });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// GET /events/:id/attendees — only exposed if the list is public or the
// requester is the host.
router.get('/:id/attendees', authMw, async (req, res) => {
  try {
    const evR = await pool.query('SELECT host_id, is_guest_list_public FROM events WHERE id = $1', [req.params.id]);
    if (!evR.rows.length) return res.status(404).json({ errors: { detail: 'Event not found' } });
    const event = evR.rows[0];
    if (!event.is_guest_list_public && event.host_id !== req.user.id) {
      return res.status(403).json({ errors: { detail: 'Guest list is private' } });
    }
    const r = await pool.query(
      `SELECT p.user_id, p.username FROM event_attendees ea
       JOIN profiles p ON p.user_id = ea.user_id
       WHERE ea.event_id = $1 ORDER BY ea.joined_at ASC`,
      [req.params.id]
    );
    return res.json({ data: { attendees: r.rows } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /events/:id/rate — 1-5 star rating (upsert)
router.post('/:id/rate', authMw, async (req, res) => {
  const rating = parseInt(req.body.rating, 10);
  if (!rating || rating < 1 || rating > 5) {
    return res.status(400).json({ errors: { detail: 'rating must be 1-5' } });
  }
  try {
    await pool.query(
      `INSERT INTO event_ratings (event_id, user_id, rating) VALUES ($1,$2,$3)
       ON CONFLICT (event_id, user_id) DO UPDATE SET rating = $3, created_at = NOW()`,
      [req.params.id, req.user.id, rating]
    );
    const avgR = await pool.query('SELECT AVG(rating)::FLOAT AS avg FROM event_ratings WHERE event_id = $1', [req.params.id]);
    return res.json({ success: true, data: { avgRating: avgR.rows[0].avg } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /events/:id/report
router.post('/:id/report', authMw, async (req, res) => {
  const reason = (req.body.reason || 'Unspecified').toString();
  try {
    await pool.query(
      'INSERT INTO event_reports (event_id, user_id, reason) VALUES ($1,$2,$3)',
      [req.params.id, req.user.id, reason]
    );
    // Also land this in the real moderation queue (content_reports) — before
    // this, event reports only ever reached event_reports, which the admin
    // dashboard never reads, so a reported event could never actually lead
    // to the host being suspended.
    await pool.query(
      `INSERT INTO content_reports (reporter_id, target_type, target_id, content_type, reason, details)
       VALUES ($1,'event',$2,'event','other',$3)`,
      [req.user.id, req.params.id, reason]
    );
    return res.json({ success: true });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// DELETE /events/:id — cancel (host only). Notifies every other attendee:
// an auto-expiring DM (reusing the 1-on-1 conversation + message pipeline,
// message_type 'event_cancelled' so the client renders it as a system
// bubble, disappear_at 3 days out) plus a notifications-bar row carrying the
// same text, including the host's typed reason if they gave one.
router.delete('/:id', authMw, async (req, res) => {
  const reason = (req.body?.reason || '').toString().trim();
  try {
    const evR = await pool.query(
      'SELECT * FROM events WHERE id = $1 AND host_id = $2 AND cancelled_at IS NULL',
      [req.params.id, req.user.id]
    );
    if (!evR.rows.length) return res.status(404).json({ errors: { detail: 'Event not found' } });
    const event = evR.rows[0];
    await pool.query('UPDATE events SET cancelled_at = NOW() WHERE id = $1', [event.id]);

    const hostP = await pool.query('SELECT username FROM profiles WHERE user_id = $1', [req.user.id]);
    const hostUsername = hostP.rows[0]?.username || 'The host';
    const attendeesR = await pool.query(
      'SELECT user_id FROM event_attendees WHERE event_id = $1 AND user_id <> $2',
      [event.id, req.user.id]
    );

    const messageText = reason
      ? `${hostUsername} cancelled "${event.title}". ${hostUsername}'s reason to cancel was: ${reason}`
      : `${hostUsername} cancelled "${event.title}".`;
    const disappearAt = new Date(Date.now() + COMMENT_WINDOW_MS);

    for (const { user_id: attendeeId } of attendeesR.rows) {
      const existing = await pool.query(
        `SELECT cp1.conversation_id AS id
         FROM conversation_participants cp1
         JOIN conversation_participants cp2
           ON cp1.conversation_id = cp2.conversation_id AND cp2.user_id = $2
         WHERE cp1.user_id = $1
           AND (SELECT COUNT(*) FROM conversation_participants
                WHERE conversation_id = cp1.conversation_id) = 2
         LIMIT 1`,
        [req.user.id, attendeeId]
      );
      let convId = existing.rows[0]?.id;
      if (!convId) {
        convId = uuidv4();
        await pool.query('INSERT INTO conversations (id, created_by) VALUES ($1,$2)', [convId, req.user.id]);
        await pool.query(
          `INSERT INTO conversation_participants (conversation_id, user_id)
           VALUES ($1,$2), ($1,$3) ON CONFLICT DO NOTHING`,
          [convId, req.user.id, attendeeId]
        );
      }
      await pool.query(
        `INSERT INTO messages (conversation_id, sender_id, message_type, text_content, disappear_at, status)
         VALUES ($1,$2,'event_cancelled',$3,$4,'sent')`,
        [convId, req.user.id, messageText, disappearAt]
      );
      await pool.query(
        `INSERT INTO notifications (user_id, type, payload) VALUES ($1,'event_cancelled',$2)`,
        [
          attendeeId,
          JSON.stringify({
            actor_id: req.user.id,
            actor_username: hostUsername,
            event_id: event.id,
            event_title: event.title,
            reason: reason || null,
            message: messageText,
          }),
        ]
      );
    }
    return res.json({ success: true });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// PUT /events/:id — edit (host only). Locked 20 minutes after creation,
// same pattern as the message edit window in conversations.js.
router.put('/:id', authMw, async (req, res) => {
  const { title, areaName } = req.body;
  try {
    const r = await pool.query(
      `UPDATE events SET title = COALESCE($1, title), area_name = COALESCE($2, area_name), updated_at = NOW()
       WHERE id = $3 AND host_id = $4 AND created_at > NOW() - ${EDIT_WINDOW_SQL} RETURNING *`,
      [title || null, areaName || null, req.params.id, req.user.id]
    );
    if (!r.rows.length) {
      const existsR = await pool.query(
        'SELECT 1 FROM events WHERE id = $1 AND host_id = $2',
        [req.params.id, req.user.id]
      );
      if (existsR.rows.length) {
        return res.status(422).json({ errors: { detail: 'The 20-minute edit window for this event has passed' } });
      }
      return res.status(404).json({ errors: { detail: 'Event not found' } });
    }
    return res.json({ success: true, data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// Comments only ever open once the event has genuinely ended (expires_at
// passed) — a cancelled event never happened, so it never gets a comment
// thread — and close again COMMENT_WINDOW_MS (3 days) after that.
function commentWindowFor(event) {
  if (event.cancelled_at) return { open: false, closesAt: null, neverOpens: true };
  if (!event.expires_at || new Date(event.expires_at) > new Date()) {
    return { open: false, closesAt: null, opensAt: event.expires_at };
  }
  const closesAt = new Date(new Date(event.expires_at).getTime() + COMMENT_WINDOW_MS);
  return { open: new Date() <= closesAt, closesAt };
}

// GET /events/:id/comments
router.get('/:id/comments', authMw, async (req, res) => {
  try {
    const evR = await pool.query('SELECT expires_at, cancelled_at FROM events WHERE id = $1', [req.params.id]);
    if (!evR.rows.length) return res.status(404).json({ errors: { detail: 'Event not found' } });
    const window = commentWindowFor(evR.rows[0]);
    if (!window.open && !window.closesAt) {
      return res.json({ data: { result: [], opensAt: window.opensAt || null } });
    }
    const r = await pool.query(
      `SELECT ec.*, p.username, p.profile_picture FROM event_comments ec
       LEFT JOIN profiles p ON p.user_id = ec.user_id
       WHERE ec.event_id = $1 ORDER BY ec.created_at ASC`,
      [req.params.id]
    );
    return res.json({ data: { result: r.rows, closesAt: window.closesAt, closed: !window.open } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /events/:id/comments — text plus an optional single image/audio/video
// URL (client uploads to Cloudinary first and passes the URL, same pattern
// as the rest of the app's media posts).
router.post('/:id/comments', authMw, async (req, res) => {
  const { text, imageUrl, audioUrl, videoUrl } = req.body || {};
  try {
    const evR = await pool.query('SELECT expires_at, cancelled_at FROM events WHERE id = $1', [req.params.id]);
    if (!evR.rows.length) return res.status(404).json({ errors: { detail: 'Event not found' } });
    const window = commentWindowFor(evR.rows[0]);
    if (!window.open) {
      return res.status(422).json({
        errors: { detail: window.neverOpens ? 'This event was cancelled' : window.closesAt ? 'Comments for this event have closed' : 'Comments open once the event has ended' },
      });
    }
    const r = await pool.query(
      `INSERT INTO event_comments (event_id, user_id, text_content, image_content, audio_content, video_content)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [req.params.id, req.user.id, text || '', imageUrl || null, audioUrl || null, videoUrl || null]
    );
    return res.status(201).json({ data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

module.exports = router;
