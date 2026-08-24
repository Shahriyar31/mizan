-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFY_schema.sql — read-only. Answers exactly one question:
--
--     "If my friends install this build tonight, what will break?"
--
-- HOW TO RUN
--   Supabase dashboard -> SQL Editor -> paste the whole file -> Run.
--   It reads system catalogues and counts rows in auth.users. It creates
--   nothing, alters nothing and deletes nothing, so it is safe to run against
--   the live project as often as you like. It does read auth.users, so it has
--   to be run from the SQL editor as the project owner; a restricted role will
--   get a permission error rather than a report.
--
-- HOW TO READ THE RESULT
--   One table, four columns, worst news first.
--
--     status      meaning                                   what to do
--     ─────────── ───────────────────────────────────────── ────────────────
--     NOT READY   at least one MISSING or WRONG below        read on
--     READY       nothing missing or wrong                   ship it
--     MISSING     the object is not there at all             run the repair
--     WRONG       it is there but will not do its job        read the detail
--     NOTE        worth knowing, does not block a launch     your call
--     OK          as expected                                nothing
--
--   The single `verdict` row is always first. If it says READY, the rest of
--   the report is all OK and NOTE and you do not need to read it.
--
--   For anything MISSING or WRONG, run 004_repair_idempotent.sql in the same
--   editor and then run this file again. The repair is safe to run more than
--   once. It deletes nothing and overwrites nothing; the only row it ever
--   writes is a missing profile for an account that has none.
--
-- WHAT IT CHECKS, AND WHY THOSE THINGS
--   Only the eight tables the Flutter app actually queries. The other five
--   tables in 001 (user_progress, vocabulary_bank, muhasabah_entries,
--   friday_reflections) are not read or written by any code in lib/, so their
--   state cannot break a launch and they are deliberately not reported on.
--
--   Every row here corresponds to something that has a specific, visible
--   failure if it is wrong. Two are worth calling out because they fail in
--   ways that do not look like a database problem:
--
--     * A second foreign key on halaqa_members.user_id makes PostgREST refuse
--       the `users(display_name)` embed with PGRST200, and the app's circle
--       member list goes empty with an error that mentions neither table.
--     * RLS enabled with zero policies is not a safe default. It denies
--       everything. The feature simply returns nothing, forever, with no
--       error anywhere — which is why enabled-with-no-policies is reported as
--       WRONG here and not as OK.
--
--   The content_type CHECK is read with pg_get_constraintdef(), not the old
--   pg_constraint.consrc column, which was removed in PostgreSQL 12.
-- ═══════════════════════════════════════════════════════════════════════════

WITH

-- ── Catalogue shorthands ──────────────────────────────────────────────────

public_rel AS (
  SELECT c.oid, c.relname, c.relrowsecurity
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'r'
),

actual_fk AS (
  SELECT
    con.conrelid                     AS rel,
    a.attname                        AS col,
    con.conname                      AS name,
    fn.nspname || '.' || fc.relname  AS ref
  FROM pg_constraint con
  JOIN pg_class     c  ON c.oid  = con.conrelid
  JOIN pg_namespace n  ON n.oid  = c.relnamespace AND n.nspname = 'public'
  JOIN pg_attribute a  ON a.attrelid = con.conrelid AND a.attnum = ANY (con.conkey)
  JOIN pg_class     fc ON fc.oid = con.confrelid
  JOIN pg_namespace fn ON fn.oid = fc.relnamespace
  WHERE con.contype = 'f'
),

-- UNIQUE and PRIMARY KEY constraints, with their column set sorted by name so
-- the comparison below does not depend on declaration order (ON CONFLICT does
-- not care about order either).
actual_unique AS (
  SELECT
    con.conrelid AS rel,
    con.conname  AS name,
    (SELECT string_agg(a.attname, ',' ORDER BY a.attname)
       FROM pg_attribute a
      WHERE a.attrelid = con.conrelid AND a.attnum = ANY (con.conkey)) AS cols
  FROM pg_constraint con
  JOIN pg_class     c ON c.oid = con.conrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = 'public'
  WHERE con.contype IN ('u', 'p')
),

-- ── What the app requires ─────────────────────────────────────────────────

want_table (tbl, why) AS (
  VALUES
    ('users'::text,      'one profile row per account. Halaqa member names and Minbar attribution both read from it'::text),
    ('halaqas',          'the circles themselves'),
    ('halaqa_members',   'who is in which circle, and what the capacity trigger counts'),
    ('halaqa_shares',    'what has been shared into a circle'),
    ('halaqa_reactions', 'Dua / Resonated / Moved inside a circle, one row per person per reaction'),
    ('minbar_shares',    'the public feed'),
    ('minbar_reactions', 'reactions on the public feed'),
    ('layer_cache',      'the shared ayah-layer cache')
),

