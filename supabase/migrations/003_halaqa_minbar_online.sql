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
