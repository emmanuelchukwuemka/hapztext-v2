require('dotenv').config();
const express = require('express');
const cors = require('cors');

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

app.use((err, req, res, _next) => {
  console.error(err);
  res.status(500).json({ errors: { detail: err.message || 'Internal server error' } });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Hapzo backend running on port ${PORT}`));