want_column (tbl, col, typ, why) AS (
  VALUES
    -- users. AuthRepository upserts {id, email, display_name} after sign-up,
    -- and the circle member list embeds users(display_name).
    ('users'::text, 'id'::text,           'uuid'::text,                     'must equal auth.uid(); everything else keys off it'::text),
    ('users', 'email',                    'text',                           'shown nowhere, but the upsert sends it'),
    ('users', 'display_name',             'text',                           'the name on every circle member row and Minbar post'),

    -- halaqas. Read whole with select(), so every column is parsed.
    ('halaqas', 'id',                     'uuid',                           'circle identity'),
    ('halaqas', 'name',                   'text',                           'the circle name'),
    ('halaqas', 'created_by',             'uuid',                           'only the creator can rename or delete'),
    ('halaqas', 'invite_code',            'text',                           'the whole join flow is a lookup on this'),
    ('halaqas', 'max_members',            'integer',                        'the capacity trigger reads this; NULL means no cap'),
    ('halaqas', 'created_at',             'timestamp with time zone',       'parsed on read'),

    -- halaqa_members.
    ('halaqa_members', 'id',              'uuid',                           'member row identity'),
    ('halaqa_members', 'halaqa_id',       'uuid',                           'which circle'),
    ('halaqa_members', 'user_id',         'uuid',                           'which person'),
    ('halaqa_members', 'joined_at',       'timestamp with time zone',       'parsed on read and sorted on'),
    ('halaqa_members', 'last_active_at',  'timestamp with time zone',       'written by touchMember; read as nullable'),

    -- halaqa_shares. content_json is the real payload; content_id and
    -- content_type exist to satisfy 001's NOT NULL and CHECK.
    ('halaqa_shares', 'id',               'uuid',                           'share identity, and what reactions point at'),
    ('halaqa_shares', 'halaqa_id',        'uuid',                           'which circle'),
    ('halaqa_shares', 'shared_by',        'uuid',                           'who shared it'),
    ('halaqa_shares', 'shared_by_name',   'text',                           'the name shown on the card'),
    ('halaqa_shares', 'content_id',       'text',                           'legacy NOT NULL; the app fills it'),
    ('halaqa_shares', 'content_type',     'text',                           'legacy NOT NULL and CHECK; see the constraint rows'),
    ('halaqa_shares', 'content_json',     'text',                           'TEXT, not jsonb: the app stores an encoded string here'),
    ('halaqa_shares', 'personal_note',    'text',                           'the one optional note, 100 characters'),
    ('halaqa_shares', 'shared_at',        'timestamp with time zone',       'parsed on read and sorted on'),

    -- halaqa_reactions.
    ('halaqa_reactions', 'id',            'uuid',                           'reaction identity'),
    ('halaqa_reactions', 'share_id',      'uuid',                           'which share'),
    ('halaqa_reactions', 'user_id',       'uuid',                           'whose reaction; the app compares it to the signed-in id'),
    ('halaqa_reactions', 'reaction',      'text',                           'dua / resonated / moved'),
    ('halaqa_reactions', 'created_at',    'timestamp with time zone',       'not read by the app, but the insert relies on its default'),

    -- minbar_shares.
    ('minbar_shares', 'id',               'uuid',                           'share identity, and what reactions point at'),
    ('minbar_shares', 'shared_by',        'uuid',                           'who posted'),
    ('minbar_shares', 'shared_by_name',   'text',                           'the name shown on the card'),
    ('minbar_shares', 'content_id',       'text',                           'legacy NOT NULL; the app fills it'),
    ('minbar_shares', 'content_type',     'text',                           'legacy NOT NULL and CHECK; see the constraint rows'),
    ('minbar_shares', 'content_json',     'text',                           'TEXT, not jsonb: an encoded string'),
    ('minbar_shares', 'shared_at',        'timestamp with time zone',       'parsed on read; the feed is paged on it'),

    -- minbar_reactions.
    ('minbar_reactions', 'id',            'uuid',                           'reaction identity'),
    ('minbar_reactions', 'share_id',      'uuid',                           'which share'),
    ('minbar_reactions', 'user_id',       'uuid',                           'whose reaction'),
    ('minbar_reactions', 'reaction',      'text',                           'dua / resonated / moved'),
    ('minbar_reactions', 'created_at',    'timestamp with time zone',       'not read, but the insert relies on its default'),

    -- layer_cache.
    ('layer_cache', 'id',                 'bigint',                         'BIGSERIAL; the app never sends it'),
    ('layer_cache', 'surah_number',       'integer',                        'part of the conflict target'),
    ('layer_cache', 'ayah_number',        'integer',                        'part of the conflict target'),
    ('layer_cache', 'layer_index',        'integer',                        'part of the conflict target'),
    ('layer_cache', 'content_json',       'jsonb',                          'jsonb here, unlike the share tables. TEXT would make every read a string the app cannot decode'),
    ('layer_cache', 'generated_at',       'timestamp with time zone',       'cache age')
),

