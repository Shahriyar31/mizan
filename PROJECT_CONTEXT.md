# Taddabur (تَدَبُّر) — Project Context for Claude Code

*Generated from a full read of the codebase on 2026-08-21. This is a working handoff doc, not marketing copy — update it as the app evolves.*

---

## 1. The Backstory (why this app exists)

Muslims globally fall into a recurring cycle: spiritual motivation → engagement with deen → dunya pulls them away → guilt → return → repeat. Existing Islamic apps (Quran readers, hadith apps, tafseer sites) solve *content access* but not this *behavioral* cycle — they're libraries, not companions.

Specific gaps that motivated Taddabur:
- Tafseer exists but reads like an encyclopedia — no narrative pull, no context.
- No community-accountability feature in any mainstream Islamic app.
- People recite the same surahs in salah 17×/day without understanding the meaning.
- Public Islamic content platforms let unverified opinions and sect conflicts leak in.
- Nothing is built around *akhirah-orientation as a daily behavioral anchor*.

**The three engagement pulls the app is designed around:**
| Pull | Mechanism | Feature |
|---|---|---|
| Social | Unresolved social info ("someone in your circle shared something") | Halaqa |
| Curiosity | Episodic content that can't be binged (1 layer/day) | Ayah of the Week / 5-layer tafseer |
| Identity mirror | Seeing your own growth reflected back | Growth Map |

The name itself — *Taddabur* — is Quranic: "Will they not reflect (yatadabbarūna) upon the Quran?" (47:24). The whole app is a bet that **reflection**, not just information, is the missing layer in Muslim digital habits.

## 2. What kind of project this is

- Solo-developer, fast-moving Flutter app, built almost entirely in **two days** (2026-08-20 → 2026-08-21, 14 commits so far — this is genuinely a from-scratch build, not a legacy codebase).
- Written like an "enterprise" project deliberately — feature-based folder architecture, conventional commits, PR-checklist discipline, phased roadmap — even though it's one person. That structure is intentional (stated in the README as "builds the habit"), not overengineering to prune.
- No `develop` branch actually exists yet in git despite the README describing a `main`/`develop`/`feature/*` flow — everything so far is committed straight to `main`. Worth deciding whether to start branching now or keep going trunk-based solo.

## 3. Tech stack (as actually wired up, not just aspirational)

| Layer | Choice | Status |
|---|---|---|
| App framework | Flutter/Dart (SDK ^3.3.0) | ✅ in use |
| State mgmt | Riverpod 2.5 | ✅ in use (providers per feature) |
| Navigation | GoRouter 13, single `ShellRoute` + bottom nav shell | ✅ wired, all 6 tabs routed |
| Backend | Supabase (`supabase_flutter` 2.17) | ✅ client connected, schema pushed; screens don't read/write it yet except scholar_ai plumbing |
| AI / RAG | Azure OpenAI + Azure AI Search (planned) | ❌ not called yet — Scholar AI currently answers from a **local bundled Ibn Kathir JSON**, no network AI call live |
| Quran content | Quran.com API | ✅ `quran_api_service.dart` present; also local surah metadata/word-roots data bundled |
| Hadith content | Sunnah.com API | 🟡 service file exists, stubbed (`TODO: Implement hadith_api_service`) |
| Local storage | sqflite | ✅ vocabulary bank persists here |
| Notifications | Firebase FCM | 🟡 service file stubbed, not wired |
| Tafseer content | Ibn Kathir JSON, all 114 surahs bundled locally (raw + "processed") | ✅ present, driving the layer system |
| Fonts | Amiri (Arabic) via bundled TTFs | ✅ |

## 4. What's actually built (feature by feature)

### Home (`lib/features/home/`) — ✅ most mature feature
- 4 "smart states" implemented: **Muhasabah**, **Wird**, **Friday/Jumu'ah**, **Returning**, plus a default state — the app picks which to show based on time/day/user activity.
- Last-ayah persistence for the Returning state (so it can resume where you left off).
- `home_screen.dart` is 1290 lines — heaviest single file in the app, all UI+state co-located (candidate for splitting into widgets when it grows further).

