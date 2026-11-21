const router = require('express').Router();
const pool = require('../db');
const authMw = require('../middleware/auth');

// POST /media/upload — accepts a base64-encoded file and stores it directly
// in Postgres (media_blobs). Stopgap for when no Cloudinary/S3/R2 account is
// set up — see the comment above the media_blobs table in schema.sql.
router.post('/upload', authMw, async (req, res) => {
  const { data, mimeType } = req.body || {};
  if (!data) return res.status(400).json({ errors: { detail: 'data (base64) is required' } });
  try {
    const buffer = Buffer.from(data, 'base64');
    const r = await pool.query(
      `INSERT INTO media_blobs (mime_type, data, size_bytes) VALUES ($1,$2,$3) RETURNING id`,
      [mimeType || 'application/octet-stream', buffer, buffer.length]
    );
    const id = r.rows[0].id;
    const url = `${req.protocol}://${req.get('host')}/media/${id}`;
    return res.status(201).json({ data: { url, id } });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// GET /media/:id — serves the blob back. Deliberately no auth: the URL this
// returns gets embedded directly in <img>/video/audio src and launchUrl
// calls throughout the app, same as an unsigned Cloudinary delivery URL
// would be — those callers don't attach an Authorization header either.
router.get('/:id', async (req, res) => {
  try {
    const r = await pool.query('SELECT mime_type, data FROM media_blobs WHERE id = $1', [req.params.id]);
    if (!r.rows.length) return res.status(404).send('Not found');
    const row = r.rows[0];
    res.set('Content-Type', row.mime_type || 'application/octet-stream');
    res.set('Cache-Control', 'public, max-age=31536000, immutable');
    return res.send(row.data);
  } catch (e) {
    return res.status(500).send('Error');
  }
});

module.exports = router;
