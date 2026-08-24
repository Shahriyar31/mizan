-- ⚠  SUPERSEDED — DO NOT RUN THIS FILE.
--
-- The halaqa_members SELECT policy below is recursive: its USING clause reads
-- halaqa_members, which re-triggers the same policy, so Postgres aborts every
-- query against the table with
--     42P17  infinite recursion detected in policy for relation "halaqa_members"
-- This shipped. It broke loading circles, creating a circle, and sharing to
-- Al-Minbar for a real user, while signing in still appeared to work.
--
-- Run supabase/migrations/005_fix_rls_and_backfill.sql instead. It replaces
-- these policies with ones that route the membership test through the
-- SECURITY DEFINER helper public.is_halaqa_member(uuid), which does not
-- re-enter RLS. This file is kept only as migration history.
--
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