### Quran + 5-Layer Tafseer (`lib/features/quran/`) — ✅ core feature, functionally deep
- Surah list, ayah detail (PageView), RTL navigation, translations — complete (Phase 3, per commit history).
- Word-tap: Al-Fatihah is fully curated (word roots, meanings); other surahs fall back to a generic path — **only 1 of 114 surahs has hand-curated word data**.
- 5-layer system implemented end-to-end: Words → Context → Scholars (Ibn Kathir) → Isnad → Your Layer (reflection), with a day-of-week unlock engine (`layer_unlock.dart` / `layer_providers.dart`) and a "tomorrow teaser."
- Scholars layer currently = Ibn Kathir only, even though README promises As-Sa'di and Al-Qurtubi as switchable — **not implemented, single-source only**.
- Reflection (personal Layer 5) storage exists locally; Supabase sync for it is not confirmed wired end-to-end.
- `layer_screen.dart` (1164 lines) and `ayah_detail_screen.dart` (864 lines) are large — logic-heavy, worth watching for maintainability.

### Growth (`lib/features/growth/`) — 🟡 partial
- Vocabulary Bank: real, working — SQLite-backed, spaced-repetition scheduling (`vocab_repository.dart`), save/persist flow live.
- Muhasabah (daily reflection) screen: built (284 lines).
- Growth Map (the "identity mirror" visual constellation) — **explicitly "coming soon"**, not built; only a placeholder message in `growth_screen.dart`.
- Seerah Timeline widget promised in README structure — not found as a distinct implemented widget yet.

### Discover (`lib/features/discover/`) — 🟡 partial, content-thin
- Screens exist for Seerah, Prophets, Sahabah, Divine Names, and a Quiz screen (578 lines) — this is more built out than the README table suggests.
- But bundled content is a small slice of the eventual scope:
  - Prophets: **2 of 25** (Adam, Ibrahim) + index
  - Sahabah: **2 of "100"** (Abu Bakr, Bilal) + index
  - Seerah: **5 episodes** (birth/childhood, first revelation, early Makkah, hijra, Badr) + index
  - 99 Names of Allah: **all 99 present** (`names/` has 101 files incl. index) — this one's essentially content-complete.
