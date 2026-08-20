-- ═══════════════════════════════════════════════════════════════
-- Taddabur Initial Database Schema
-- Migration: 001_initial_schema.sql
-- ═══════════════════════════════════════════════════════════════

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Users ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email                TEXT UNIQUE NOT NULL,
  display_name         TEXT NOT NULL,
  language_preference  TEXT DEFAULT 'en' CHECK (language_preference IN ('en','bn','hi','de','fr')),
  created_at           TIMESTAMPTZ DEFAULT NOW(),
  last_active_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ── User Progress (Ayah layers) ───────────────────────────────
CREATE TABLE IF NOT EXISTS user_progress (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  surah_number     INT NOT NULL,
  ayah_number      INT NOT NULL,
  layer_completed  INT NOT NULL CHECK (layer_completed BETWEEN 1 AND 5),
  completed_at     TIMESTAMPTZ DEFAULT NOW(),
  reflection_text  TEXT, -- encrypted at application layer
  UNIQUE(user_id, surah_number, ayah_number, layer_completed)
);

-- ── Vocabulary Bank ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS vocabulary_bank (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  arabic_word    TEXT NOT NULL,
  root           TEXT,
  meaning_en     TEXT NOT NULL,
  times_seen     INT DEFAULT 1,
  next_review_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '1 day',
  saved_at       TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, arabic_word)
);

-- ── Muhasabah Journal ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS muhasabah_entries (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  entry_date DATE NOT NULL,
  q1_answer  TEXT, -- encrypted: what did you do for Allah?
  q2_answer  TEXT, -- encrypted: what did you do for nafs?
  q3_answer  TEXT, -- encrypted: intention for tomorrow
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, entry_date)
);

-- ── Friday Reflections ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS friday_reflections (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  week_date  DATE NOT NULL,
  reflection TEXT, -- encrypted
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, week_date)
);

-- ── Halaqas ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS halaqas (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  created_by  UUID NOT NULL REFERENCES users(id),
  invite_code TEXT UNIQUE NOT NULL,
  max_members INT DEFAULT 8,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── Halaqa Members ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS halaqa_members (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  halaqa_id       UUID NOT NULL REFERENCES halaqas(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at       TIMESTAMPTZ DEFAULT NOW(),
  last_opened_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(halaqa_id, user_id)
);

-- ── Halaqa Shares ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS halaqa_shares (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  halaqa_id      UUID NOT NULL REFERENCES halaqas(id) ON DELETE CASCADE,
  shared_by      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content_id     TEXT NOT NULL,  -- references content in app
  content_type   TEXT NOT NULL CHECK (content_type IN ('quran','hadith','sahabi','name','prophet')),
  personal_note  TEXT CHECK (char_length(personal_note) <= 100),
  shared_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ── Minbar Shares (public feed) ───────────────────────────────
CREATE TABLE IF NOT EXISTS minbar_shares (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shared_by        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content_id       TEXT NOT NULL,
  content_type     TEXT NOT NULL CHECK (content_type IN ('quran','hadith','sahabi','name','prophet')),
  dua_count        INT DEFAULT 0,
  resonated_count  INT DEFAULT 0,
  shared_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ── Indexes for performance ───────────────────────────────────
CREATE INDEX idx_user_progress_user ON user_progress(user_id);
CREATE INDEX idx_vocab_user ON vocabulary_bank(user_id);
CREATE INDEX idx_vocab_next_review ON vocabulary_bank(user_id, next_review_at);
CREATE INDEX idx_muhasabah_user_date ON muhasabah_entries(user_id, entry_date);
CREATE INDEX idx_halaqa_members_halaqa ON halaqa_members(halaqa_id);
CREATE INDEX idx_halaqa_shares_halaqa ON halaqa_shares(halaqa_id, shared_at DESC);
CREATE INDEX idx_minbar_shares_time ON minbar_shares(shared_at DESC);
