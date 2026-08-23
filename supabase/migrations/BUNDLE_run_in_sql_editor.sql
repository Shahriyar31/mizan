-- Taddabur — full schema bundle for a fresh cloud project.
-- Paste into Supabase Studio → SQL Editor → Run. Safe to run once, in this order.

-- ============================================================
-- 001_initial_schema.sql
-- ============================================================
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

-- ============================================================
-- 002_auth_rls.sql
-- ============================================================
-- ═══════════════════════════════════════════════════════════════
-- Migration: 002_auth_rls.sql
-- Wires public.users to real Supabase Auth (auth.users) and enables
-- Row Level Security + policies on every table in 001_initial_schema.sql,
-- plus layer_cache (used by SupabaseService but never migrated before).
--
-- Safe to run on a fresh or already-applied 001 schema: no existing rows
-- are deleted. users.id had no FK to auth.users before this — since no
-- application code has ever written to `users` (confirmed: nothing in the
-- Flutter app queries it), this just tightens a previously-unconstrained
-- column rather than migrating live data.
-- ═══════════════════════════════════════════════════════════════

-- ── users: tie id to auth.users, stop generating random ids ─────────
ALTER TABLE users ALTER COLUMN id DROP DEFAULT;
ALTER TABLE users
  ADD CONSTRAINT users_id_fkey FOREIGN KEY (id)
  REFERENCES auth.users(id) ON DELETE CASCADE;

-- Auto-create the public.users row the moment someone signs up, so app
-- code never has to race the trigger (AuthRepository also upserts
-- defensively after sign-up, but this is the source of truth).
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, email, display_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── layer_cache: used by SupabaseService, never had a migration ─────
CREATE TABLE IF NOT EXISTS layer_cache (
  id            BIGSERIAL PRIMARY KEY,
  surah_number  INT NOT NULL,
  ayah_number   INT NOT NULL,
  layer_index   INT NOT NULL,
  content_json  JSONB NOT NULL,
  generated_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (surah_number, ayah_number, layer_index)
);

-- ═══════════════════════════════════════════════════════════════
-- Row Level Security
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE users               ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_progress       ENABLE ROW LEVEL SECURITY;
ALTER TABLE vocabulary_bank     ENABLE ROW LEVEL SECURITY;
ALTER TABLE muhasabah_entries   ENABLE ROW LEVEL SECURITY;
ALTER TABLE friday_reflections  ENABLE ROW LEVEL SECURITY;
ALTER TABLE halaqas             ENABLE ROW LEVEL SECURITY;
ALTER TABLE halaqa_members      ENABLE ROW LEVEL SECURITY;
ALTER TABLE halaqa_shares       ENABLE ROW LEVEL SECURITY;
ALTER TABLE minbar_shares       ENABLE ROW LEVEL SECURITY;
ALTER TABLE layer_cache         ENABLE ROW LEVEL SECURITY;

-- ── users: profiles are readable by any signed-in user (needed for
-- Halaqa member lists / Minbar attribution); only the owner can write.
CREATE POLICY users_select_authenticated ON users
  FOR SELECT TO authenticated USING (true);
CREATE POLICY users_insert_own ON users
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
CREATE POLICY users_update_own ON users
  FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- ── Private per-user tables: strictly owner-only ─────────────────────
CREATE POLICY user_progress_owner ON user_progress
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY vocabulary_bank_owner ON vocabulary_bank
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY muhasabah_entries_owner ON muhasabah_entries
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY friday_reflections_owner ON friday_reflections
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── halaqas: invite_code is the access secret, not row visibility, so
-- any signed-in user can look one up (to join). Only the creator can
-- rename/delete it.
CREATE POLICY halaqas_select_authenticated ON halaqas
  FOR SELECT TO authenticated USING (true);
CREATE POLICY halaqas_insert_own ON halaqas
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = created_by);
CREATE POLICY halaqas_update_own ON halaqas
  FOR UPDATE TO authenticated USING (auth.uid() = created_by);
CREATE POLICY halaqas_delete_own ON halaqas
  FOR DELETE TO authenticated USING (auth.uid() = created_by);

-- ── halaqa_members: visible only to fellow members of the same circle;
-- a user can only add/remove *themselves*.
CREATE POLICY halaqa_members_select_fellow ON halaqa_members
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM halaqa_members hm
      WHERE hm.halaqa_id = halaqa_members.halaqa_id AND hm.user_id = auth.uid()
    )
  );