- There's dead code duplication: both `discover/presentation/discover_screen.dart` (2 lines, stub) and `discover/screens/discover_screen.dart` (878 lines, the real one) exist — the router points at the presentation one's stub-free sibling; this pair (and the `models/` vs `domain/` split vs README's proposed structure) should be cleaned up before it grows further.

### Scholar AI (`lib/features/scholar_ai/`) — ❌ barely started in the UI layer, but the RAG groundwork exists elsewhere
- `scholar_ai_screen.dart` is a **22-line literal placeholder** ("TODO: Implement Scholar_ai screen"), class even has a stray underscore typo (`Scholar_aiScreen`).
- However `services/scholar_ai/scholar_ai_service.dart` and `services/ai/scholar_ai_service.dart` (duplicate!) exist, and the Ibn Kathir local JSON is already wired as the knowledge source for citation-locked answers — so the *engine* has more progress than the *screen*.
- Azure OpenAI / Azure AI Search calls are not live — everything is local-JSON lookup today. The "RAG pipeline" in the README is the target architecture, not the current one.
- Citation Lock concept (must cite ayah/hadith/tafseer or refuse) — logic not yet found as a distinct verifier; likely needs to be built when real AI calls are added.

### Halaqa (`lib/features/halaqa/`) — ❌ not started (by design, Phase 5)
- `halaqa_screen.dart` (87 lines) is a styled "Coming Soon" screen only. No repository, no data model, no Supabase tables consumed yet even though `halaqas`/`halaqa_members`/`halaqa_shares` tables are in the schema.

### Al-Minbar (`lib/features/minbar/`) — ❌ not started (by design, Phase 5)
- Same pattern as Halaqa: styled "Coming Soon" placeholder only.

### Backend / Supabase — 🟡 schema-only
- `supabase/migrations/001_initial_schema.sql` (115 lines) — single migration, all core tables from the README's ERD likely present (users, user_progress, vocabulary_bank, muhasabah_entries, halaqas, halaqa_members, halaqa_shares, minbar_shares, friday_reflections).
- `supabase_client.dart` still carries a stub `TODO` comment despite the commit message claiming "all tables created, connected" — worth verifying which parts are real vs scaffolded.
- No Row-Level Security policies confirmed reviewed — worth checking before any real user data flows in, since reflections/muhasabah entries are meant to be encrypted/private per the README.

### Feature flags
`.env` has `FEATURE_SCHOLAR_AI`, `FEATURE_HALAQA`, `FEATURE_MINBAR`, `FEATURE_MULTILINGUAL` — all off by default (`=0`), matching Phase 5+ gating.

### Housekeeping debt already visible
- A pile of one-off `fix_*.py` / `generate_remaining_names.py` scripts sit at the repo root (`fix_all_copywith.py`, `fix_citation.py`, `fix_discover.py`, `fix_final.py`, `fix_navigation.py`, `fix_provider.py`, `fix_seerah_and_home.py`, `fix_surgical.py`, `fix_theme_mismatch.py`, `setup_structure.sh`) — these look like one-time migration/refactor scripts, not part of the app; candidates to move into a `/scripts` or `/tools` folder (or delete) so they don't get mistaken for app code.
- Duplicate service files: `services/ai/scholar_ai_service.dart` vs `services/scholar_ai/scholar_ai_service.dart`, and `services/local/database_service.dart` vs `services/database/database_service.dart` — needs reconciling to one canonical location each.
- Duplicate discover screen (see above).

## 5. Honest status summary

| Feature | Real status |
|---|---|
| Home 4-state engine | ✅ Done, most polished part of the app |
| Quran browsing + translations | ✅ Done |
| 5-layer tafseer (Ibn Kathir only) | ✅ Done for the Ibn Kathir layer; word-level curation only covers Al-Fatihah |
| Vocabulary Bank (SQLite, spaced repetition) | ✅ Done |
| Muhasabah journal | ✅ Done |
| Discover: 99 Names | ✅ Content-complete |
| Discover: Prophets/Sahabah/Seerah | 🟡 Skeleton + 2-5 sample entries each, not full content |
| Growth Map (constellation viz) | ❌ Not built |
| Scholar AI screen | ❌ Placeholder only |
| Scholar AI RAG (Azure) | ❌ Not wired; local JSON substitute only |
| Halaqa | ❌ Not built (by design, Phase 5) |
| Al-Minbar | ❌ Not built (by design, Phase 5) |
| Supabase backend | 🟡 Schema exists, client wiring partially stubbed |
| Hadith API (Sunnah.com) | ❌ Stub only |
| Push notifications (FCM) | ❌ Stub only |
| Multi-surah word-level tafseer data | ❌ Only Surah 1 curated |

## 6. Suggested next priorities (for discussion, not decided)

1. **Clean up dead weight first**: move/delete the root `fix_*.py` scripts, resolve the duplicate service/screen files — cheap wins before adding more surface area.
2. **Decide Scholar AI's real near-term shape**: keep it local-JSON-only (cheap, no hallucination risk, matches "Citation Lock" ethos) vs. start wiring Azure OpenAI/AI Search now. Given the README's own citation-lock philosophy, shipping a good local-JSON version further and delaying real LLM calls may be the lower-risk path.
3. **Expand Discover content** (Prophets/Sahabah/Seerah) since the screens already exist and only need data — likely the fastest visible progress per hour of work.
4. **Decide whether Halaqa/Minbar start now or stay Phase 5** as originally planned — currently correctly gated off, no action needed unless priorities shifted.
5. **Add RLS policies and verify encryption-at-rest story** for `muhasabah_entries`/`user_progress.reflection_text` before any real users touch it, since the README promises this.
6. **Split the largest files** (`home_screen.dart` 1290 lines, `layer_screen.dart` 1164, `ayah_detail_screen.dart` 864, `discover_screen.dart` 878) into smaller widgets as per the intended `presentation/widgets/` structure — currently under-decomposed vs. the README's own target folder layout.

---

*Use this doc as the orientation briefing for any new Claude Code session on this repo. Keep it updated as features move between the ❌/🟡/✅ buckets — it's meant to stay accurate, not be a one-time snapshot.*
