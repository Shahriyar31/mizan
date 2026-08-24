-- ═══════════════════════════════════════════════════════════════════════
-- 005_fix_rls_and_backfill.sql
--
-- Run this ONCE in the Supabase SQL Editor, as the project owner.
--
-- WHAT THIS FIXES
-- Signing in worked, but loading circles, creating a circle and sharing to
-- Al-Minbar all failed. Two separate causes, both invisible from the app:
--
--   1. INFINITE RECURSION. Every earlier script (002, 003, 004 and the
--      bundle) gave halaqa_members a SELECT policy whose USING clause reads
--      halaqa_members. Postgres re-applies the policy to that inner read,
--      which re-applies it again, and aborts the whole query with
--      42P17 "infinite recursion detected in policy for relation
--      halaqa_members". That is why the circles list showed an ERROR rather
--      than an empty state: an empty table returns no rows, it does not fail.
--      The fix is the standard one — move the membership test into a
--      SECURITY DEFINER function, which runs as its owner and therefore does
--      not re-trigger RLS. The policy text then never names its own table.
--
--   2. NO POLICIES AT ALL, most likely. The live database was built by
--      pasting the table dump, and a dump of tables carries no policies. With
--      RLS enabled and zero policies, Postgres denies every write and returns
--      nothing for every read — which is exactly the reported behaviour.
--
-- This script is idempotent: running it twice is harmless, and it does not
-- delete a single row of anyone's data. It ends with a report.
-- ═══════════════════════════════════════════════════════════════════════


-- ── Part 0 · Record the "before" state so the report can show what changed
-- The SQL Editor only displays the LAST result, so this is parked in a temp
-- table rather than selected now.
DROP TABLE IF EXISTS _mizan_before;
CREATE TEMP TABLE _mizan_before AS
SELECT
  (SELECT count(*) FROM pg_policies WHERE schemaname = 'public') AS policies,
  (SELECT count(*) FROM public.users)                            AS users_rows,
  (SELECT count(*) FROM auth.users)                              AS auth_rows;


-- ── Part 1 · The recursion fix ──────────────────────────────────────────
-- SECURITY DEFINER runs the body as the function's owner, so the read of
-- halaqa_members inside it is not subject to halaqa_members' own policy.
-- STABLE lets the planner call it once per row-group instead of per row.
-- The pinned search_path is required: without it, a caller could point
-- "halaqa_members" at a table of their own making.
CREATE OR REPLACE FUNCTION public.is_halaqa_member(p_halaqa_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.halaqa_members
    WHERE halaqa_id = p_halaqa_id AND user_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_halaqa_member(UUID) TO authenticated;


-- ── Part 2 · Row Level Security stays ON everywhere ─────────────────────
-- Looping rather than listing, because the four private tables may or may
-- not exist in this project and a missing one must not abort the script.
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'users','halaqas','halaqa_members','halaqa_shares','halaqa_reactions',
    'minbar_shares','minbar_reactions','layer_cache',
    'user_progress','vocabulary_bank','muhasabah_entries','friday_reflections'
  ] LOOP
    IF EXISTS (SELECT 1 FROM pg_class c
               WHERE c.relname = t AND c.relnamespace = 'public'::regnamespace) THEN
      EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    END IF;
  END LOOP;
END $$;


-- ── Part 2b · Tables that arrived in later migrations ───────────────────
-- layer_cache came in 002 and the two reaction tables in 003. If neither
-- script was ever run against this project those tables are absent, and a
-- CREATE POLICY naming a missing table is a hard error — which, because the
-- SQL Editor wraps the whole script in one transaction, would roll back
-- everything above it and leave the database exactly as broken as before.
-- Creating them first costs nothing when they already exist.
CREATE TABLE IF NOT EXISTS public.layer_cache (
  id            BIGSERIAL PRIMARY KEY,
  surah_number  INT NOT NULL,
  ayah_number   INT NOT NULL,
  layer_index   INT NOT NULL,
  content_json  JSONB NOT NULL,
  generated_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (surah_number, ayah_number, layer_index)
);

