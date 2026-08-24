-- ═══════════════════════════════════════════════════════════════════════════
-- 004_repair_idempotent.sql
--
-- Brings a Supabase project up to what the Mizan app actually needs, from
-- whatever state it is currently in. Written to be run after
-- VERIFY_schema.sql reports anything MISSING or WRONG, and safe to run again
-- afterwards — every statement is either IF NOT EXISTS, OR REPLACE, or guarded
-- by a catalogue check.
--
-- HOW TO RUN
--   Supabase dashboard -> SQL Editor -> paste the whole file -> Run.
--   Then run VERIFY_schema.sql again. It should say READY.
--
-- WHAT THIS WRITES TO YOUR DATA
--   Almost nothing. It creates and alters schema objects, not rows, with one
--   deliberate exception at the very end: accounts in auth.users that have no
--   public.users profile get one, because without it their name is blank on
--   every circle and Minbar post they make. Nothing is deleted and nothing
--   existing is overwritten.
--
-- WHAT IT WILL NOT DO FOR YOU
--   If a UNIQUE constraint cannot be added because duplicate rows already
--   exist, this script does not delete your rows to make room. It prints a
--   NOTICE naming the constraint and the exact statement to run, and carries
--   on. Read the Messages tab in the SQL editor after running.
--
--   Same for layer_cache.content_json: if it is TEXT holding something that is
--   not valid JSON, the conversion to jsonb is skipped with a NOTICE rather
--   than failing the whole script.
--
-- ORDER MATTERS
--   Tables, then columns, then defaults, then keys, then constraints, then
--   RLS and policies, then functions and triggers, then the backfill. A
--   foreign key cannot be added before the table it points at exists, and the
--   backfill must come after the trigger so that new sign-ups from that moment
--   on are handled by the trigger rather than by this script.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 0. Extension ──────────────────────────────────────────────────────────
-- Every id column defaults to uuid_generate_v4(). Without this, every insert
-- into every table below fails.
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── 1. Tables ─────────────────────────────────────────────────────────────
-- Full definitions, so this file works on an empty project as well as on a
-- partially-migrated one. On an existing project every one of these is a no-op.