-- Defaults the app depends on because it never sends these values itself.
want_default (tbl, col, why) AS (
  VALUES
    ('halaqas'::text, 'id'::text,            'the insert sends no id'::text),
    ('halaqas', 'created_at',                'the insert sends no timestamp, and the read parses it as non-null'),
    ('halaqa_members', 'id',                 'the insert sends no id'),
    ('halaqa_members', 'joined_at',          'the insert sends no timestamp, and the read parses it as non-null'),
    ('halaqa_members', 'last_active_at',     'not sent when a member joins, only on touchMember'),
    ('halaqa_shares', 'id',                  'the insert sends no id'),
    ('halaqa_shares', 'shared_at',           'the insert sends no timestamp, and the read parses it as non-null'),
    ('halaqa_reactions', 'id',               'the insert sends no id'),
    ('halaqa_reactions', 'created_at',       'the insert sends no timestamp'),
    ('minbar_shares', 'id',                  'the insert sends no id'),
    ('minbar_shares', 'shared_at',           'the insert sends no timestamp, and the read parses it as non-null'),
    ('minbar_reactions', 'id',               'the insert sends no id'),
    ('minbar_reactions', 'created_at',       'the insert sends no timestamp'),
    ('layer_cache', 'id',                    'BIGSERIAL; the upsert sends no id'),
    ('layer_cache', 'generated_at',          'the upsert sends no timestamp')
),

want_fk (tbl, col, ref, why) AS (
  VALUES
    ('users'::text, 'id'::text, 'auth.users'::text,
       'without it a profile can outlive the account it describes, and deleting an account leaves an orphan row that still shows a name on old circle posts'::text),
    ('halaqas', 'created_by', 'public.users',
       'the only owner check the circle has'),
    ('halaqa_members', 'halaqa_id', 'public.halaqas',
       'PostgREST resolves the halaqas(*) embed through this FK. "My circles" is one query and it is that embed'),
    ('halaqa_members', 'user_id', 'public.users',
       'PostgREST resolves the users(display_name) embed through this FK. Exactly one FK is required: a second one, even a correct one to auth.users, makes the embed ambiguous and PostgREST answers PGRST200 instead of a member list'),
    ('halaqa_shares', 'halaqa_id', 'public.halaqas',
       'a share must belong to a circle that exists'),
    ('halaqa_shares', 'shared_by', 'public.users',
       'attribution'),
    ('halaqa_reactions', 'share_id', 'public.halaqa_shares',
       'ON DELETE CASCADE: deleting a share must take its reactions with it'),
    ('halaqa_reactions', 'user_id', 'auth.users',
       'deliberately auth.users, not public.users, unlike halaqa_members'),
    ('minbar_shares', 'shared_by', 'public.users',
       'attribution'),
    ('minbar_reactions', 'share_id', 'public.minbar_shares',
       'ON DELETE CASCADE: deleting a post must take its reactions with it'),
    ('minbar_reactions', 'user_id', 'auth.users',
       'deliberately auth.users, not public.users')
),

want_unique (tbl, shown, cols, why) AS (
  VALUES
    ('users'::text, 'email'::text, 'email'::text,
       'one account per address'::text),
    ('halaqas', 'invite_code', 'invite_code',
       'the only thing that actually guarantees two circles never share a code. createHalaqa generates a code, checks it, and inserts; that is a race, and this constraint is what closes it. The retry loop looks for this constraint name in the error'),
    ('halaqa_members', '(halaqa_id, user_id)', 'halaqa_id,user_id',
       'stops one person joining the same circle twice, which would also consume two of the eight seats'),
    ('halaqa_reactions', '(share_id, user_id, reaction)', 'reaction,share_id,user_id',
       'the reaction toggle is an insert-or-delete against this constraint. Without it a double tap counts twice'),
    ('minbar_reactions', '(share_id, user_id, reaction)', 'reaction,share_id,user_id',
       'same toggle on the public feed'),
    ('layer_cache', '(surah_number, ayah_number, layer_index)', 'ayah_number,layer_index,surah_number',
       'the upsert names this triple as its conflict target. Without the constraint the upsert raises 42P10 and every cache write fails')
),