CREATE TABLE IF NOT EXISTS public.halaqa_reactions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  share_id   UUID NOT NULL REFERENCES public.halaqa_shares(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reaction   TEXT NOT NULL CHECK (reaction IN ('dua','resonated','moved')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (share_id, user_id, reaction)
);

CREATE TABLE IF NOT EXISTS public.minbar_reactions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  share_id   UUID NOT NULL REFERENCES public.minbar_shares(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reaction   TEXT NOT NULL CHECK (reaction IN ('dua','resonated','moved')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (share_id, user_id, reaction)
);

ALTER TABLE public.layer_cache      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.halaqa_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.minbar_reactions ENABLE ROW LEVEL SECURITY;


-- ── Part 3 · Policies ───────────────────────────────────────────────────
-- CREATE POLICY has no IF NOT EXISTS, so each one is dropped first. That is
-- what makes this script safe to re-run.

-- users: any signed-in person can read profiles, because Halaqa member lists
-- and Minbar attribution show display names. Only the owner may write.
DROP POLICY IF EXISTS users_select_authenticated ON public.users;
CREATE POLICY users_select_authenticated ON public.users
  FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS users_insert_own ON public.users;
CREATE POLICY users_insert_own ON public.users
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
DROP POLICY IF EXISTS users_update_own ON public.users;
CREATE POLICY users_update_own ON public.users
  FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- halaqas: the invite code is the secret, not row visibility — a joiner has
-- to be able to look a circle up before they belong to it.
DROP POLICY IF EXISTS halaqas_select_authenticated ON public.halaqas;
CREATE POLICY halaqas_select_authenticated ON public.halaqas
  FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS halaqas_insert_own ON public.halaqas;
CREATE POLICY halaqas_insert_own ON public.halaqas
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = created_by);
DROP POLICY IF EXISTS halaqas_update_own ON public.halaqas;
CREATE POLICY halaqas_update_own ON public.halaqas
  FOR UPDATE TO authenticated USING (auth.uid() = created_by);
DROP POLICY IF EXISTS halaqas_delete_own ON public.halaqas;
CREATE POLICY halaqas_delete_own ON public.halaqas
  FOR DELETE TO authenticated USING (auth.uid() = created_by);

-- halaqa_members: your own rows, plus the roster of circles you are in.
-- NOTE the helper call — this is the line that used to recurse.
DROP POLICY IF EXISTS halaqa_members_select_fellow ON public.halaqa_members;
DROP POLICY IF EXISTS halaqa_members_select_self_or_fellow ON public.halaqa_members;
CREATE POLICY halaqa_members_select_self_or_fellow ON public.halaqa_members
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_halaqa_member(halaqa_id));
DROP POLICY IF EXISTS halaqa_members_insert_self ON public.halaqa_members;
CREATE POLICY halaqa_members_insert_self ON public.halaqa_members
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS halaqa_members_update_self ON public.halaqa_members;
CREATE POLICY halaqa_members_update_self ON public.halaqa_members
  FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS halaqa_members_delete_self ON public.halaqa_members;
CREATE POLICY halaqa_members_delete_self ON public.halaqa_members
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- halaqa_shares: a circle's feed belongs to its members and nobody else.
DROP POLICY IF EXISTS halaqa_shares_select_member ON public.halaqa_shares;
CREATE POLICY halaqa_shares_select_member ON public.halaqa_shares
  FOR SELECT TO authenticated USING (public.is_halaqa_member(halaqa_id));
DROP POLICY IF EXISTS halaqa_shares_insert_member ON public.halaqa_shares;
CREATE POLICY halaqa_shares_insert_member ON public.halaqa_shares
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = shared_by AND public.is_halaqa_member(halaqa_id));
DROP POLICY IF EXISTS halaqa_shares_update_own ON public.halaqa_shares;
CREATE POLICY halaqa_shares_update_own ON public.halaqa_shares
  FOR UPDATE TO authenticated USING (auth.uid() = shared_by);
