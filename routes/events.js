const router = require('express').Router();
const pool = require('../db');
const authMw = require('../middleware/auth');

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
              (SELECT COUNT(*) FROM events e2 WHERE e2.host_id = e.host_id AND e2.cancelled_at IS NULL) AS host_events_hosted,
              (SELECT AVG(rating)::FLOAT FROM event_ratings er WHERE er.event_id = e.id) AS avg_rating,
              (SELECT rating FROM event_ratings er WHERE er.event_id = e.id AND er.user_id = $1) AS my_rating
       FROM events e
       LEFT JOIN profiles hp ON hp.user_id = e.host_id
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
    return res.json({ success: true });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// DELETE /events/:id — cancel (host only)
router.delete('/:id', authMw, async (req, res) => {
  try {
    const r = await pool.query(
      'UPDATE events SET cancelled_at = NOW() WHERE id = $1 AND host_id = $2 AND cancelled_at IS NULL RETURNING id',
      [req.params.id, req.user.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'Event not found' } });
    return res.json({ success: true });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// PUT /events/:id — edit (host only)
router.put('/:id', authMw, async (req, res) => {
  const { title, areaName } = req.body;
  try {
    const r = await pool.query(
      `UPDATE events SET title = COALESCE($1, title), area_name = COALESCE($2, area_name), updated_at = NOW()
       WHERE id = $3 AND host_id = $4 RETURNING *`,
      [title || null, areaName || null, req.params.id, req.user.id]
    );
    if (!r.rows.length) return res.status(404).json({ errors: { detail: 'Event not found' } });
    return res.json({ success: true, data: r.rows[0] });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

module.exports = router;