want_trigger (trg, sch, tbl, why) AS (
  VALUES
    ('on_auth_user_created'::text, 'auth'::text, 'users'::text,
       'creates the public.users row the instant somebody signs up. Without it a new account has no profile, so their name is blank on every circle and Minbar post until they log in again'::text),
    ('halaqa_capacity_check', 'public', 'halaqa_members',
       'enforces the eight-member cap in the database. The client cannot: check-then-insert is a race, and two people accepting an invite at once would both get in'),
    ('halaqa_cleanup_on_leave', 'public', 'halaqa_members',
       'deletes a circle once its last member leaves, so an empty circle does not keep its invite code reserved forever')
),

want_function (fn, why) AS (
  VALUES
    ('handle_new_user'::text,      'the body of the sign-up trigger'::text),
    ('check_halaqa_capacity',      'the body of the capacity trigger. Must be SECURITY DEFINER: a prospective joiner is not yet a member, so RLS hides the very rows the cap has to count'),
    ('cleanup_empty_halaqa',       'the body of the cleanup trigger. Must be SECURITY DEFINER: the last member to leave is usually not the creator, and only the creator may delete a circle')
),

want_policy (tbl, pol, why) AS (
  VALUES
    ('users'::text, 'users_select_authenticated'::text, 'any signed-in user can read profiles; needed for member lists'::text),
    ('users', 'users_insert_own',                'the sign-up upsert'),
    ('users', 'users_update_own',                'renaming yourself'),
    ('halaqas', 'halaqas_select_authenticated',  'looking a circle up by invite code, before you are a member of it'),
    ('halaqas', 'halaqas_insert_own',            'creating a circle'),
    ('halaqas', 'halaqas_update_own',            'renaming your own circle'),
    ('halaqas', 'halaqas_delete_own',            'deleting your own circle'),
    ('halaqa_members', 'halaqa_members_select_self_or_fellow',
                                                 'your own memberships plus your fellow members. The 002 version saw only fellow members, which made "my circles" and the already-a-member check return nothing'),
    ('halaqa_members', 'halaqa_members_insert_self',  'joining'),
    ('halaqa_members', 'halaqa_members_update_self',  'touchMember'),
    ('halaqa_members', 'halaqa_members_delete_self',  'leaving'),
    ('halaqa_shares', 'halaqa_shares_select_member',  'reading the circle feed'),
    ('halaqa_shares', 'halaqa_shares_insert_member',  'sharing into a circle you belong to'),
    ('halaqa_shares', 'halaqa_shares_update_own',     'editing your own share'),
    ('halaqa_shares', 'halaqa_shares_delete_own',     'deleting your own share'),
    ('halaqa_reactions', 'halaqa_reactions_select_member', 'seeing the counts'),
    ('halaqa_reactions', 'halaqa_reactions_insert_own',    'reacting'),
    ('halaqa_reactions', 'halaqa_reactions_delete_own',    'un-reacting'),
    ('minbar_shares', 'minbar_shares_select_public',  'the feed is public'),
    ('minbar_shares', 'minbar_shares_insert_own',     'posting'),
    ('minbar_shares', 'minbar_shares_update_own',     'editing your own post'),
    ('minbar_shares', 'minbar_shares_delete_own',     'deleting your own post'),
    ('minbar_reactions', 'minbar_reactions_select_public', 'counts are part of the public feed'),
    ('minbar_reactions', 'minbar_reactions_insert_own',    'reacting'),
    ('minbar_reactions', 'minbar_reactions_delete_own',    'un-reacting'),
    ('layer_cache', 'layer_cache_select_public',      'reading the cache'),
    ('layer_cache', 'layer_cache_write_public',       'filling the cache'),
    ('layer_cache', 'layer_cache_update_public',      'refreshing an entry')
),

-- ── The checks ────────────────────────────────────────────────────────────

check_extension AS (
  SELECT
    'extension'::text AS category,
    'uuid-ossp'::text AS object,
    CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'uuid-ossp')
         THEN 'OK' ELSE 'MISSING' END::text AS status,
    CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'uuid-ossp')
         THEN 'uuid_generate_v4() is available'
         ELSE 'every id column defaults to uuid_generate_v4(), so without this '
              'extension every insert into every table fails. '
              'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'
    END::text AS detail
),

check_table AS (
  SELECT
    'table'::text AS category,
    w.tbl AS object,
    CASE WHEN r.oid IS NULL THEN 'MISSING' ELSE 'OK' END::text AS status,
    CASE WHEN r.oid IS NULL
         THEN 'not in the public schema. ' || w.why
         ELSE w.why END::text AS detail
  FROM want_table w
  LEFT JOIN public_rel r ON r.relname = w.tbl
),