DROP POLICY IF EXISTS halaqa_shares_delete_own ON public.halaqa_shares;
CREATE POLICY halaqa_shares_delete_own ON public.halaqa_shares
  FOR DELETE TO authenticated USING (auth.uid() = shared_by);

-- halaqa_reactions: reachable only through a share you are entitled to see.
DROP POLICY IF EXISTS halaqa_reactions_select_member ON public.halaqa_reactions;
CREATE POLICY halaqa_reactions_select_member ON public.halaqa_reactions
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.halaqa_shares s
            WHERE s.id = halaqa_reactions.share_id
              AND public.is_halaqa_member(s.halaqa_id))
  );
DROP POLICY IF EXISTS halaqa_reactions_insert_own ON public.halaqa_reactions;
CREATE POLICY halaqa_reactions_insert_own ON public.halaqa_reactions
  FOR INSERT TO authenticated WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (SELECT 1 FROM public.halaqa_shares s
                WHERE s.id = halaqa_reactions.share_id
                  AND public.is_halaqa_member(s.halaqa_id))
  );
DROP POLICY IF EXISTS halaqa_reactions_delete_own ON public.halaqa_reactions;
CREATE POLICY halaqa_reactions_delete_own ON public.halaqa_reactions
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- minbar_shares: the public square. Readable by anyone; written only by its
-- author.
DROP POLICY IF EXISTS minbar_shares_select_public ON public.minbar_shares;
CREATE POLICY minbar_shares_select_public ON public.minbar_shares
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS minbar_shares_insert_own ON public.minbar_shares;
CREATE POLICY minbar_shares_insert_own ON public.minbar_shares
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = shared_by);
DROP POLICY IF EXISTS minbar_shares_update_own ON public.minbar_shares;
CREATE POLICY minbar_shares_update_own ON public.minbar_shares
  FOR UPDATE TO authenticated USING (auth.uid() = shared_by);
DROP POLICY IF EXISTS minbar_shares_delete_own ON public.minbar_shares;
CREATE POLICY minbar_shares_delete_own ON public.minbar_shares
  FOR DELETE TO authenticated USING (auth.uid() = shared_by);

DROP POLICY IF EXISTS minbar_reactions_select_public ON public.minbar_reactions;
CREATE POLICY minbar_reactions_select_public ON public.minbar_reactions
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS minbar_reactions_insert_own ON public.minbar_reactions;
CREATE POLICY minbar_reactions_insert_own ON public.minbar_reactions
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS minbar_reactions_delete_own ON public.minbar_reactions;
CREATE POLICY minbar_reactions_delete_own ON public.minbar_reactions
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- layer_cache: a shared, non-personal cache of generated ayah layers.
DROP POLICY IF EXISTS layer_cache_select_public ON public.layer_cache;
CREATE POLICY layer_cache_select_public ON public.layer_cache
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS layer_cache_write_public ON public.layer_cache;
CREATE POLICY layer_cache_write_public ON public.layer_cache
  FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS layer_cache_update_public ON public.layer_cache;
CREATE POLICY layer_cache_update_public ON public.layer_cache
  FOR UPDATE TO anon, authenticated USING (true);

-- The four private tables, if this project has them: owner-only, full stop.
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['user_progress','vocabulary_bank',
                           'muhasabah_entries','friday_reflections'] LOOP
    IF EXISTS (SELECT 1 FROM pg_class c
               WHERE c.relname = t AND c.relnamespace = 'public'::regnamespace) THEN
      EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_owner', t);
      EXECUTE format(
        'CREATE POLICY %I ON public.%I FOR ALL TO authenticated '
        'USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)',
        t || '_owner', t);
    END IF;
  END LOOP;
END $$;


-- ── Part 4 · The constraints the app relies on ──────────────────────────
-- The app retries on 23505 to survive an invite-code collision and to detect
-- "already a member". Without these UNIQUE constraints there is no 23505 to
-- catch, and duplicates land silently instead.
DO $$ BEGIN
  ALTER TABLE public.halaqa_members
    ADD CONSTRAINT halaqa_members_halaqa_id_user_id_key UNIQUE (halaqa_id, user_id);
