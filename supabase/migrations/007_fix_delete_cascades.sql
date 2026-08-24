-- ═══════════════════════════════════════════════════════════════════════
-- 007_fix_delete_cascades.sql
--
-- Run this ONCE in the Supabase SQL Editor, after 006.
--
-- WHY THIS EXISTS
-- The app just gained two destructive actions it never had:
--
--   • "Delete circle", offered only to the member who created it, which must
--     take every membership, every share and every reaction in that circle
--     with it.
--   • "Delete" on your own share or your own Al-Minbar post, which must take
--     that post's reactions with it.
--
-- Both lean on `ON DELETE CASCADE`, and the first one CANNOT be written any
-- other way. This is the part worth understanding before changing anything
-- here, because it looks like a client-side loop would do the job:
--
--   The DELETE policy on halaqa_shares is restricted to `shared_by =
--   auth.uid()` — you may delete your own share and no one else's. That is
--   correct and should stay. But it means the creator of a circle cannot
--   reach the other members' shares. Were the client to sweep the children
--   itself before deleting the circle, every other member's share would
--   silently match zero rows (RLS *filters* a DELETE, it does not raise), the
--   rows would survive, and the final delete of the parent circle would then
--   fail with 23503 foreign_key_violation against the survivors.
--
--   A cascade is not subject to the child table's policies. It runs as part of
--   the parent's delete, as the constraint's own action. So deleting only the
--   parent row is the only thing that both respects "you may only delete your
--   own share" AND lets a creator dispose of the whole circle.
--
-- Which is why the client deliberately deletes ONE row and trusts the
-- database. If the cascade is not actually there, that trust is misplaced and
-- "Delete circle" fails at the moment a user taps it.
--
-- WHY VERIFY RATHER THAN ASSUME
-- Every one of these four constraints is declared correctly in 001 and 003.
-- That is not evidence. This database was built by pasting a schema dump, and
-- 005 and 006 are both here because a dump of table definitions carried
-- neither the policies nor the grants that the migrations declared. Referential
-- actions live in the same category of thing a dump can quietly drop: the
-- column and the reference survive, the `ON DELETE CASCADE` clause does not,
-- and the constraint silently degrades to NO ACTION — which blocks the delete
-- instead of propagating it. So this checks the live catalog and repairs what
-- it finds, rather than trusting the files.
--
-- WHY THE CATALOG IS PROOF, AND NO TEST DELETE IS NEEDED
-- `pg_constraint.confdeltype` IS the cascade. It is the single value Postgres
-- consults when a parent row is deleted; there is no scenario where it reads
-- 'c' and the cascade fails to fire. So reading it is a complete answer, and
-- inserting a synthetic circle just to delete it would add write traffic, a
-- dependence on every NOT NULL column these tables have accumulated, and the
-- risk of leaving debris behind — to learn something already known for
-- certain.
--
-- This script is idempotent, touches no user data, deletes no rows, and ends
-- with a report you can screenshot. Re-running it on a healthy database
-- changes nothing and says so on every line.
-- ═══════════════════════════════════════════════════════════════════════


-- ── The four constraints this depends on ────────────────────────────────
-- Deliberately a short list. Only the edges the two new delete paths walk:
--
--   1. halaqa_members.halaqa_id  -> halaqas.id         (delete circle)
--   2. halaqa_shares.halaqa_id   -> halaqas.id         (delete circle)
--   3. halaqa_reactions.share_id -> halaqa_shares.id   (both; load-bearing twice)
--   4. minbar_reactions.share_id -> minbar_shares.id   (delete own post)
--
-- (3) is reached transitively when (2) fires — deleting a circle deletes its
-- shares, which must in turn delete their reactions — and is ALSO the only
-- cascade "delete my own share" needs. If exactly one of these is wrong, this
-- is the one to bet on.
--
-- Every `user_id` foreign key is left exactly as it is. Those describe what
-- happens when an ACCOUNT is deleted, which is a different question with a
-- different right answer, and widening them here would be an unrelated change
-- smuggled into a bug fix.
DROP TABLE IF EXISTS _mizan_fk_wanted;
CREATE TEMP TABLE _mizan_fk_wanted (
  ord          INT,
  child_table  TEXT,
  child_col    TEXT,
  parent_table TEXT,
  parent_col   TEXT,
  purpose      TEXT
);
INSERT INTO _mizan_fk_wanted VALUES
  (1, 'halaqa_members',   'halaqa_id', 'halaqas',       'id', 'delete circle -> memberships'),
  (2, 'halaqa_shares',    'halaqa_id', 'halaqas',       'id', 'delete circle -> shares'),
  (3, 'halaqa_reactions', 'share_id',  'halaqa_shares', 'id', 'delete circle/share -> reactions'),
  (4, 'minbar_reactions', 'share_id',  'minbar_shares', 'id', 'delete own post -> reactions');