-- Inner join on the table: when a table is missing, its column rows are
-- suppressed so the report says "one table missing" rather than "one table and
-- nine columns missing".
check_column AS (
  SELECT
    'column'::text AS category,
    (w.tbl || '.' || w.col) AS object,
    CASE
      WHEN a.attname IS NULL THEN 'MISSING'
      WHEN format_type(a.atttypid, a.atttypmod) <> w.typ THEN 'WRONG'
      ELSE 'OK'
    END::text AS status,
    CASE
      WHEN a.attname IS NULL
        THEN 'absent; expected ' || w.typ || '. ' || w.why
      WHEN format_type(a.atttypid, a.atttypmod) <> w.typ
        THEN 'is ' || format_type(a.atttypid, a.atttypmod)
             || ', expected ' || w.typ || '. ' || w.why
      ELSE w.typ || '. ' || w.why
    END::text AS detail
  FROM want_column w
  JOIN public_rel r ON r.relname = w.tbl
  LEFT JOIN pg_attribute a
    ON a.attrelid = r.oid AND a.attname = w.col
   AND a.attnum > 0 AND NOT a.attisdropped
),

check_default AS (
  SELECT
    'default'::text AS category,
    (w.tbl || '.' || w.col) AS object,
    CASE WHEN d.adrelid IS NULL THEN 'MISSING' ELSE 'OK' END::text AS status,
    CASE WHEN d.adrelid IS NULL
         THEN 'no default, and ' || w.why || ', so the insert fails'
         ELSE pg_get_expr(d.adbin, d.adrelid) END::text AS detail
  FROM want_default w
  JOIN public_rel r ON r.relname = w.tbl
  JOIN pg_attribute a
    ON a.attrelid = r.oid AND a.attname = w.col
   AND a.attnum > 0 AND NOT a.attisdropped
  LEFT JOIN pg_attrdef d ON d.adrelid = r.oid AND d.adnum = a.attnum
),

-- 002 drops the default on users.id so a profile can never be created with an
-- id that belongs to no account. Harmless if it is still there, because every
-- writer sends an id, but it means 002 did not finish.
check_users_id_default AS (
  SELECT
    'default'::text AS category,
    'users.id (must have none)'::text AS object,
    CASE WHEN d.adrelid IS NULL THEN 'OK' ELSE 'NOTE' END::text AS status,
    CASE WHEN d.adrelid IS NULL
         THEN 'no default, as intended: an id must come from auth.users'
         ELSE 'still defaults to ' || pg_get_expr(d.adbin, d.adrelid)
              || '. Harmless, because the trigger and the app both send an id, '
              || 'but 002 was meant to drop it' END::text AS detail
  FROM public_rel r
  JOIN pg_attribute a ON a.attrelid = r.oid AND a.attname = 'id'
  LEFT JOIN pg_attrdef d ON d.adrelid = r.oid AND d.adnum = a.attnum
  WHERE r.relname = 'users'
),

check_fk AS (
  SELECT
    'foreign key'::text AS category,
    (w.tbl || '.' || w.col) AS object,
    CASE
      WHEN count(f.name) = 0 THEN 'MISSING'
      WHEN count(f.name) > 1 THEN 'WRONG'
      WHEN min(f.ref) <> w.ref THEN 'WRONG'
      ELSE 'OK'
    END::text AS status,
    CASE
      WHEN count(f.name) = 0
        THEN 'no foreign key. ' || w.why
      WHEN count(f.name) > 1
        THEN count(f.name)::text || ' foreign keys on this one column ('
             || string_agg(f.name || ' -> ' || f.ref, ', ') || '). ' || w.why
      WHEN min(f.ref) <> w.ref
        THEN min(f.name) || ' points at ' || min(f.ref)
             || ', expected ' || w.ref || '. ' || w.why
      ELSE min(f.name) || ' -> ' || w.ref
    END::text AS detail
  FROM want_fk w
  JOIN public_rel r ON r.relname = w.tbl
  LEFT JOIN actual_fk f ON f.rel = r.oid AND f.col = w.col
  GROUP BY w.tbl, w.col, w.ref, w.why
),

check_unique AS (
  SELECT
    'unique'::text AS category,
    (w.tbl || ' ' || w.shown) AS object,
    CASE WHEN count(u.name) = 0 THEN 'MISSING' ELSE 'OK' END::text AS status,
    CASE WHEN count(u.name) = 0
         THEN 'no UNIQUE or PRIMARY KEY constraint over exactly these columns. '
              || w.why
         ELSE string_agg(u.name, ', ') END::text AS detail
  FROM want_unique w
  JOIN public_rel r ON r.relname = w.tbl
  LEFT JOIN actual_unique u ON u.rel = r.oid AND u.cols = w.cols
  GROUP BY w.tbl, w.shown, w.why
),

