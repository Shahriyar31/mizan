-- ═══════════════════════════════════════════════════════════════════════
-- 006_fix_table_grants.sql
--
-- Run this ONCE in the Supabase SQL Editor, after 005.
--
-- WHAT THIS FIXES
-- After 005, the policy report came back clean on all five rows — 32 policies,
-- the recursion helper installed, no policy naming its own table, no table with
-- RLS on and nothing behind it. And the app still failed, with a DIFFERENT
-- message: "You do not have access to this", on the circles list, inside the
-- new-circle sheet, on the share sheet, AND on the Al-Minbar feed.
--
-- That last one is what identifies the cause. The Minbar feed read is
--     from('minbar_shares').select().order('shared_at').range(...)
-- with no join, no membership test and no filter on the account. Row-level
-- security cannot make that fail: RLS *filters* a SELECT down to the rows you
-- are allowed, and if that is none it returns an empty list. The repository
-- then hits `if (shares.isEmpty) return const []` and the screen shows its
-- empty state. It showed an ERROR, so the SELECT threw — and a SELECT that
-- throws has not been filtered, it has been refused outright.
--
-- Postgres has two separate permission gates and a request must pass both:
--
--   1. GRANT — may this role touch this table AT ALL? Failing this RAISES
--      42501 "permission denied for table x", on reads as well as writes.
--   2. RLS POLICIES — given that it may, WHICH ROWS? Failing this filters a
--      SELECT to zero rows and refuses an INSERT. It does not raise on SELECT.
--
-- 005 fixed gate 2. Nothing has ever configured gate 1. Supabase sets it up for
-- you via ALTER DEFAULT PRIVILEGES when tables are created through the
-- dashboard — but this database was built by pasting a schema dump, and a dump
-- of table definitions carries no GRANT statements, exactly as it carried no
-- policies. So `anon` and `authenticated` — the two roles every request from
-- the app arrives as — hold no privilege on any of these tables, and the
-- carefully-correct row rules behind them have never once been consulted.
--
-- One cause, all four screens. The grants below are deliberately narrow and
-- mirror the policies one for one, so the coarse gate never permits more than
-- the fine gate would have allowed anyway.
--
-- This script is idempotent, grants nothing to a table that does not exist,
-- deletes no data, and ends with a report that proves the result by actually
-- becoming the `authenticated` role and running the four failing queries.
-- ═══════════════════════════════════════════════════════════════════════


-- ── Part 0 · Record the "before" state ──────────────────────────────────
-- Parked in a temp table because the SQL Editor shows only the last result.
DROP TABLE IF EXISTS _mizan_grants_before;
CREATE TEMP TABLE _mizan_grants_before AS
SELECT
  t.tbl,
  has_table_privilege('authenticated', 'public.' || quote_ident(t.tbl), 'SELECT') AS auth_select,
  has_table_privilege('authenticated', 'public.' || quote_ident(t.tbl), 'INSERT') AS auth_insert,
  has_table_privilege('anon',          'public.' || quote_ident(t.tbl), 'SELECT') AS anon_select
FROM (
  SELECT unnest(ARRAY[
    'users','halaqas','halaqa_members','halaqa_shares','halaqa_reactions',
    'minbar_shares','minbar_reactions','layer_cache',
    'user_progress','vocabulary_bank','muhasabah_entries','friday_reflections'
  ]) AS tbl
) t
WHERE EXISTS (
  SELECT 1 FROM pg_class c
  WHERE c.relname = t.tbl AND c.relnamespace = 'public'::regnamespace
);

DROP TABLE IF EXISTS _mizan_schema_before;
CREATE TEMP TABLE _mizan_schema_before AS
SELECT
  has_schema_privilege('authenticated', 'public', 'USAGE') AS auth_usage,
  has_schema_privilege('anon',          'public', 'USAGE') AS anon_usage;


-- ── Part 1 · The schema itself ──────────────────────────────────────────
-- Without USAGE on the schema, no grant on a table inside it can be exercised.
-- This is the first thing to be missing and the easiest to overlook.
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;