EXCEPTION WHEN duplicate_table THEN NULL; WHEN duplicate_object THEN NULL;
          WHEN undefined_table THEN NULL; WHEN undefined_column THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE public.halaqa_reactions
    ADD CONSTRAINT halaqa_reactions_share_user_reaction_key UNIQUE (share_id, user_id, reaction);
EXCEPTION WHEN duplicate_table THEN NULL; WHEN duplicate_object THEN NULL;
          WHEN undefined_table THEN NULL; WHEN undefined_column THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE public.minbar_reactions
    ADD CONSTRAINT minbar_reactions_share_user_reaction_key UNIQUE (share_id, user_id, reaction);
EXCEPTION WHEN duplicate_table THEN NULL; WHEN duplicate_object THEN NULL;
          WHEN undefined_table THEN NULL; WHEN undefined_column THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE public.halaqas
    ADD CONSTRAINT halaqas_invite_code_key UNIQUE (invite_code);
EXCEPTION WHEN duplicate_table THEN NULL; WHEN duplicate_object THEN NULL;
          WHEN undefined_table THEN NULL; WHEN undefined_column THEN NULL; END $$;


-- ── Part 5 · The profile mirror ─────────────────────────────────────────
-- public.users must hold a row for every account, because halaqas.created_by,
-- halaqa_members.user_id and the Minbar all point at it. The trigger covers
-- everyone who signs up from now on; the backfill covers everyone who already
-- has an account — including the one that could not create a circle.
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

INSERT INTO public.users (id, email, display_name)
SELECT u.id,
       u.email,
       COALESCE(u.raw_user_meta_data->>'display_name', split_part(u.email, '@', 1))
FROM auth.users u
WHERE u.email IS NOT NULL AND u.email <> ''
ON CONFLICT (id) DO NOTHING;


-- ── Part 6 · Report ─────────────────────────────────────────────────────
-- "check" is a reserved word in Postgres and cannot be a bare column alias,
-- hence check_item.
SELECT '1 · policies in public'  AS check_item,
       b.policies::text || ' before  ->  ' ||
       (SELECT count(*) FROM pg_policies WHERE schemaname = 'public')::text || ' now' AS result
FROM _mizan_before b
UNION ALL
SELECT '2 · accounts mirrored into public.users',
       b.users_rows::text || ' of ' || b.auth_rows::text || ' before  ->  ' ||
       (SELECT count(*) FROM public.users)::text || ' of ' ||
       (SELECT count(*) FROM auth.users)::text || ' now'
FROM _mizan_before b
UNION ALL
SELECT '3 · recursion helper installed',
       CASE WHEN EXISTS (SELECT 1 FROM pg_proc
                         WHERE proname = 'is_halaqa_member'
                           AND pronamespace = 'public'::regnamespace)
            THEN 'yes' ELSE 'NO - part 1 did not run' END
UNION ALL
SELECT '4 · policy still naming its own table',
       CASE WHEN EXISTS (SELECT 1 FROM pg_policies
                         WHERE schemaname = 'public'
                           AND tablename = 'halaqa_members'
                           AND qual LIKE '%halaqa_members%')
            THEN 'STILL RECURSIVE - tell Claude' ELSE 'clean' END
UNION ALL
SELECT '5 · tables with RLS on but no policy',
       COALESCE((SELECT string_agg(c.relname::text, ', ' ORDER BY c.relname::text)
                 FROM pg_class c
                 WHERE c.relnamespace = 'public'::regnamespace
                   AND c.relkind = 'r' AND c.relrowsecurity
                   AND NOT EXISTS (SELECT 1 FROM pg_policies p
                                   WHERE p.schemaname = 'public'
                                     AND p.tablename = c.relname)), 'none - good')
ORDER BY 1;