check_rls AS (
  SELECT
    'rls'::text AS category,
    w.tbl AS object,
    CASE
      WHEN NOT r.relrowsecurity THEN 'WRONG'
      WHEN (SELECT count(*) FROM pg_policies p
             WHERE p.schemaname = 'public' AND p.tablename = w.tbl) = 0 THEN 'WRONG'
      ELSE 'OK'
    END::text AS status,
    CASE
      WHEN NOT r.relrowsecurity
        THEN 'ROW LEVEL SECURITY IS OFF. The app ships with a publishable key, '
             'so anybody who unpacks the APK can read and rewrite every row in '
             'this table. This is the most serious thing in this report'
      WHEN (SELECT count(*) FROM pg_policies p
             WHERE p.schemaname = 'public' AND p.tablename = w.tbl) = 0
        THEN 'RLS is on and there are no policies, which denies everything to '
             'everybody. Nothing errors: the feature just returns nothing, '
             'forever, and looks like an empty screen rather than a fault'
      ELSE 'on, with '
           || (SELECT count(*) FROM pg_policies p
                WHERE p.schemaname = 'public' AND p.tablename = w.tbl)::text
           || ' policies'
    END::text AS detail
  FROM want_table w
  JOIN public_rel r ON r.relname = w.tbl
),

check_policy AS (
  SELECT
    'policy'::text AS category,
    w.pol AS object,
    CASE WHEN p.policyname IS NULL THEN 'MISSING' ELSE 'OK' END::text AS status,
    CASE WHEN p.policyname IS NULL
         THEN 'absent on ' || w.tbl || '. ' || w.why
         ELSE upper(p.cmd) || ' on ' || w.tbl || ' for ' || array_to_string(p.roles, ', ')
    END::text AS detail
  FROM want_policy w
  JOIN public_rel r ON r.relname = w.tbl
  LEFT JOIN pg_policies p
    ON p.schemaname = 'public' AND p.tablename = w.tbl AND p.policyname = w.pol
),

-- Policies nobody expects. Not automatically a fault — policies are OR'd, so a
-- stray one can only widen access, never narrow it — but a widened public feed
-- is exactly the kind of thing worth seeing before a launch.
check_extra_policy AS (
  SELECT
    'policy'::text AS category,
    (p.policyname || ' (unexpected)') AS object,
    'NOTE'::text AS status,
    ('on ' || p.tablename || ', ' || upper(p.cmd) || ' for '
      || array_to_string(p.roles, ', ')
      || '. Not one of the 28 policies the migrations create. Policies combine '
      || 'with OR, so this can only grant more access than intended, never less'
    )::text AS detail
  FROM pg_policies p
  WHERE p.schemaname = 'public'
    AND p.tablename IN (SELECT tbl FROM want_table)
    AND NOT EXISTS (
      SELECT 1 FROM want_policy w
       WHERE w.tbl = p.tablename AND w.pol = p.policyname
    )
),

check_trigger AS (
  SELECT
    'trigger'::text AS category,
    (w.sch || '.' || w.tbl || ' -> ' || w.trg) AS object,
    CASE
      WHEN t.tgname IS NULL THEN 'MISSING'
      WHEN t.tgenabled = 'D' THEN 'WRONG'
      ELSE 'OK'
    END::text AS status,
    CASE
      WHEN t.tgname IS NULL THEN 'absent. ' || w.why
      WHEN t.tgenabled = 'D'
        THEN 'present but DISABLED, which looks identical to working until it '
             'has to fire. ' || w.why
      ELSE w.why
    END::text AS detail
  FROM want_trigger w
  LEFT JOIN pg_namespace n ON n.nspname = w.sch
  LEFT JOIN pg_class c ON c.relnamespace = n.oid AND c.relname = w.tbl
  LEFT JOIN pg_trigger t
    ON t.tgrelid = c.oid AND t.tgname = w.trg AND NOT t.tgisinternal
),

check_function AS (
  SELECT
    'function'::text AS category,
    ('public.' || w.fn || '()') AS object,
    CASE
      WHEN p.oid IS NULL THEN 'MISSING'
      WHEN NOT p.prosecdef THEN 'WRONG'
      WHEN p.proconfig IS NULL THEN 'NOTE'
      ELSE 'OK'
    END::text AS status,
    CASE
      WHEN p.oid IS NULL THEN 'absent, so its trigger cannot fire. ' || w.why
      WHEN NOT p.prosecdef
        THEN 'exists but is not SECURITY DEFINER, so it runs under the caller''s '
             'own RLS and will silently do nothing. ' || w.why
      WHEN p.proconfig IS NULL
        THEN 'SECURITY DEFINER but its search_path is not pinned. It works, but '
             'a SECURITY DEFINER function without SET search_path = public is a '
             'known escalation shape and Supabase''s own linter flags it'
      ELSE 'SECURITY DEFINER, search_path pinned'
    END::text AS detail
  FROM want_function w
  LEFT JOIN pg_proc p ON p.proname = w.fn
   AND p.pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
),

