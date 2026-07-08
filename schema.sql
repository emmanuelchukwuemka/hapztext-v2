-- Hapzo Schema for Neon PostgreSQL
-- Run this once in your Neon SQL Editor at console.neon.tech

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─── USERS ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  email           TEXT        UNIQUE NOT NULL,
  username        TEXT        UNIQUE NOT NULL,
  password_hash   TEXT        NOT NULL,
  otp             TEXT,
  otp_expires_at  TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── PROFILES ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID        UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  email                TEXT,
  username             TEXT,
  first_name           TEXT,
  last_name            TEXT,
  gender               TEXT,
  birth_date           TEXT,
  ethnicity            TEXT,
  relationship_status  TEXT,
  occupation           TEXT,
  bio                  TEXT,
  location             TEXT,
  height               TEXT,
  weight               TEXT,
  profile_picture      TEXT,
  cover_picture        TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── FOLLOWS ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_follows (
  follower_id   UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  following_id  UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (follower_id, following_id)
);

-- ─── POSTS ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS posts (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id         UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sender_username   TEXT,
  sender_name       TEXT,
  post_format       TEXT        NOT NULL,
  text_content      TEXT,
  background_color  TEXT,
  image_content     TEXT,
  audio_content     TEXT,
  video_content     TEXT,
  is_reply          BOOLEAN     NOT NULL DEFAULT FALSE,
  previous_post_id  UUID        REFERENCES posts(id) ON DELETE CASCADE,
  is_published      BOOLEAN     NOT NULL DEFAULT TRUE,
  scheduled_at      TIMESTAMPTZ,
  share_count       INT         NOT NULL DEFAULT 0,
  like_count        INT         NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── MEDIA FILES ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS media_files (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id     UUID        NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  media_type  TEXT        NOT NULL,
  image_file  TEXT,
  audio_file  TEXT,
  video_file  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── REACTIONS ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS post_reactions (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id     UUID        NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reaction    TEXT        NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (post_id, user_id)
);

-- ─── NOTIFICATIONS ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type        TEXT,
  payload     JSONB       NOT NULL DEFAULT '{}',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── CONVERSATIONS ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS conversations (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  created_by  UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS conversation_participants (
  conversation_id  UUID        NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (conversation_id, user_id)
);

-- ─── MESSAGES ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS messages (
  id                        UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id           UUID        NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id                 UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  message_type              TEXT        NOT NULL DEFAULT 'text',
  text_content              TEXT,
  media_url                 TEXT,
  is_reply                  BOOLEAN     NOT NULL DEFAULT FALSE,
  previous_message_id       UUID        REFERENCES messages(id) ON DELETE SET NULL,
  previous_message_content  TEXT,
  previous_message_sender_id UUID       REFERENCES users(id) ON DELETE SET NULL,
  status                    TEXT        NOT NULL DEFAULT 'sent',
  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── INDEXES ──────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_posts_sender     ON posts(sender_id);
CREATE INDEX IF NOT EXISTS idx_posts_created    ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_media_post       ON media_files(post_id);
CREATE INDEX IF NOT EXISTS idx_reactions_post   ON post_reactions(post_id);
CREATE INDEX IF NOT EXISTS idx_follows_follower ON user_follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON user_follows(following_id);
CREATE INDEX IF NOT EXISTS idx_cp_user          ON conversation_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_conv    ON messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notif_user       ON notifications(user_id, created_at DESC);

-- ─── UPDATED_AT TRIGGER ───────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS users_upd    ON users;
CREATE TRIGGER users_upd    BEFORE UPDATE ON users    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS profiles_upd ON profiles;
CREATE TRIGGER profiles_upd BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS posts_upd    ON posts;
CREATE TRIGGER posts_upd    BEFORE UPDATE ON posts    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS media_upd    ON media_files;
CREATE TRIGGER media_upd    BEFORE UPDATE ON media_files FOR EACH ROW EXECUTE FUNCTION set_updated_at();