-- ── Part 2 · Table privileges, mirroring the policies exactly ───────────
-- `authenticated` gets the four verbs on every table the app touches. That is
-- not a security decision — RLS is still the thing deciding which rows, and
-- 005 proved every one of these tables has RLS on with policies behind it.
-- Granting here only means "the door is not bolted"; the policies still decide
-- who walks through.
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
      EXECUTE format(
        'GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated', t);
    END IF;
  END LOOP;
END $$;

-- `anon` gets only what an anon policy actually permits. Signed out, the app
-- reads from on-device SQLite rather than Supabase, so this is a short list:
-- the public Minbar feed is readable by anyone, and layer_cache is a shared,
-- non-personal cache of generated ayah layers that anyone may fill.
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['minbar_shares','minbar_reactions','layer_cache'] LOOP
    IF EXISTS (SELECT 1 FROM pg_class c
               WHERE c.relname = t AND c.relnamespace = 'public'::regnamespace) THEN
      EXECUTE format('GRANT SELECT ON public.%I TO anon', t);
    END IF;
  END LOOP;

  IF EXISTS (SELECT 1 FROM pg_class c
             WHERE c.relname = 'layer_cache'
               AND c.relnamespace = 'public'::regnamespace) THEN
    GRANT INSERT, UPDATE ON public.layer_cache TO anon;
  END IF;
END $$;

-- layer_cache.id is BIGSERIAL, and an INSERT that takes a value from a sequence
-- needs USAGE on that sequence as well as INSERT on the table. Missing this
-- produces "permission denied for sequence layer_cache_id_seq", which reads
-- like a different problem entirely.
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;

-- The recursion helper from 005. 005 already granted this, so it is belt and
-- braces — but if the helper cannot be executed, every halaqa policy that calls
-- it fails, and the failure looks like a policy bug rather than a grant.
DO $$ BEGIN
  GRANT EXECUTE ON FUNCTION public.is_halaqa_member(UUID) TO authenticated;
EXCEPTION WHEN undefined_function THEN NULL; END $$;


-- ── Part 3 · Future tables ──────────────────────────────────────────────
-- Applies to objects created from now on by the role running this script, which
-- is what Supabase configures on a normal project. Without it, the next table
-- added through the SQL Editor arrives locked in exactly the same way and the
-- same afternoon gets spent twice.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO anon, authenticated, service_role;


-- ── Part 4 · Ask PostgREST to re-read the schema ────────────────────────
-- It caches the table and relationship layout. It reloads on its own, but
-- nudging it removes one variable from the next test.
NOTIFY pgrst, 'reload schema';


-- ── Part 5 · Prove it the way the app will experience it ────────────────
-- Everything above is a claim about privileges. This actually becomes the
-- `authenticated` role, presents the real account's id as a JWT claim the way
-- PostgREST does, and runs the two queries that were failing. That is the
-- difference between "the grants look right" and "the app will work".
--
-- Wrapped in its own exception block: the SQL Editor runs this whole file as
-- one transaction, and an uncaught error here would roll back every grant
-- above it and leave the database exactly as locked as before.
DROP TABLE IF EXISTS _mizan_probe;
CREATE TEMP TABLE _mizan_probe (step TEXT, outcome TEXT);

DO $$
DECLARE
  v_uid   UUID := '4c7d4de7-9e18-4ced-b9da-b7fe1a56d118';
  n       INT;
  r_users TEXT := 'not reached';
  r_mem   TEXT := 'not reached';
  r_join  TEXT := 'not reached';
  r_feed  TEXT := 'not reached';
  r_fail  TEXT := NULL;