-- The content_type CHECK. 001 wrote it without 'seerah'; 003 replaced it. If
-- the old one survived, sharing anything from the Seerah section fails with a
-- constraint violation and nothing else in the app does.
--
-- Zero CHECKs is not a fault: with nothing constraining the column, every
-- value including 'seerah' is accepted. It is reported so the absence is
-- visible rather than silently read as success.
check_content_type AS (
  SELECT
    'constraint'::text AS category,
    (w.tbl || '.content_type CHECK') AS object,
    CASE
      WHEN count(con.oid) = 0 THEN 'NOTE'
      WHEN bool_and(pg_get_constraintdef(con.oid) LIKE '%seerah%') THEN 'OK'
      ELSE 'WRONG'
    END::text AS status,
    CASE
      WHEN count(con.oid) = 0
        THEN 'no CHECK on content_type at all, so nothing rejects any value, '
             'including seerah. Harmless for the app'
      WHEN bool_and(pg_get_constraintdef(con.oid) LIKE '%seerah%')
        THEN string_agg(con.conname, ', ') || ' — admits seerah'
      ELSE 'a CHECK here does not admit ''seerah'', so every share from the '
           'Seerah section fails with a constraint violation: '
           || string_agg(con.conname || ' = ' || pg_get_constraintdef(con.oid), '; ')
    END::text AS detail
  FROM (VALUES ('halaqa_shares'::text), ('minbar_shares')) AS w (tbl)
  JOIN public_rel r ON r.relname = w.tbl
  LEFT JOIN pg_constraint con
    ON con.conrelid = r.oid AND con.contype = 'c'
   AND pg_get_constraintdef(con.oid) LIKE '%content_type%'
  GROUP BY w.tbl
),

check_reaction_values AS (
  SELECT
    'constraint'::text AS category,
    (w.tbl || '.reaction CHECK') AS object,
    CASE
      WHEN count(con.oid) = 0 THEN 'NOTE'
      WHEN bool_and(pg_get_constraintdef(con.oid) LIKE '%dua%'
                AND pg_get_constraintdef(con.oid) LIKE '%resonated%'
                AND pg_get_constraintdef(con.oid) LIKE '%moved%') THEN 'OK'
      ELSE 'WRONG'
    END::text AS status,
    CASE
      WHEN count(con.oid) = 0
        THEN 'no CHECK on reaction; any string would be stored'
      WHEN bool_and(pg_get_constraintdef(con.oid) LIKE '%dua%'
                AND pg_get_constraintdef(con.oid) LIKE '%resonated%'
                AND pg_get_constraintdef(con.oid) LIKE '%moved%')
        THEN string_agg(con.conname, ', ') || ' — admits all three reactions'
      ELSE 'a CHECK here does not admit all of dua, resonated and moved, so at '
           'least one of the three reaction buttons fails: '
           || string_agg(con.conname || ' = ' || pg_get_constraintdef(con.oid), '; ')
    END::text AS detail
  FROM (VALUES ('halaqa_reactions'::text), ('minbar_reactions')) AS w (tbl)
  JOIN public_rel r ON r.relname = w.tbl
  LEFT JOIN pg_constraint con
    ON con.conrelid = r.oid AND con.contype = 'c'
   AND pg_get_constraintdef(con.oid) LIKE '%reaction%'
  GROUP BY w.tbl
),

-- Not schema, but the thing most likely to be wrong on launch night, and
-- invisible to every check above: an account that exists in auth.users with no
-- profile row means on_auth_user_created is not firing, and that person's name
-- will be blank everywhere they post.
check_orphan_accounts AS (
  SELECT
    'accounts'::text AS category,
    'auth.users without a profile'::text AS object,
    CASE WHEN count(*) = 0 THEN 'OK' ELSE 'WRONG' END::text AS status,
    CASE WHEN count(*) = 0
         THEN 'every account has a public.users row'
         ELSE count(*)::text || ' account(s) signed up but have no public.users '
              || 'row, so on_auth_user_created is not firing. Their name will be '
              || 'blank on every circle and Minbar post. The repair script '
              || 'backfills them'
    END::text AS detail
  FROM auth.users au
  WHERE NOT EXISTS (SELECT 1 FROM public.users pu WHERE pu.id = au.id)
),