CREATE POLICY halaqa_members_insert_self ON halaqa_members
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY halaqa_members_update_self ON halaqa_members
  FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY halaqa_members_delete_self ON halaqa_members
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- ── halaqa_shares: visible only to members of that circle; only the
-- sharer can edit/delete their own share, and only while a member.
CREATE POLICY halaqa_shares_select_member ON halaqa_shares
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM halaqa_members hm
      WHERE hm.halaqa_id = halaqa_shares.halaqa_id AND hm.user_id = auth.uid()
    )
  );
CREATE POLICY halaqa_shares_insert_member ON halaqa_shares
  FOR INSERT TO authenticated WITH CHECK (
    auth.uid() = shared_by AND EXISTS (
      SELECT 1 FROM halaqa_members hm
      WHERE hm.halaqa_id = halaqa_shares.halaqa_id AND hm.user_id = auth.uid()
    )
  );
CREATE POLICY halaqa_shares_update_own ON halaqa_shares
  FOR UPDATE TO authenticated USING (auth.uid() = shared_by);
CREATE POLICY halaqa_shares_delete_own ON halaqa_shares
  FOR DELETE TO authenticated USING (auth.uid() = shared_by);

-- ── minbar_shares: public feed, readable by anyone (matches the app's
-- current no-login-required browsing); only the author can write. The
-- dua_count/resonated_count columns are plain integers with no per-user
-- reaction ledger yet, so they're locked to the owner rather than opened
-- to any signed-in user — a real reactions table (user_id, share_id,
-- kind) is needed before those counters can be safely incremented by
-- other users. Nothing in the app writes to this table yet.
CREATE POLICY minbar_shares_select_public ON minbar_shares
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY minbar_shares_insert_own ON minbar_shares
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = shared_by);
CREATE POLICY minbar_shares_update_own ON minbar_shares
  FOR UPDATE TO authenticated USING (auth.uid() = shared_by);
CREATE POLICY minbar_shares_delete_own ON minbar_shares
  FOR DELETE TO authenticated USING (auth.uid() = shared_by);

-- ── layer_cache: shared, non-user-owned Scholar AI cache — same
-- permissive access the app already relies on (anon key, no auth).
CREATE POLICY layer_cache_select_public ON layer_cache
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY layer_cache_write_public ON layer_cache
  FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY layer_cache_update_public ON layer_cache
  FOR UPDATE TO anon, authenticated USING (true);

-- ============================================================
-- 003_halaqa_minbar_online.sql
-- ============================================================
-- ═══════════════════════════════════════════════════════════════
-- Migration: 003_halaqa_minbar_online.sql
-- Brings halaqas/halaqa_members/halaqa_shares/minbar_shares (from 001) up
-- to what LocalHalaqaRepository/LocalMinbarRepository actually store, and
-- adds the per-user reaction ledgers (dua/resonated/moved) neither 001 nor
-- 002 had. No existing columns/rows are dropped or renamed.
-- ═══════════════════════════════════════════════════════════════

-- ── Column gaps vs. the app's actual share/member shape ──────────────
ALTER TABLE halaqa_shares  ADD COLUMN IF NOT EXISTS shared_by_name TEXT;
ALTER TABLE halaqa_shares  ADD COLUMN IF NOT EXISTS content_json   TEXT;
ALTER TABLE minbar_shares  ADD COLUMN IF NOT EXISTS shared_by_name TEXT;
ALTER TABLE minbar_shares  ADD COLUMN IF NOT EXISTS content_json   TEXT;
ALTER TABLE halaqa_members ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ DEFAULT NOW();

-- 001's content_type CHECK predates the Seerah content type.
ALTER TABLE halaqa_shares DROP CONSTRAINT IF EXISTS halaqa_shares_content_type_check;
ALTER TABLE halaqa_shares ADD CONSTRAINT halaqa_shares_content_type_check
  CHECK (content_type IN ('quran','hadith','sahabi','name','prophet','seerah'));
ALTER TABLE minbar_shares DROP CONSTRAINT IF EXISTS minbar_shares_content_type_check;
ALTER TABLE minbar_shares ADD CONSTRAINT minbar_shares_content_type_check
  CHECK (content_type IN ('quran','hadith','sahabi','name','prophet','seerah'));

