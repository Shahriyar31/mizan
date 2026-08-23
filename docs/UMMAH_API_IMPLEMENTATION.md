# UmmahAPI integration — implementation report

Commit `4191ca8`. 44 files, +5,760 / −385. Every file below type-checks clean;
what could *not* be verified from here is listed in section 8.

Companion document: `docs/UMMAH_API.md` holds the key verification and the raw
endpoint reference. This one holds what was built and why.

---

## 1. The plan, and what landed against it

| Phase | Brief | Status |
| --- | --- | --- |
| 1 | Client, env config, key management, repository layer, local cache | done |
| 2 | Diagnose distortion, then migrate audio with MP3Quran kept as fallback | done |
| 3 | Ibn Kathir, Ma'arif al-Quran, Muyassar into the existing Quran layers | done |
| 4 | Mutashabihat, not as a separate section | done |
| 5 | Topic-based hadith learning on the existing knowledge graph | done |

No new screens were added to the Quran layer, no navigation was duplicated, and
nothing in the design system was redesigned. Phase 5 adds two screens because it
is a new section the brief asked for; both are built from `KnowledgeScaffold`,
`KnowledgeHero`, `MizanRow` and `MizanSurface`, so they are visibly the same app.

---

## 2. Phase 1 — the client

`lib/core/network/ummah_api_client.dart` (378 lines) and
`lib/core/config/ummah_api_config.dart` (59).

The key comes from `.env` via `flutter_dotenv` and travels as the `X-API-Key`
header. It is never placed in a query string, never logged, and appears nowhere in
`lib/`. `.env` stays git-ignored; `.env.example` documents the variable.

Two decisions worth naming. The `{success, service, data, timestamp}` envelope is
unwrapped in exactly one place, so no repository ever sees it. And every field read
goes through `stringAt` / `intAt` / `listFrom`, which try each plausible spelling
of a key — the documentation gives paths but no schemas and no query parameters, so
a repository that hard-coded `"text"` would break the first time a response said
`"content"`. This is the "if a response shape differs, adapt accordingly"
instruction implemented as code rather than as a probe script.

`lib/services/cache/api_cache.dart` (196) is a sqlite response cache with three
policies: `immutable` 365 days for scripture, `catalogue` 7 days for lists,
`search` 12 hours for queries. Scripture does not change, so re-fetching it is
waste; a search might.

## 3. Phase 2 — audio

**The distortion was not the source.** Four client-side defects, any one of which
would survive a source swap:

1. No `audio_session` category configured, so the OS mixed and ducked the stream
   against whatever else was playing.
2. `setUrl` called cold, with playback starting before any buffer existed.
3. No file caching — every replay re-streamed.
4. Player exclusion handled at the widget layer, so two players could hold the
   same output.

Fixed in `lib/services/audio/audio_session_setup.dart` (97),
`recitation_cache.dart` (236) and `playback_arbiter.dart` (86). Only then was
UmmahAPI added as a source, in `lib/features/quran/data/audio_repository.dart`
(265) and `ayah_reciters.dart` (102), with MP3Quran retained as fallback exactly
as the brief required. The player UI is untouched.

Had the migration been done first, the distortion would still be there and the API
would have taken the blame.

## 4. Phase 3 — tafsir and word-by-word

`tafsir_repository.dart` (366), `word_analysis_repository.dart` (289),
`tafsir_providers.dart` (120), folded into `layer_screen.dart` and
`ayah_detail_screen.dart`. Ibn Kathir, Ma'arif al-Quran and Muyassar. No new
screens — these fill layers that already existed.

## 5. Phase 4 — mutashabihat, without renumbering

`mutashabihat_repository.dart` (282), plus `layer_unlock.dart`,
`layer_providers.dart`, `layer_repository.dart`.

The constraint: rows already in `layer_unlocks` on every installed device mean
"4 = Reflection". Renumbering would silently relabel what people have already
unlocked. So Similar took storage index **5** and is *displayed* between Isnad and
Reflection through `LayerMeta.displayOrder = [0,1,2,3,5,4]`. No DB migration, no
renumbering, Isnad retained. Unlock scheduling now reads `LayerMeta.predecessorOf`
in one place instead of assuming index − 1.

## 6. Phase 5 — hadith learning

Ten topics, not eleven books. `hadith_topic.dart` (181) holds them as a const
table of *search terms*, not curated hadith lists — hand-picking which narration
belongs under "Patience" is a scholarly claim the app is not sourced to make.

