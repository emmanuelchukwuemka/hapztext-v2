require('dotenv').config();
const express = require('express');
const cors = require('cors');
const http = require('http');
const { Server: SocketIOServer } = require('socket.io');

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

app.get('/health', (_, res) => res.json({ status: 'ok', ts: new Date().toISOString() }));

app.use('/auth', require('./routes/auth'));
app.use('/posts', require('./routes/posts'));
app.use('/people', require('./routes/people'));
app.use('/conversations', require('./routes/conversations'));
app.use('/profiles', require('./routes/profiles'));
app.use('/streams', require('./routes/streams'));
app.use('/rtc', require('./routes/rtc'));

app.use((err, req, res, _next) => {
  console.error(err);
  res.status(500).json({ errors: { detail: err.message || 'Internal server error' } });
});

const pool = require('./db');

const fs = require('fs');
const path = require('path');

async function initializeDatabase() {
  try {
    const schemaSql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf-8');
    await pool.query(schemaSql);
    console.log('Successfully verified database schema from schema.sql');
  } catch (err) {
    console.error('Error initializing database schema:', err);
  }
}

const httpServer = http.createServer(app);
const io = new SocketIOServer(httpServer, { cors: { origin: '*' } });
require('./realtime/livestream')(io);

const PORT = process.env.PORT || 3000;
initializeDatabase().then(() => {
  httpServer.listen(PORT, () => console.log(`Hapzo backend running on port ${PORT}`));
});