-- ── Reaction ledgers (dua / resonated / moved), one row per user+reaction ──
CREATE TABLE IF NOT EXISTS halaqa_reactions (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  share_id   UUID NOT NULL REFERENCES halaqa_shares(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reaction   TEXT NOT NULL CHECK (reaction IN ('dua','resonated','moved')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (share_id, user_id, reaction)
);

CREATE TABLE IF NOT EXISTS minbar_reactions (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  share_id   UUID NOT NULL REFERENCES minbar_shares(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reaction   TEXT NOT NULL CHECK (reaction IN ('dua','resonated','moved')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (share_id, user_id, reaction)
);

CREATE INDEX IF NOT EXISTS idx_halaqa_reactions_share ON halaqa_reactions(share_id);
CREATE INDEX IF NOT EXISTS idx_minbar_reactions_share ON minbar_reactions(share_id);

-- ── halaqa_members: let a user always see their OWN membership rows (not
-- just fellow-member rows) — needed for "my circles" and join/already-
-- member checks, which run before the user is a fellow member of anything.
DROP POLICY IF EXISTS halaqa_members_select_fellow ON halaqa_members;
CREATE POLICY halaqa_members_select_self_or_fellow ON halaqa_members
  FOR SELECT TO authenticated USING (
    user_id = auth.uid() OR EXISTS (
      SELECT 1 FROM halaqa_members hm
      WHERE hm.halaqa_id = halaqa_members.halaqa_id AND hm.user_id = auth.uid()
    )
  );

-- ── Capacity + cleanup, enforced server-side (not a client check-then-
-- insert race). SECURITY DEFINER so a prospective joiner (not yet a member,
-- so blocked by the RLS above from seeing fellow rows) can still be counted
-- against the cap — the function only ever returns "full or not", no data.
CREATE OR REPLACE FUNCTION public.check_halaqa_capacity()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  cap INT;
  current_count INT;
BEGIN
  SELECT max_members INTO cap FROM halaqas WHERE id = NEW.halaqa_id;
  SELECT COUNT(*) INTO current_count FROM halaqa_members WHERE halaqa_id = NEW.halaqa_id;
  IF cap IS NOT NULL AND current_count >= cap THEN
    RAISE EXCEPTION 'halaqa_full' USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS halaqa_capacity_check ON halaqa_members;
CREATE TRIGGER halaqa_capacity_check
  BEFORE INSERT ON halaqa_members
  FOR EACH ROW EXECUTE FUNCTION public.check_halaqa_capacity();

-- Mirrors LocalHalaqaRepository.leaveHalaqa: delete the circle once its
-- last member leaves. SECURITY DEFINER because the last member to leave
-- often isn't the creator, who alone can normally delete a halaqa row.
CREATE OR REPLACE FUNCTION public.cleanup_empty_halaqa()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM halaqa_members WHERE halaqa_id = OLD.halaqa_id) THEN
    DELETE FROM halaqas WHERE id = OLD.halaqa_id;
  END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS halaqa_cleanup_on_leave ON halaqa_members;
CREATE TRIGGER halaqa_cleanup_on_leave
  AFTER DELETE ON halaqa_members
  FOR EACH ROW EXECUTE FUNCTION public.cleanup_empty_halaqa();

-- ═══════════════════════════════════════════════════════════════
-- RLS — reaction ledgers
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE halaqa_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE minbar_reactions ENABLE ROW LEVEL SECURITY;

-- halaqa_reactions: visible to fellow circle members only; a user may only
-- create/remove their OWN reaction, and only while a member of that circle.
CREATE POLICY halaqa_reactions_select_member ON halaqa_reactions
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM halaqa_shares hs
      JOIN halaqa_members hm ON hm.halaqa_id = hs.halaqa_id
      WHERE hs.id = halaqa_reactions.share_id AND hm.user_id = auth.uid()
    )
  );
CREATE POLICY halaqa_reactions_insert_own ON halaqa_reactions
  FOR INSERT TO authenticated WITH CHECK (
    auth.uid() = user_id AND EXISTS (
      SELECT 1 FROM halaqa_shares hs
      JOIN halaqa_members hm ON hm.halaqa_id = hs.halaqa_id
      WHERE hs.id = halaqa_reactions.share_id AND hm.user_id = auth.uid()
    )
  );
CREATE POLICY halaqa_reactions_delete_own ON halaqa_reactions
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- minbar_reactions: counts are part of the public feed, so readable by
-- anyone; only the reacting user can create/remove their own reaction.
CREATE POLICY minbar_reactions_select_public ON minbar_reactions
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY minbar_reactions_insert_own ON minbar_reactions
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY minbar_reactions_delete_own ON minbar_reactions
  FOR DELETE TO authenticated USING (auth.uid() = user_id);
