const router = require('express').Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../db');
const authMw = require('../middleware/auth');

const makeToken = (userId) =>
  jwt.sign({ id: userId }, process.env.JWT_SECRET, { expiresIn: '30d' });

const getProfile = async (userId) => {
  const r = await pool.query('SELECT * FROM profiles WHERE user_id = $1', [userId]);
  return r.rows[0] || null;
};

// POST /auth/register
router.post('/register', async (req, res) => {
  const {
    username, email, password, passwordConfirm,
    firstName, lastName, gender, birthDate,
    location, relationshipStatus, occupation,
    profilePictureUrl,
  } = req.body;

  if (!username || !email || !password)
    return res.status(400).json({ errors: { detail: 'username, email and password are required' } });
  if (password !== passwordConfirm)
    return res.status(400).json({ errors: { detail: 'Passwords do not match' } });

  try {
    const hash = await bcrypt.hash(password, 12);
    const ur = await pool.query(
      'INSERT INTO users (email, username, password_hash) VALUES ($1,$2,$3) RETURNING id, email, username',
      [email.toLowerCase().trim(), username.trim(), hash]
    );
    const user = ur.rows[0];

    await pool.query(
      `INSERT INTO profiles (user_id, email, username, first_name, last_name, gender, birth_date, location, relationship_status, occupation, profile_picture)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
      [user.id, email.toLowerCase().trim(), username.trim(),
       firstName || null, lastName || null, gender || null,
       birthDate || null, location || null, relationshipStatus || null, occupation || null,
       profilePictureUrl || null]
    );

    const token = makeToken(user.id);
    const profile = await getProfile(user.id);
    return res.status(200).json({
      data: {
        id: user.id,
        email: user.email,
        username: user.username,
        tokens: { auth: token },
        profile,
      },
    });
  } catch (e) {
    if (e.code === '23505')
      return res.status(400).json({ errors: { detail: 'Email or username already taken' } });
    console.error('register:', e);
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /auth/login
router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password)
    return res.status(400).json({ errors: { detail: 'email and password required' } });

  try {
    let r = await pool.query('SELECT * FROM users WHERE email = $1', [email.toLowerCase().trim()]);
    if (r.rows.length === 0)
      r = await pool.query('SELECT * FROM users WHERE username = $1', [email.trim()]);
    if (r.rows.length === 0)
      return res.status(401).json({ errors: { detail: 'Invalid credentials' } });

    const user = r.rows[0];
    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid)
      return res.status(401).json({ errors: { detail: 'Invalid credentials' } });

    const token = makeToken(user.id);
    const profile = await getProfile(user.id);
    return res.json({
      data: {
        id: user.id,
        email: user.email,
        username: user.username,
        tokens: { auth: token },
        profile,
      },
    });
  } catch (e) {
    console.error('login:', e);
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// GET /auth/me
router.get('/me', authMw, async (req, res) => {
  try {
    const r = await pool.query(
      'SELECT id, email, username FROM users WHERE id = $1',
      [req.user.id]
    );
    if (r.rows.length === 0)
      return res.status(404).json({ errors: { detail: 'User not found' } });

    const user = r.rows[0];
    const profile = await getProfile(user.id);
    return res.json({
      data: { id: user.id, email: user.email, username: user.username, profile },
    });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /auth/request-password-reset
router.post('/request-password-reset', async (req, res) => {
  const { email } = req.body;
  try {
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expires = new Date(Date.now() + 15 * 60 * 1000);
    await pool.query(
      'UPDATE users SET otp = $1, otp_expires_at = $2 WHERE email = $3',
      [otp, expires, email?.toLowerCase().trim()]
    );
    // In production, send otp via email service. For now, log it.
    console.log(`Password reset OTP for ${email}: ${otp}`);
    return res.json({ message: 'Password reset OTP sent', data: {} });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /auth/reset-password
router.post('/reset-password', async (req, res) => {
  const { email, otp, newPassword, confirmNewPassword } = req.body;
  if (newPassword !== confirmNewPassword)
    return res.status(400).json({ errors: { detail: 'Passwords do not match' } });

  try {
    const r = await pool.query(
      'SELECT id FROM users WHERE email = $1 AND otp = $2 AND otp_expires_at > NOW()',
      [email?.toLowerCase().trim(), otp]
    );
    if (r.rows.length === 0)
      return res.status(400).json({ errors: { detail: 'Invalid or expired OTP' } });

    const hash = await bcrypt.hash(newPassword, 12);
    await pool.query(
      'UPDATE users SET password_hash = $1, otp = NULL, otp_expires_at = NULL WHERE email = $2',
      [hash, email.toLowerCase().trim()]
    );
    return res.json({ message: 'Password updated', data: {} });
  } catch (e) {
    return res.status(500).json({ errors: { detail: e.message } });
  }
});

// POST /auth/verify-otp  (no-op — always verified on signup)
router.post('/verify-otp', (_, res) => res.json({ message: 'Email verified', data: {} }));

// POST /auth/resend-otp
router.post('/resend-otp', (_, res) => res.json({ message: 'Verification email resent', data: {} }));

module.exports = router;
