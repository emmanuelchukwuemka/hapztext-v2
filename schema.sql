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
  phone_number         TEXT,
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

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone_number TEXT;

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
  repost_of         UUID        REFERENCES posts(id) ON DELETE SET NULL,
  is_published      BOOLEAN     NOT NULL DEFAULT TRUE,
  scheduled_at      TIMESTAMPTZ,
  share_count       INT         NOT NULL DEFAULT 0,
  like_count        INT         NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE posts ADD COLUMN IF NOT EXISTS repost_of UUID REFERENCES posts(id) ON DELETE SET NULL;

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
  read_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE notifications ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

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
  edited_at                 TIMESTAMPTZ,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE messages ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
-- Set on system-generated 'post_share' messages ("X uploaded a picture"),
-- pointing at the post to open when the user taps "View" in the chat.
ALTER TABLE messages ADD COLUMN IF NOT EXISTS related_post_id UUID REFERENCES posts(id) ON DELETE SET NULL;
-- View-once media (WhatsApp-style): once the recipient opens it,
-- view_once_consumed_at is stamped and the media_url stops being served.
ALTER TABLE messages ADD COLUMN IF NOT EXISTS view_once BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS view_once_consumed_at TIMESTAMPTZ;
-- Disappearing messages: set at send time from the sender's "Disappearing
-- Messages" chat setting; once past, GET /messages simply stops returning it.
ALTER TABLE messages ADD COLUMN IF NOT EXISTS disappear_at TIMESTAMPTZ;
-- Multi-reply (WhatsApp-style "reply to up to 2 messages at once"): the
-- first quote still uses the original previous_message_* columns above,
-- this is only the optional second one.
ALTER TABLE messages ADD COLUMN IF NOT EXISTS previous_message_id_2 UUID REFERENCES messages(id) ON DELETE SET NULL;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS previous_message_content_2 TEXT;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS previous_message_sender_id_2 UUID REFERENCES users(id) ON DELETE SET NULL;

-- ─── MESSAGE READS (per-user) ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS message_reads (
  message_id  UUID        NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  read_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (message_id, user_id)
);

-- ─── CONVERSATION USER SETTINGS (pin/mute/mode/theme) ────────────────────────
CREATE TABLE IF NOT EXISTS conversation_user_settings (
  conversation_id     UUID        NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id             UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  pinned              BOOLEAN     NOT NULL DEFAULT FALSE,
  muted               BOOLEAN     NOT NULL DEFAULT FALSE,
  chat_mode           TEXT        NOT NULL DEFAULT 'mixed',
  disappearing        TEXT        NOT NULL DEFAULT 'off',
  auto_clear_enabled  BOOLEAN     NOT NULL DEFAULT FALSE,
  auto_clear_start    TEXT,
  auto_clear_end      TEXT,
  -- Stamped when auto_clear_enabled flips to true, cleared when it flips
  -- back to false — the sweep only ever considers messages sent after this.
  auto_clear_enabled_at TIMESTAMPTZ,
  theme_index         INT         NOT NULL DEFAULT 0,
  notification_tone   TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (conversation_id, user_id)
);
ALTER TABLE conversation_user_settings ADD COLUMN IF NOT EXISTS auto_clear_enabled_at TIMESTAMPTZ;

-- ─── HASHTAGS + MENTIONS ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS hashtags (
  tag         TEXT        PRIMARY KEY,
  usage_count INT         NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS post_hashtags (
  post_id  UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  tag      TEXT NOT NULL REFERENCES hashtags(tag) ON DELETE CASCADE,
  PRIMARY KEY (post_id, tag)
);

CREATE TABLE IF NOT EXISTS post_mentions (
  post_id            UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  mentioned_user_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  mentioned_username TEXT,
  PRIMARY KEY (post_id, mentioned_user_id)
);

-- One row per (post, viewer) so re-viewing your own feed doesn't inflate the
-- count — view_count on posts is how many *distinct people* saw it.
CREATE TABLE IF NOT EXISTS post_views (
  post_id    UUID        NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (post_id, user_id)
);

ALTER TABLE posts ADD COLUMN IF NOT EXISTS view_count INT NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS post_bookmarks (
  post_id    UUID        NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (post_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_bookmarks_user ON post_bookmarks(user_id, created_at DESC);

-- ─── EVENTS (Discover/Explore "Events" tab) ──────────────────────────────────
CREATE TABLE IF NOT EXISTS events (
  id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  host_id               UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title                 TEXT        NOT NULL,
  category              TEXT        NOT NULL DEFAULT 'Other',
  area_name             TEXT        NOT NULL,
  guests_limit          INT,
  is_guest_list_public  BOOLEAN     NOT NULL DEFAULT TRUE,
  closes_at             TIMESTAMPTZ,
  expires_at            TIMESTAMPTZ,
  cancelled_at          TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS event_attendees (
  event_id   UUID        NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (event_id, user_id)
);

CREATE TABLE IF NOT EXISTS event_ratings (
  event_id   UUID        NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating     INT         NOT NULL CHECK (rating BETWEEN 1 AND 5),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (event_id, user_id)
);

CREATE TABLE IF NOT EXISTS event_reports (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id   UUID        NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason     TEXT        NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_events_created  ON events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_host     ON events(host_id);
CREATE INDEX IF NOT EXISTS idx_event_attendees_user ON event_attendees(user_id);

-- ─── INDEXES ──────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_posts_sender     ON posts(sender_id);
CREATE INDEX IF NOT EXISTS idx_posts_created    ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_scheduled  ON posts(is_published, scheduled_at);
CREATE INDEX IF NOT EXISTS idx_posts_repost_of  ON posts(repost_of);
CREATE INDEX IF NOT EXISTS idx_media_post       ON media_files(post_id);
CREATE INDEX IF NOT EXISTS idx_reactions_post   ON post_reactions(post_id);
CREATE INDEX IF NOT EXISTS idx_follows_follower ON user_follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON user_follows(following_id);
CREATE INDEX IF NOT EXISTS idx_cp_user          ON conversation_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_conv    ON messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_message_reads_user ON message_reads(user_id, read_at DESC);
CREATE INDEX IF NOT EXISTS idx_hashtags_usage   ON hashtags(usage_count DESC, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_post_hashtags_tag ON post_hashtags(tag);
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

DROP TRIGGER IF EXISTS messages_upd ON messages;
CREATE TRIGGER messages_upd BEFORE UPDATE ON messages FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS hashtags_upd ON hashtags;
CREATE TRIGGER hashtags_upd BEFORE UPDATE ON hashtags FOR EACH ROW EXECUTE FUNCTION set_updated_at();