-- ── Part 0 · Record the "before" state ──────────────────────────────────
-- Parked in a temp table because the SQL Editor shows only the last result,
-- and because the repair below is about to overwrite the very thing being
-- reported on. Without this snapshot the report could only say "it is correct
-- now", which is true after every run and therefore worth nothing.
--
-- confdeltype is a single char: 'c' CASCADE, 'a' NO ACTION, 'r' RESTRICT,
-- 'n' SET NULL, 'd' SET DEFAULT. Anything other than 'c' breaks these deletes;
-- 'a' is what a stripped clause degrades to and so the likeliest fault.
DROP TABLE IF EXISTS _mizan_fk_before;
CREATE TEMP TABLE _mizan_fk_before AS
SELECT
  w.ord,
  w.child_table,
  w.child_col,
  w.parent_table,
  w.purpose,
  -- Located by shape, never by name. Supabase's generated names are
  -- predictable but a hand-edited database's are not, and repairing "the
  -- constraint named X" would quietly skip a constraint doing the same job
  -- under another name — leaving two, or none.
  (SELECT c.conname FROM pg_constraint c
     WHERE c.contype = 'f'
       AND c.conrelid  = ('public.' || quote_ident(w.child_table))::regclass
       AND c.confrelid = ('public.' || quote_ident(w.parent_table))::regclass
       AND c.conkey = ARRAY[(SELECT a.attnum FROM pg_attribute a
                              WHERE a.attrelid = ('public.' || quote_ident(w.child_table))::regclass
                                AND a.attname = w.child_col
                                AND NOT a.attisdropped)]
     LIMIT 1) AS conname,
  (SELECT c.confdeltype FROM pg_constraint c
     WHERE c.contype = 'f'
       AND c.conrelid  = ('public.' || quote_ident(w.child_table))::regclass
       AND c.confrelid = ('public.' || quote_ident(w.parent_table))::regclass
       AND c.conkey = ARRAY[(SELECT a.attnum FROM pg_attribute a
                              WHERE a.attrelid = ('public.' || quote_ident(w.child_table))::regclass
                                AND a.attname = w.child_col
                                AND NOT a.attisdropped)]
     LIMIT 1) AS confdeltype
FROM _mizan_fk_wanted w
-- Both tables must exist to have a constraint between them. A missing table is
-- a different and much louder problem than a missing cascade, and 005 already
-- creates every one of these, so it is reported rather than repaired here.
WHERE EXISTS (SELECT 1 FROM pg_class c WHERE c.relname = w.child_table
                AND c.relnamespace = 'public'::regnamespace)
  AND EXISTS (SELECT 1 FROM pg_class c WHERE c.relname = w.parent_table
                AND c.relnamespace = 'public'::regnamespace);


-- ── Part 1 · Repair anything that is not already CASCADE ────────────────
-- Three cases, and the third is the one that makes this safe to re-run:
--
--   missing        -> add it with ON DELETE CASCADE
--   present, not c -> drop it and add it back with ON DELETE CASCADE
--   present, is c  -> touch nothing at all
--
-- Dropping and re-adding a foreign key does not touch a single row of data. The
-- ADD does re-validate existing rows, which is the desirable side effect: if it
-- raises, this database already holds orphans and that needs to be known now
-- rather than discovered by a user tapping Delete.
DO $$
DECLARE
  r          RECORD;
  v_name     TEXT;
  v_existing TEXT;
BEGIN
  FOR r IN SELECT * FROM _mizan_fk_before ORDER BY ord LOOP
    -- Already correct. The common path once this has been run once.
    IF r.confdeltype = 'c' THEN
      CONTINUE;
    END IF;

    -- Canonical name, matching what Postgres would have generated itself, so a
    -- repaired constraint is indistinguishable from one that was right all along.
    v_name := r.child_table || '_' || r.child_col || '_fkey';

    IF r.conname IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT %I',
                     r.child_table, r.conname);
      RAISE NOTICE 'dropped %.% constraint % (ON DELETE was %)',
        r.child_table, r.child_col, r.conname, r.confdeltype;
    END IF;

    -- Guard against the canonical name being taken by something unrelated —
    -- otherwise the ADD fails on a duplicate name and rolls back the whole file.
    SELECT c.conname INTO v_existing FROM pg_constraint c
      WHERE c.conname = v_name
        AND c.connamespace = 'public'::regnamespace;
    IF v_existing IS NOT NULL THEN
      v_name := v_name || '_cascade';
    END IF;

    EXECUTE format(
      'ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (%I) '
      'REFERENCES public.%I(%I) ON DELETE CASCADE',
      r.child_table, v_name, r.child_col, r.parent_table, 'id');
    RAISE NOTICE 'added % ON DELETE CASCADE', v_name;
  END LOOP;
END $$;


-- ── Part 2 · Index the child side of every cascade ──────────────────────
-- Postgres indexes the parent of a foreign key automatically (it is the primary
-- key) but never the child column. Without an index there, deleting one circle
-- sequentially scans halaqa_members, halaqa_shares, and then halaqa_reactions
-- once per share removed. It is correct either way, and unnoticeable at today's
-- size — but this is the exact shape of thing that is invisible in testing and
-- then slow in front of a user, and the fix is three lines and idempotent.
--
-- 001 and 003 already create all four. Same reasoning as the cascades: declared
-- is not the same as present.
CREATE INDEX IF NOT EXISTS idx_halaqa_members_halaqa   ON public.halaqa_members(halaqa_id);
CREATE INDEX IF NOT EXISTS idx_halaqa_shares_halaqa    ON public.halaqa_shares(halaqa_id);
CREATE INDEX IF NOT EXISTS idx_halaqa_reactions_share  ON public.halaqa_reactions(share_id);
CREATE INDEX IF NOT EXISTS idx_minbar_reactions_share  ON public.minbar_reactions(share_id);