BEGIN
  BEGIN
    -- This is the pair of settings PostgREST puts in place for every request
    -- from a signed-in phone, and what auth.uid() reads inside every policy.
    PERFORM set_config(
      'request.jwt.claims',
      json_build_object('sub', v_uid::text, 'role', 'authenticated')::text,
      true);
    SET LOCAL ROLE authenticated;

    -- The read that made sign-in report "your profile did not finish saving".
    SELECT count(*) INTO n FROM public.users WHERE id = v_uid;
    r_users := CASE WHEN n = 1 THEN 'yes - sign-in will be clean'
                    ELSE 'NO - found ' || n || ' rows' END;

    -- The read behind "Your circles could not be loaded."
    SELECT count(*) INTO n FROM public.halaqa_members WHERE user_id = v_uid;
    r_mem := 'yes - ' || n || ' membership rows (0 is right before any circle)';

    -- The relationship the circles list actually walks: members -> halaqas.
    SELECT count(*) INTO n
      FROM public.halaqa_members m
      JOIN public.halaqas h ON h.id = m.halaqa_id
     WHERE m.user_id = v_uid;
    r_join := 'yes - ' || n || ' circles';

    -- The public feed. This one is the tell: it needs no account and no
    -- membership, so if it errors, the failure cannot be about rows.
    SELECT count(*) INTO n FROM public.minbar_shares;
    r_feed := 'yes - ' || n || ' posts';
  EXCEPTION WHEN OTHERS THEN
    r_fail := SQLERRM || '  [' || SQLSTATE || ']';
  END;

  -- Drop the impersonation BEFORE writing anything down. The temp table below
  -- is owned by postgres and `authenticated` holds no privilege on it, so an
  -- INSERT while still impersonating would fail on the bookkeeping and the
  -- probe would report its own error instead of the answer it just found.
  RESET ROLE;

  IF r_fail IS NOT NULL THEN
    INSERT INTO _mizan_probe
      VALUES ('x - PROBE FAILED, send this line to Claude', r_fail);
  END IF;

  INSERT INTO _mizan_probe VALUES
    ('a - own profile row visible',  r_users),
    ('b - halaqa_members readable',  r_mem),
    ('c - circles join readable',    r_join),
    ('d - minbar feed readable',     r_feed);
END $$;


-- ── Part 6 · Report ─────────────────────────────────────────────────────
-- "check" is a reserved word and cannot be a bare column alias, hence
-- check_item. Ordered so the probe lands at the bottom, where the eye goes.
SELECT '1 - schema USAGE (authenticated / anon)' AS check_item,
       (CASE WHEN s.auth_usage THEN 'had it' ELSE 'was MISSING' END) || ' / ' ||
       (CASE WHEN s.anon_usage THEN 'had it' ELSE 'was MISSING' END) ||
       '  ->  both granted now' AS result
FROM _mizan_schema_before s

UNION ALL
SELECT '2 - tables authenticated could not read before',
       COALESCE((SELECT string_agg(tbl, ', ' ORDER BY tbl)
                 FROM _mizan_grants_before WHERE NOT auth_select),
                'none - grants were already fine, so this was NOT the cause')

UNION ALL
SELECT '3 - tables authenticated could not write before',
       COALESCE((SELECT string_agg(tbl, ', ' ORDER BY tbl)
                 FROM _mizan_grants_before WHERE NOT auth_insert),
                'none - grants were already fine, so this was NOT the cause')

UNION ALL
SELECT '4 - tables authenticated cannot read NOW',
       COALESCE((SELECT string_agg(b.tbl, ', ' ORDER BY b.tbl)
                 FROM _mizan_grants_before b
                 WHERE NOT has_table_privilege(
                   'authenticated', 'public.' || quote_ident(b.tbl), 'SELECT')),
                'none - every table is reachable')

UNION ALL
-- A safety check, not a fix. If a table in public has RLS switched off, the
-- grants above would expose it wholesale. 005 reported none, and this confirms
-- it after granting rather than before.
SELECT '5 - public tables with RLS switched OFF',
       COALESCE((SELECT string_agg(c.relname::text, ', ' ORDER BY c.relname::text)
                 FROM pg_class c
                 WHERE c.relnamespace = 'public'::regnamespace
                   AND c.relkind = 'r' AND NOT c.relrowsecurity),
                'none - every table is protected')

UNION ALL
SELECT 'probe ' || p.step, p.outcome FROM _mizan_probe p

ORDER BY 1;