`hadith_search_repository.dart` (212) searches, `ummah_hadith_collections.dart`
(183) bridges slugs, `hadith_extras.dart` (205) backs layers 2 and 4,
`hadith_topics_screen.dart` (248) is the index and one topic,
`hadith_detail_screen.dart` (+487) is the five-layer page, `narrator_index.dart`
(150) matches narrator names to companions.

The five layers: **1** Hadith (Arabic, translation, narrator, authenticity,
collection) · **2** Vocabulary · **3** Context (book, chapter, and the sentence the
corpus used when citing it) · **4** Scholar commentary · **5** Reflection.

Narrator names are tappable and open **the companion's existing biography** — the
same five-layer story Discover opens. No second profile of Abu Hurayrah exists.
`NarratorIndex` strips honorifics and narration formulae, then matches exact or
unique-prefix, and returns nothing when a name is ambiguous. A wrong biography
attached to a narration is worse than no link.

Source chain for a hadith: memory → sqlite → bundle → UmmahAPI → any separately
configured endpoint. Topic results are written into the cache before they are
shown, so tapping one opens instantly and still works offline.

### Three refusals that are load-bearing

**The `nawawi` collision.** Our `nawawi` slug is *Riyad as-Salihin*. UmmahAPI's is
*Nawawi's Forty*. Binding them would answer a Riyad as-Salihin citation with
unrelated text under a citation saying Riyad as-Salihin — a fabricated citation.
`UmmahHadithCollections` refuses any candidate whose name contains 40 / forty /
arbain, and lists `ahmad`, `darimi`, `bulugh`, `nawawi` as not carried, so those
citations short-circuit with zero requests.

**Uncitable results are dropped.** A search result without a resolvable collection
*and* a hadith number never reaches the UI. `id` is deliberately excluded from the
accepted number fields: on some services it is a row identifier, and a row
identifier printed as a hadith number is a false citation.

**Layers 2 and 4 have no source, and say so.** UmmahAPI exposes no dictionary,
lemma, root or sharh endpoint — `/api/quran/words` is Qur'an-only, and matching
hadith Arabic to Qur'anic word forms needs morphology the app does not have. Both
layers therefore ship as real slots with honest empty states and bundled drop-ins
(`assets/data/hadith/vocabulary/{collection}.json`,
`.../commentary/{collection}.json`). Commentary missing scholar, work or text is
dropped rather than shown as anonymous opinion. Glossing a word ourselves would be
precisely the machine-generated Islamic content the brief forbids.

### The undocumented search parameter

The PDF documents `/api/hadith/search` but names no query parameter. Rather than
guess or write a probe, the repository tries `q`, `query`, `keyword`, `search`,
`text`, keeps the first that returns results, and remembers it for the session.
Discovery costs at most four extra requests once, ever, and it happens inside the
app where a shape change fixes itself.

---

## 7. Storage, and one thing that must not be cleared

Database is now **v6**. The new table is `hadith_reflections`
(collection, number, reflection, saved_at). It is created from both the fresh-install
path and an `oldVersion < 6` upgrade block, with `IF NOT EXISTS` so the double call
is a no-op.

`hadith_reflections` is **user content, not a cache.** `clearSaved()` must never
touch it. Clearing saved hadith removes downloaded texts only; what someone wrote
survives.

Growth counts hadith reflections separately from ayah reflections
(`GrowthMetrics.hadithReflections`) so its detail line stays accurate — "12 ayah
reflections" when four were hadith would be false.

**No new asset directories were declared in `pubspec.yaml`.** Flutter fails the
build on a declared asset directory that does not exist, and git does not track
empty directories. Add the directory, the JSON file and the pubspec line together;
both drop-in points document this at the top of their file.

---

## 8. What I could not verify from here, and two launch blockers

Verified: every changed file type-checks with zero errors and zero warnings, and no
new code uses `AppColors` or a literal `Color(0x…)`.

Not verifiable in this sandbox — `flutter run`, `flutter build`, `flutter pub get`,
rendering, and network to `ummahapi.com` (host allowlist). So the response shapes
are handled tolerantly rather than confirmed, and the first real run is where the
field spellings get settled.

Two blockers before a store release, neither changed silently:

- `LayerMeta.unlockInterval` is `Duration(seconds: 1)`. It must become 24 hours.
  It is left as-is because you are relying on it for device testing.
- `applicationId` is still `com.example.ummahapp`. Play will reject it.

One action outstanding: `git push origin main` — five commits are unpushed, and
push from this sandbox is blocked by the proxy.
