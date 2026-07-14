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
app.use('/streams', require('./routes/streams'));
app.use('/rtc', require('./routes/rtc'));

app.use((err, req, res, _next) => {
  console.error(err);
  res.status(500).json({ errors: { detail: err.message || 'Internal server error' } });
});

const pool = require('./db');

async function initializeDatabase() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS public.post_hashtags (
        id uuid primary key default gen_random_uuid(),
        post_id uuid not null references public.posts(id) on delete cascade,
        hashtag text not null,
        created_at timestamptz not null default now()
      );
      
      CREATE INDEX IF NOT EXISTS post_hashtags_post_id_idx ON public.post_hashtags(post_id);
      CREATE INDEX IF NOT EXISTS post_hashtags_hashtag_idx ON public.post_hashtags(hashtag);
      
      ALTER TABLE public.post_hashtags ENABLE ROW LEVEL SECURITY;
      
      DROP POLICY IF EXISTS "post_hashtags_select" ON public.post_hashtags;
      CREATE POLICY "post_hashtags_select" ON public.post_hashtags FOR SELECT TO authenticated USING (true);
      
      DROP POLICY IF EXISTS "post_hashtags_insert" ON public.post_hashtags;
      CREATE POLICY "post_hashtags_insert" ON public.post_hashtags FOR INSERT TO authenticated WITH CHECK (
        EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_hashtags.post_id AND p.sender_id = auth.uid())
      );
      
      DROP POLICY IF EXISTS "post_hashtags_delete" ON public.post_hashtags;
      CREATE POLICY "post_hashtags_delete" ON public.post_hashtags FOR DELETE TO authenticated USING (
        EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_hashtags.post_id AND p.sender_id = auth.uid())
      );
      
      REVOKE ALL ON public.post_hashtags FROM anon, authenticated;
      GRANT SELECT, INSERT, DELETE ON public.post_hashtags TO authenticated;
    `);
    console.log('Verified database schema (post_hashtags)');
  } catch (err) {
    console.error('Error initializing database schema:', err);
  }
}

const PORT = process.env.PORT || 3000;
initializeDatabase().then(() => {
  app.listen(PORT, () => console.log(`Hapzo backend running on port ${PORT}`));
});