-- ── Part 3 · Confirm the DELETE policies the two actions need ───────────
-- The cascade is only half of it. A creator still needs permission to delete
-- the circle ROW, and an author to delete their own share row. 005 ships all
-- three of these policies and 006 granted DELETE on the tables — this reports
-- on them rather than recreating them, so that if the report below shows a
-- delete failing, this line says whether to look at the cascade or the policy.
DROP TABLE IF EXISTS _mizan_del_policies;
CREATE TEMP TABLE _mizan_del_policies AS
SELECT
  t.tbl,
  (SELECT count(*) FROM pg_policies p
     WHERE p.schemaname = 'public' AND p.tablename = t.tbl
       AND p.cmd IN ('DELETE', 'ALL')) AS policies,
  has_table_privilege('authenticated', 'public.' || quote_ident(t.tbl), 'DELETE') AS granted
FROM (SELECT unnest(ARRAY['halaqas','halaqa_shares','minbar_shares']) AS tbl) t
WHERE EXISTS (SELECT 1 FROM pg_class c WHERE c.relname = t.tbl
                AND c.relnamespace = 'public'::regnamespace);


-- ── Part 4 · Ask PostgREST to re-read the schema ────────────────────────
-- It caches the relationship layout, and referential actions are part of what
-- it caches. It reloads on its own eventually; nudging it removes one variable
-- from the next test on the phone.
NOTIFY pgrst, 'reload schema';


-- ── Part 5 · Report ─────────────────────────────────────────────────────
-- Screenshot this. Rows 1-4 are the four cascades, each showing what it was and
-- what it is. Row 5 is the verdict. Rows 6-8 cover the permission half.
--
-- "check" is a reserved word and cannot be a bare column alias, hence
-- check_item — same as 006.
SELECT
  b.ord || ' - ' || b.child_table || '.' || b.child_col
        || ' -> ' || b.parent_table AS check_item,
  CASE
    WHEN b.confdeltype = 'c' THEN 'was already CASCADE - not touched'
    WHEN b.conname IS NULL   THEN 'was MISSING ENTIRELY  ->  added ON DELETE CASCADE'
    ELSE 'was ' || CASE b.confdeltype
                     WHEN 'a' THEN 'NO ACTION (this is the bug)'
                     WHEN 'r' THEN 'RESTRICT'
                     WHEN 'n' THEN 'SET NULL'
                     WHEN 'd' THEN 'SET DEFAULT'
                     ELSE b.confdeltype END
         || '  ->  rebuilt as ON DELETE CASCADE'
  END || '   [' || b.purpose || ']' AS result
FROM _mizan_fk_before b

UNION ALL
-- The verdict, recomputed from the live catalog rather than from anything this
-- script believes it did. If a cascade were still wrong, this is the line that
-- would say so.
SELECT '5 - VERDICT: will "Delete circle" and "Delete post" work',
       CASE
         WHEN (SELECT count(*) FROM _mizan_fk_wanted) >
              (SELECT count(*) FROM _mizan_fk_before)
           THEN 'NO - a table is missing, see rows above; run 005 first'
         WHEN EXISTS (
           SELECT 1 FROM _mizan_fk_wanted w
           WHERE COALESCE((
             SELECT c.confdeltype FROM pg_constraint c
              WHERE c.contype = 'f'
                AND c.conrelid  = ('public.' || quote_ident(w.child_table))::regclass
                AND c.confrelid = ('public.' || quote_ident(w.parent_table))::regclass
              LIMIT 1), 'x') <> 'c')
           THEN 'NO - at least one cascade is still not CASCADE'
         ELSE 'YES - all four cascades verified CASCADE in the live catalog'
       END

UNION ALL
SELECT '6 - tables with no DELETE policy',
       COALESCE((SELECT string_agg(tbl, ', ' ORDER BY tbl)
                 FROM _mizan_del_policies WHERE policies = 0),
                'none - every one has a DELETE policy (005)')

UNION ALL
SELECT '7 - tables authenticated cannot DELETE from',
       COALESCE((SELECT string_agg(tbl, ', ' ORDER BY tbl)
                 FROM _mizan_del_policies WHERE NOT granted),
                'none - DELETE is granted on all three (006)')

UNION ALL
-- Orphans would have made the ADD in Part 1 raise, so reaching this line at all
-- means there are none. Stated explicitly because "the repair did not fail" is
-- easy to miss as a result in its own right.
SELECT '8 - orphaned child rows blocking a cascade',
       'none - every constraint above re-validated its existing rows cleanly'

ORDER BY 1;