CREATE TABLE IF NOT EXISTS public.users (
  id            UUID PRIMARY KEY,
  email         TEXT UNIQUE NOT NULL,
  display_name  TEXT NOT NULL,
  language_preference TEXT DEFAULT 'en',
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  last_active_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.halaqas (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  created_by  UUID NOT NULL,
  invite_code TEXT NOT NULL,
  max_members INT DEFAULT 8,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.halaqa_members (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  halaqa_id      UUID NOT NULL,
  user_id        UUID NOT NULL,
  joined_at      TIMESTAMPTZ DEFAULT NOW(),
  last_opened_at TIMESTAMPTZ DEFAULT NOW(),
  last_active_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.halaqa_shares (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  halaqa_id      UUID NOT NULL,
  shared_by      UUID NOT NULL,
  shared_by_name TEXT,
  content_id     TEXT NOT NULL,
  content_type   TEXT NOT NULL,
  content_json   TEXT,
  personal_note  TEXT CHECK (char_length(personal_note) <= 100),
  shared_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.halaqa_reactions (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  share_id   UUID NOT NULL,
  user_id    UUID NOT NULL,
  reaction   TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.minbar_shares (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shared_by       UUID NOT NULL,
  shared_by_name  TEXT,
  content_id      TEXT NOT NULL,
  content_type    TEXT NOT NULL,
  content_json    TEXT,
  dua_count       INT DEFAULT 0,
  resonated_count INT DEFAULT 0,
  shared_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.minbar_reactions (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  share_id   UUID NOT NULL,
  user_id    UUID NOT NULL,
  reaction   TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.layer_cache (
  id           BIGSERIAL PRIMARY KEY,
  surah_number INT NOT NULL,
  ayah_number  INT NOT NULL,
  layer_index  INT NOT NULL,
  content_json JSONB NOT NULL,
  generated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 2. Columns added after 001 ────────────────────────────────────────────
ALTER TABLE public.halaqa_shares  ADD COLUMN IF NOT EXISTS shared_by_name TEXT;
ALTER TABLE public.halaqa_shares  ADD COLUMN IF NOT EXISTS content_json   TEXT;
ALTER TABLE public.minbar_shares  ADD COLUMN IF NOT EXISTS shared_by_name TEXT;
ALTER TABLE public.minbar_shares  ADD COLUMN IF NOT EXISTS content_json   TEXT;
ALTER TABLE public.halaqa_members ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ DEFAULT NOW();

-- layer_cache.content_json has to be jsonb: the app decodes what comes back as
-- a map, and a TEXT column returns a quoted string it cannot read. Converted
-- rather than dropped, and skipped with a notice if any existing value is not
-- valid JSON, because losing a cache is cheap but failing this whole script is
-- not.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_attribute a
    WHERE a.attrelid = 'public.layer_cache'::regclass
      AND a.attname = 'content_json'
      AND format_type(a.atttypid, a.atttypmod) <> 'jsonb'
  ) THEN
    BEGIN
      ALTER TABLE public.layer_cache
        ALTER COLUMN content_json TYPE JSONB USING content_json::jsonb;
      RAISE NOTICE 'layer_cache.content_json converted to jsonb';
    EXCEPTION WHEN others THEN
      RAISE NOTICE 'layer_cache.content_json could not be converted to jsonb (%). The cache is disposable: TRUNCATE public.layer_cache; then run this file again.', SQLERRM;
    END;
  END IF;
END $$;

-- ── 3. Defaults the app depends on ────────────────────────────────────────
-- The app never sends an id or a created/shared timestamp, and it parses those
-- timestamps as non-null on the way back. SET DEFAULT is idempotent.
ALTER TABLE public.halaqas          ALTER COLUMN id             SET DEFAULT uuid_generate_v4();
ALTER TABLE public.halaqas          ALTER COLUMN created_at     SET DEFAULT NOW();
ALTER TABLE public.halaqa_members   ALTER COLUMN id             SET DEFAULT uuid_generate_v4();
ALTER TABLE public.halaqa_members   ALTER COLUMN joined_at      SET DEFAULT NOW();
ALTER TABLE public.halaqa_members   ALTER COLUMN last_active_at SET DEFAULT NOW();
ALTER TABLE public.halaqa_shares    ALTER COLUMN id             SET DEFAULT uuid_generate_v4();
ALTER TABLE public.halaqa_shares    ALTER COLUMN shared_at      SET DEFAULT NOW();
ALTER TABLE public.halaqa_reactions ALTER COLUMN id             SET DEFAULT uuid_generate_v4();
ALTER TABLE public.halaqa_reactions ALTER COLUMN created_at     SET DEFAULT NOW();
ALTER TABLE public.minbar_shares    ALTER COLUMN id             SET DEFAULT uuid_generate_v4();
ALTER TABLE public.minbar_shares    ALTER COLUMN shared_at      SET DEFAULT NOW();
ALTER TABLE public.minbar_reactions ALTER COLUMN id             SET DEFAULT uuid_generate_v4();
ALTER TABLE public.minbar_reactions ALTER COLUMN created_at     SET DEFAULT NOW();
ALTER TABLE public.layer_cache      ALTER COLUMN generated_at   SET DEFAULT NOW();

-- users.id must have NO default: an id has to come from auth.users, and a
-- random one would create a profile that belongs to no account.
ALTER TABLE public.users ALTER COLUMN id DROP DEFAULT;

-- ── 4. Unique constraints ─────────────────────────────────────────────────
-- Added only when no UNIQUE or PRIMARY KEY already covers exactly that column
-- set, so re-running never tries to add a second copy under a different name.
--
-- halaqas.invite_code is the load-bearing one: createHalaqa generates a code,
-- checks it is free, then inserts, which is a race. This constraint is what
-- actually closes it, and the retry loop in the app looks for this constraint
-- in the error text.
DO $$
DECLARE
  w record;
BEGIN
  FOR w IN
    SELECT * FROM (VALUES
      ('users',            'users_email_key',              'email',                                'email'),
      ('halaqas',          'halaqas_invite_code_key',      'invite_code',                          'invite_code'),
      ('halaqa_members',   'halaqa_members_halaqa_user_key','halaqa_id, user_id',                  'halaqa_id,user_id'),
      ('halaqa_reactions', 'halaqa_reactions_unique',      'share_id, user_id, reaction',          'reaction,share_id,user_id'),
      ('minbar_reactions', 'minbar_reactions_unique',      'share_id, user_id, reaction',          'reaction,share_id,user_id'),
      ('layer_cache',      'layer_cache_ayah_layer_key',   'surah_number, ayah_number, layer_index','ayah_number,layer_index,surah_number')
    ) AS v(tbl, cname, decl, sorted)
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint con
      WHERE con.conrelid = ('public.' || w.tbl)::regclass
        AND con.contype IN ('u', 'p')
        AND (SELECT string_agg(a.attname, ',' ORDER BY a.attname)
               FROM pg_attribute a
              WHERE a.attrelid = con.conrelid
                AND a.attnum = ANY (con.conkey)) = w.sorted
    ) THEN
      BEGIN
        EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I UNIQUE (%s)',
                       w.tbl, w.cname, w.decl);
        RAISE NOTICE 'added UNIQUE %.(%)', w.tbl, w.decl;
      EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'could NOT add UNIQUE %(%) because duplicate rows already exist. Look at them first: SELECT %s, count(*) FROM public.%I GROUP BY %s HAVING count(*) > 1;',
          w.tbl, w.decl, w.decl, w.tbl, w.decl;
      WHEN others THEN
        RAISE NOTICE 'could NOT add UNIQUE %(%): %', w.tbl, w.decl, SQLERRM;
      END;
    END IF;
  END LOOP;
END $$;

-- ── 5. Foreign keys ──────────────────────────────────────────────────────
-- Every existing foreign key on the target column is dropped first and exactly
-- one is put back. That is deliberate: PostgREST resolves an embed like
-- `users(display_name)` by finding *the* foreign key between the two tables,
-- and a second one — even a correct second one — makes the embed ambiguous.
-- PostgREST then answers PGRST200 and the circle member list comes back empty
-- with an error that names neither table. One key per column, always.
DO $$
DECLARE
  w     record;
  found record;
BEGIN
  FOR w IN
    SELECT * FROM (VALUES
      ('users',            'id',        'auth.users',           'CASCADE'),
      ('halaqas',          'created_by','public.users',          'NO ACTION'),
      ('halaqa_members',   'halaqa_id', 'public.halaqas',        'CASCADE'),
      ('halaqa_members',   'user_id',   'public.users',          'CASCADE'),
      ('halaqa_shares',    'halaqa_id', 'public.halaqas',        'CASCADE'),
      ('halaqa_shares',    'shared_by', 'public.users',          'CASCADE'),
      ('halaqa_reactions', 'share_id',  'public.halaqa_shares',  'CASCADE'),
      ('halaqa_reactions', 'user_id',   'auth.users',            'CASCADE'),
      ('minbar_shares',    'shared_by', 'public.users',          'CASCADE'),
      ('minbar_reactions', 'share_id',  'public.minbar_shares',  'CASCADE'),
      ('minbar_reactions', 'user_id',   'auth.users',            'CASCADE')
    ) AS v(tbl, col, ref, ondel)
  LOOP
    FOR found IN
      SELECT con.conname
      FROM pg_constraint con
      JOIN pg_attribute a
        ON a.attrelid = con.conrelid AND a.attnum = ANY (con.conkey)
      WHERE con.conrelid = ('public.' || w.tbl)::regclass
        AND con.contype = 'f'
        AND a.attname = w.col
    LOOP
      EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT %I', w.tbl, found.conname);
    END LOOP;

    BEGIN
      EXECUTE format(
        'ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES %s(id) ON DELETE %s',
        w.tbl, w.tbl || '_' || w.col || '_fkey', w.col, w.ref, w.ondel);
    EXCEPTION WHEN foreign_key_violation THEN
      RAISE NOTICE 'could NOT add %.% -> % because existing rows point at ids that do not exist there. Find them: SELECT * FROM public.%I t WHERE t.%I IS NOT NULL AND NOT EXISTS (SELECT 1 FROM %s r WHERE r.id = t.%I);',
        w.tbl, w.col, w.ref, w.tbl, w.col, w.ref, w.col;
    WHEN others THEN
      RAISE NOTICE 'could NOT add %.% -> %: %', w.tbl, w.col, w.ref, SQLERRM;
    END;
  END LOOP;
END $$;

-- ── 6. CHECK constraints ─────────────────────────────────────────────────
-- 001 wrote the content_type CHECK before the Seerah section existed, so a
-- project still carrying 001's version rejects every Seerah share with a
-- constraint violation and nothing else in the app misbehaves. Every CHECK
-- mentioning the column is dropped by definition rather than by name, because
-- 001's was auto-named and the name differs between projects.
DO $$
DECLARE
  w     record;
  found record;
BEGIN
  FOR w IN
    SELECT * FROM (VALUES
      ('halaqa_shares',    'content_type', '''quran'',''hadith'',''sahabi'',''name'',''prophet'',''seerah'''),
      ('minbar_shares',    'content_type', '''quran'',''hadith'',''sahabi'',''name'',''prophet'',''seerah'''),
      ('halaqa_reactions', 'reaction',     '''dua'',''resonated'',''moved'''),
      ('minbar_reactions', 'reaction',     '''dua'',''resonated'',''moved''')
    ) AS v(tbl, col, allowed)
  LOOP
    FOR found IN
      SELECT con.conname
      FROM pg_constraint con
      WHERE con.conrelid = ('public.' || w.tbl)::regclass
        AND con.contype = 'c'
        AND pg_get_constraintdef(con.oid) LIKE '%' || w.col || '%'
    LOOP
      EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT %I', w.tbl, found.conname);
    END LOOP;

    BEGIN
      EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I CHECK (%I IN (%s))',
                     w.tbl, w.tbl || '_' || w.col || '_check', w.col, w.allowed);
    EXCEPTION WHEN check_violation THEN
      RAISE NOTICE 'could NOT add the % CHECK on % because existing rows hold a value outside (%). See them: SELECT DISTINCT %I FROM public.%I;',
        w.col, w.tbl, w.allowed, w.col, w.tbl;
    WHEN others THEN
      RAISE NOTICE 'could NOT add the % CHECK on %: %', w.col, w.tbl, SQLERRM;
    END;
  END LOOP;
END $$;

-- ── 7. Row Level Security ────────────────────────────────────────────────
-- The app ships with a publishable key, which means anybody who unpacks the
-- APK holds it. RLS is the only thing standing between that key and every row.
ALTER TABLE public.users            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.halaqas          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.halaqa_members   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.halaqa_shares    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.halaqa_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.minbar_shares    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.minbar_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.layer_cache      ENABLE ROW LEVEL SECURITY;

-- Every policy is dropped and recreated, so this file is the single authority
-- on what access exists. CREATE POLICY has no IF NOT EXISTS form, so DROP
-- IF EXISTS first is how it is made idempotent.

-- users: any signed-in person can read profiles, because a circle member list
-- needs everyone's name. Only the owner can write their own row.
DROP POLICY IF EXISTS users_select_authenticated ON public.users;
CREATE POLICY users_select_authenticated ON public.users
  FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS users_insert_own ON public.users;
CREATE POLICY users_insert_own ON public.users
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
DROP POLICY IF EXISTS users_update_own ON public.users;
CREATE POLICY users_update_own ON public.users
  FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- halaqas: the invite code is the secret, not row visibility — you have to be
-- able to look a circle up before you are a member of it in order to join.
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

-- halaqa_members: your own memberships, plus the members of circles you are
-- in. 002's version showed only fellow members, which meant "my circles" and
-- the already-a-member check both returned nothing — the queries that run
-- before you are a fellow member of anything.
--
-- The membership test goes through public.is_halaqa_member(), created by
-- 005_fix_rls_and_backfill.sql. It must not be inlined here. An earlier version
-- of this file wrote the EXISTS clause directly, and because a SELECT policy on
-- halaqa_members whose USING clause reads halaqa_members re-triggers itself,
-- every query against the table died with 42P17 "infinite recursion detected in
-- policy for relation halaqa_members". That shipped, and it broke circles and
-- Al-Minbar for a real user. SECURITY DEFINER is what breaks the loop.
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

-- halaqa_shares: a circle's feed belongs to its members and to nobody else.
-- Same helper, same reason: an inline read of halaqa_members here triggers
-- halaqa_members' own policy, and the recursion aborts this query too.
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

-- halaqa_reactions: visible to fellow members; you may only create or remove
-- your own, and only while you are in that circle.
DROP POLICY IF EXISTS halaqa_reactions_select_member ON public.halaqa_reactions;
CREATE POLICY halaqa_reactions_select_member ON public.halaqa_reactions
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.halaqa_shares hs
      JOIN public.halaqa_members hm ON hm.halaqa_id = hs.halaqa_id
      WHERE hs.id = halaqa_reactions.share_id AND hm.user_id = auth.uid()
    )
  );
DROP POLICY IF EXISTS halaqa_reactions_insert_own ON public.halaqa_reactions;
CREATE POLICY halaqa_reactions_insert_own ON public.halaqa_reactions
  FOR INSERT TO authenticated WITH CHECK (
    auth.uid() = user_id AND EXISTS (
      SELECT 1 FROM public.halaqa_shares hs
      JOIN public.halaqa_members hm ON hm.halaqa_id = hs.halaqa_id
      WHERE hs.id = halaqa_reactions.share_id AND hm.user_id = auth.uid()
    )
  );
DROP POLICY IF EXISTS halaqa_reactions_delete_own ON public.halaqa_reactions;
CREATE POLICY halaqa_reactions_delete_own ON public.halaqa_reactions
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- minbar_shares: a public feed, readable without an account. Only the author
-- writes.
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

-- minbar_reactions: the counts are part of the public feed, so readable by
-- anyone; only the person reacting can add or remove their own.
DROP POLICY IF EXISTS minbar_reactions_select_public ON public.minbar_reactions;
CREATE POLICY minbar_reactions_select_public ON public.minbar_reactions
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS minbar_reactions_insert_own ON public.minbar_reactions;
CREATE POLICY minbar_reactions_insert_own ON public.minbar_reactions
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS minbar_reactions_delete_own ON public.minbar_reactions;
CREATE POLICY minbar_reactions_delete_own ON public.minbar_reactions
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- layer_cache: shared, non-personal content. Nothing here is about a person.
DROP POLICY IF EXISTS layer_cache_select_public ON public.layer_cache;
CREATE POLICY layer_cache_select_public ON public.layer_cache
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS layer_cache_write_public ON public.layer_cache;
CREATE POLICY layer_cache_write_public ON public.layer_cache
  FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS layer_cache_update_public ON public.layer_cache;
CREATE POLICY layer_cache_update_public ON public.layer_cache
  FOR UPDATE TO anon, authenticated USING (true);

-- ── 8. Functions and triggers ────────────────────────────────────────────
-- All three are SECURITY DEFINER with a pinned search_path. Each one has a
-- specific reason, stated where it is defined; none of them is defensive
-- boilerplate.

-- Creates the profile row the instant somebody signs up, so the app never has
-- to race it. AuthRepository also upserts after sign-up, but this is the
-- source of truth and the reason a name is never blank.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
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

-- The eight-member cap, enforced in the database. The client cannot do this:
-- count-then-insert is a race, and two people accepting the same invite at the
-- same moment would both get in. SECURITY DEFINER because a prospective joiner
-- is not yet a member, so the RLS policy above hides the very rows the cap has
-- to count.
CREATE OR REPLACE FUNCTION public.check_halaqa_capacity()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  cap           INT;
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

DROP TRIGGER IF EXISTS halaqa_capacity_check ON public.halaqa_members;
CREATE TRIGGER halaqa_capacity_check
  BEFORE INSERT ON public.halaqa_members
  FOR EACH ROW EXECUTE FUNCTION public.check_halaqa_capacity();

-- Deletes a circle once its last member leaves, so an empty circle does not
-- hold its invite code reserved forever. SECURITY DEFINER because the last
-- member to leave is usually not the creator, and only the creator may delete
-- a halaqa row.
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

DROP TRIGGER IF EXISTS halaqa_cleanup_on_leave ON public.halaqa_members;
CREATE TRIGGER halaqa_cleanup_on_leave
  AFTER DELETE ON public.halaqa_members
  FOR EACH ROW EXECUTE FUNCTION public.cleanup_empty_halaqa();

-- ── 9. Indexes ───────────────────────────────────────────────────────────
-- The three queries the app runs on every screen open.
CREATE INDEX IF NOT EXISTS idx_halaqa_members_halaqa   ON public.halaqa_members(halaqa_id);
CREATE INDEX IF NOT EXISTS idx_halaqa_members_user     ON public.halaqa_members(user_id);
CREATE INDEX IF NOT EXISTS idx_halaqa_shares_halaqa    ON public.halaqa_shares(halaqa_id, shared_at DESC);
CREATE INDEX IF NOT EXISTS idx_halaqa_reactions_share  ON public.halaqa_reactions(share_id);
CREATE INDEX IF NOT EXISTS idx_minbar_shares_time      ON public.minbar_shares(shared_at DESC);
CREATE INDEX IF NOT EXISTS idx_minbar_reactions_share  ON public.minbar_reactions(share_id);

-- ── 10. Backfill ─────────────────────────────────────────────────────────
-- The one place this file writes to your data. An account with no profile row
-- shows a blank name on every circle and Minbar post it makes, and the person
-- has no way to fix it from inside the app. This is last on purpose: the
-- trigger above is already in place by now, so from this moment on new
-- sign-ups are handled there and this only ever has to catch up on the past.
--
-- Nothing existing is overwritten — ON CONFLICT DO NOTHING — so a profile
-- somebody has already renamed keeps the name they chose.
INSERT INTO public.users (id, email, display_name)
SELECT
  au.id,
  COALESCE(au.email, au.id::text || '@unknown.invalid'),
  COALESCE(
    NULLIF(TRIM(au.raw_user_meta_data->>'display_name'), ''),
    NULLIF(split_part(COALESCE(au.email, ''), '@', 1), ''),
    'Member'
  )
FROM auth.users au
WHERE NOT EXISTS (SELECT 1 FROM public.users pu WHERE pu.id = au.id)
ON CONFLICT (id) DO NOTHING;

-- Now run VERIFY_schema.sql again. It should say READY.