check_orphan_profiles AS (
  SELECT
    'accounts'::text AS category,
    'profiles without an account'::text AS object,
    CASE WHEN count(*) = 0 THEN 'OK' ELSE 'WRONG' END::text AS status,
    CASE WHEN count(*) = 0
         THEN 'every profile belongs to a live account'
         ELSE count(*)::text || ' public.users row(s) reference an account that '
              || 'no longer exists. Their name still appears on old posts. This '
              || 'is what the users.id -> auth.users foreign key prevents'
    END::text AS detail
  FROM public.users pu
  WHERE NOT EXISTS (SELECT 1 FROM auth.users au WHERE au.id = pu.id)
),

check_confirmations AS (
  SELECT
    'accounts'::text AS category,
    'email confirmation'::text AS object,
    'NOTE'::text AS status,
    ((SELECT count(*) FROM auth.users)::text || ' account(s), of which '
      || (SELECT count(*) FROM auth.users WHERE email_confirmed_at IS NULL)::text
      || ' have not confirmed their email. An unconfirmed account cannot log in '
      || 'while confirmation is required, and the app tells them so and offers '
      || 'to resend. If you would rather your friends skip that step, turn off '
      || '"Confirm email" under Authentication -> Providers -> Email'
    )::text AS detail
),

findings AS (
  SELECT category, object, status, detail FROM check_extension
  UNION ALL SELECT category, object, status, detail FROM check_table
  UNION ALL SELECT category, object, status, detail FROM check_column
  UNION ALL SELECT category, object, status, detail FROM check_default
  UNION ALL SELECT category, object, status, detail FROM check_users_id_default
  UNION ALL SELECT category, object, status, detail FROM check_fk
  UNION ALL SELECT category, object, status, detail FROM check_unique
  UNION ALL SELECT category, object, status, detail FROM check_rls
  UNION ALL SELECT category, object, status, detail FROM check_policy
  UNION ALL SELECT category, object, status, detail FROM check_extra_policy
  UNION ALL SELECT category, object, status, detail FROM check_trigger
  UNION ALL SELECT category, object, status, detail FROM check_function
  UNION ALL SELECT category, object, status, detail FROM check_content_type
  UNION ALL SELECT category, object, status, detail FROM check_reaction_values
  UNION ALL SELECT category, object, status, detail FROM check_orphan_accounts
  UNION ALL SELECT category, object, status, detail FROM check_orphan_profiles
  UNION ALL SELECT category, object, status, detail FROM check_confirmations
),

verdict AS (
  SELECT
    'verdict'::text AS category,
    'launch readiness'::text AS object,
    CASE WHEN EXISTS (SELECT 1 FROM findings WHERE status IN ('MISSING', 'WRONG'))
         THEN 'NOT READY' ELSE 'READY' END::text AS status,
    ((SELECT count(*) FROM findings WHERE status = 'MISSING')::text || ' missing, '
      || (SELECT count(*) FROM findings WHERE status = 'WRONG')::text || ' wrong, '
      || (SELECT count(*) FROM findings WHERE status = 'NOTE')::text || ' to note, '
      || (SELECT count(*) FROM findings WHERE status = 'OK')::text || ' fine. '
      || CASE WHEN EXISTS (SELECT 1 FROM findings WHERE status IN ('MISSING', 'WRONG'))
              THEN 'Run 004_repair_idempotent.sql, then run this file again.'
              ELSE 'Nothing below needs doing.' END
    )::text AS detail
)

SELECT category, object, status, detail
FROM (
  SELECT category, object, status, detail FROM verdict
  UNION ALL
  SELECT category, object, status, detail FROM findings
) AS report
ORDER BY
  CASE status
    WHEN 'NOT READY' THEN 0
    WHEN 'READY'     THEN 0
    WHEN 'MISSING'   THEN 1
    WHEN 'WRONG'     THEN 2
    WHEN 'NOTE'      THEN 3
    ELSE 4
  END,
  CASE category
    WHEN 'verdict'     THEN 0
    WHEN 'extension'   THEN 1
    WHEN 'table'       THEN 2
    WHEN 'rls'         THEN 3
    WHEN 'policy'      THEN 4
    WHEN 'accounts'    THEN 5
    WHEN 'column'      THEN 6
    WHEN 'foreign key' THEN 7
    WHEN 'unique'      THEN 8
    WHEN 'default'     THEN 9
    WHEN 'trigger'     THEN 10
    WHEN 'function'    THEN 11
    ELSE 12
  END,
  object;
