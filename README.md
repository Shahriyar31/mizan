# مِيزان · Mizan

A Flutter app for reading the Qur'an slowly.

Most Qur'an apps are built for retrieval: open, find the verse, close. Mizan is
built for the opposite — one ayah at a time, in six layers, opened over days
rather than minutes, with a small circle of people who can see what you are
reading and respond without talking over it.

Every scholarly statement in the app carries its source. Nothing is generated,
nothing is paraphrased into an authority it does not have, and where a source is
missing the app says so rather than filling the gap.

> **Status: pre-launch.** `version: 0.1.0+1`. This is a working build being
> handed to a small group of friends, not a store release. The
> [Known limitations](#known-limitations) section is honest and complete — read
> it before you install anything.

---

## Contents

- [The name](#the-name)
- [What the app does](#what-the-app-does)
- [The six layers](#the-six-layers)
- [Citation Lock](#citation-lock)
- [Halaqa — private circles](#halaqa--private-circles)
- [Al-Minbar — the public feed](#al-minbar--the-public-feed)
- [The knowledge graph](#the-knowledge-graph)
- [The corpus, counted](#the-corpus-counted)
- [Data sources](#data-sources)
- [The Mizan design system](#the-mizan-design-system)
- [Architecture](#architecture)
- [Local database](#local-database)
- [Supabase](#supabase)
- [Environment and secrets](#environment-and-secrets)
- [Running it](#running-it)
- [Verifying changes](#verifying-changes)
- [Building an APK](#building-an-apk)
- [Known limitations](#known-limitations)
- [Repository layout](#repository-layout)
- [Author](#author)

---

## The name

**Mizan** — ميزان, "the scale" — is the only name in this project. Product name,
Dart package, database file, Android application id, window title, wordmark: all
one word.

It did not start that way. Two earlier names, `ummahapp` and `taddabur`, had
spread across the pubspec, every import, the SQLite filenames, the notification
channel and the build identifiers. They are gone. Three places keep a deliberate
trace, and each one is load-bearing:

| Where | What it says | Why it must stay |
| --- | --- | --- |
| `DatabaseService._legacyDbName` | `taddabur.db` | Renaming the file would have hidden every existing install's saved words, reflections and unlocked layers. The old file is moved to `mizan.db` on first open instead. |
| `DiscoverDatabase._legacyDbName` | `taddabur_discover_v2.db` | Same, for Discover reading progress. |
| `NotificationService._legacyChannelId` | `taddabur_daily` | Android keeps a channel registered forever once created. This one is deleted on launch so the user does not see two identical "Daily reminders" entries in system settings. |

One more, unrelated to branding:
`assets/data/discover/seerah/first_revelation.json` uses the word *taddabur* in
its content, meaning deep reflection. That is Arabic vocabulary in a sourced
narration, not a leftover, and it stays.

The **repository directory and its GitHub URL are still `ummahapp`** — that is a
rename only the account owner can perform, in the repo's GitHub settings. GitHub
redirects the old URL afterwards, so nothing breaks; the local remote then needs
`git remote set-url`.

---

## What the app does

Twelve feature areas live under `lib/features/`. File counts give a fair sense
of weight:

| Area | Files | What it is |
| --- | --- | --- |
| `quran` | 21 | The reader: surah index, ayah view, the six layers, audio, translation picker |
| `knowledge` | 18 | The graph — entities, relationships, evidence mode, hadith topics |
| `settings` | 17 | Account, theme, app icon, translation, audio, notifications, language, About |
| `discover` | 14 | Prophets, companions, the Divine Names, the seerah timeline |
| `growth` | 12 | Growth map, Al-Meezan, vocabulary bank, muhasabah |
| `halaqa` | 11 | Private circles — create, join, share, react, nudge |
| `home` | 8 | Today's thread and where you left off |
| `minbar` | 7 | The public feed |
| `onboarding` | 3 | Welcome and first run |
| `identity` | 2 | Who the current user is, signed in or not |
| `sharing` | 1 | The share sheet that targets a circle or the feed |
| `scholar_ai` | 1 | A placeholder. Ships **locked** — see limitations |

Roughly 46,000 lines of Dart across 192 files. Navigation is a single GoRouter
`ShellRoute` with **five** bottom tabs — Home, Quran, Discover, Halaqa, Minbar —
and every other destination is a child route of one of them. Growth and Settings
are deliberately *not* tabs: the design reaches them from Today's Mizan on the
Home header, which keeps the bar to five items and one entry point per
destination. There is no second navigation stack anywhere in the app.

---

## The six layers

The centre of the app. An ayah is not a paragraph to be read once; it is opened
in six passes, and the next pass is not available immediately.

| Shown | Name | Icon | ~Minutes | Storage index |
| --- | --- | --- | --- | --- |
| 1st | **Words** | translate | 3 | 0 |
| 2nd | **Context** | place | 2 | 1 |
| 3rd | **Scholars** | auto_stories | 4 | 2 |
| 4th | **Isnad** | link | 2 | 3 |
| 5th | **Similar** | compare_arrows | 2 | **5** |
| 6th | **Reflection** | edit_note | 3 | **4** |

Two details in that table are deliberate and easy to get wrong:

**Display order is not storage order.** `LayerMeta.displayOrder` is
`[0, 1, 2, 3, 5, 4]`. *Similar* (mutashabihat) was added last, so it took the
next free storage index — 5 — even though it is shown before *Reflection*. Giving
it index 4 and pushing Reflection to 5 would have silently reinterpreted every
`layer_unlocks` row already saved on every device: a row reading "layer 4 opened"
would change meaning from Reflection to Similar. Order-on-screen and
order-in-storage are kept as separate concerns, and `displayOrder` is the only
place the difference is allowed to live.

**Reflection stays last on screen** because it is the layer that gates moving on
to the next ayah. A browsing layer placed after it would invite leaving the ayah
without reflecting.

Unlocking follows the layer the reader *actually saw last*, not whichever index
happens to be one lower — `LayerMeta.predecessorOf` walks `displayOrder` for
exactly this reason. Timestamps go into `layer_unlocks`, one row per
`(surah, ayah, layer)`.

The `readMinutes` estimates are estimates. Nothing in the app times a reader.
They exist so the layers sheet can say "about 9 min left" instead of offering six
destinations with no sense of the cost of any of them, and they are always spoken
with a hedge.

> ⚠️ `LayerMeta.unlockInterval` is currently `Duration(seconds: 1)`. It must be
> `Duration(hours: 24)` for release. See [Known limitations](#known-limitations).

---

## Citation Lock

The rule the whole app is built around:

> Every scholarly claim must cite a Qur'an ayah, a hadith with book + number +
> grade, or a named tafseer — or the app refuses to make the claim.

Consequences that show up throughout the codebase:

- **No machine translation.** Translations are shipped or fetched from a named
  source, never generated.
- **No invented Islamic content.** Not by a model, not by a helpful fallback
  string, not by interpolation between two sourced facts.
- **Absence is stated, not hidden.** `scholars.json` has `biography: null` for
  all twelve entries because verified text has not been supplied; the pages are
  not empty in the meantime, because each one shows the verses and topics derived
  from every layer that cites that scholar. Where a description exists,
  `description_source` says exactly what it is so it can never be mistaken for a
  sourced claim.
- **Derived is labelled derived.** Theme membership is counted from corpus text,
  not asserted. Nothing in the data files decides on the reader's behalf which
  prophet is "about patience" — the prose does, and the edge points at the layer
  where the discussion actually is.

---

## Halaqa — private circles

A Halaqa is a small private circle, and the constraints are the feature:

- **2–8 members.** `AppConstants.minHalaqaMembers` / `maxHalaqaMembers`. Enforced
  locally and, online, by a `SECURITY DEFINER` trigger that raises `halaqa_full`.
- **Joined by invite code.** Six characters drawn from
  `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` — the full alphabet minus `I` and `O`, and
  digits `2`–`9`, so nothing in a code can be misread as something else. Eight
  characters after four collisions, ten as a final fallback. The code is the
  access secret; row visibility is not the mechanism.
- **One optional note per share, ≤100 characters.** Hard-capped on write.
- **Three reactions: Du'a, Resonated, Moved.** Stored as `dua`, `resonated`,
  `moved`.
- **No text replies. Ever.** There is no reply field, no thread, no draft state,
  nowhere for one to be added without changing what a Halaqa is. A circle is for
  reading alongside people, not for discussing them.
- **The nudge alerts a circle member, not the person who drifted.** After
  `daysBeforeNudge` (3) of no activity, other members can be shown a quiet
  prompt. Nobody is ever told they have been inactive.

Invite codes are canonicalised before comparison — `HalaqaInviteCode.canonical`
uppercases and strips everything outside `[A-Z0-9]`, so `k7p2-qm `, `K7P2 QM` and
a code pasted mid-sentence all resolve to the same circle. `0` and `1` are *not*
remapped to `O` and `I`: a wrong code should fail as "not found" rather than be
silently rewritten into a different circle's code.

Circles work signed out, but only on that device — an offline circle is a row in
one phone's SQLite and nothing more, so its invite code can never be joined by
anybody. The create sheet says this in plain language rather than letting a
friend discover it.

---

## Al-Minbar — the public feed

A public feed of shared content, paged 20 at a time
(`AppConstants.minbarPageSize`). Same three reactions. **No comments** — the same
reasoning as Halaqa, for the same reason.

---

## The knowledge graph

Under `lib/features/knowledge/` and `lib/core/knowledge/`. Entities (prophets,
companions, scholars, places, themes, ayat, hadith) are connected by edges, and
almost every edge is **derived** rather than stated:

- **Shared citations** — two entries that cite the same ayah are connected
  through it.
- **Chronology** — ordering comes from each entry's own `sequence_number`, never
  from a hand-written list.
- **Theme membership** — keyword frequency across each entry's layer text, with a
  `min_hits` threshold per theme.

Thresholds were measured, not guessed. `tools/audit_corpus.dart` shows the
method: each `min_hits` sits at the point where the hit distribution across all
186 corpus entries falls away, so a theme collects the entries that discuss it
and stops before the ones that mention the word in passing. A common English
keyword needs a higher bar than a specific term — `leadership`, whose keywords
include "command" and "appointed", requires 5 hits; `tawheed` requires 2.
`wisdom` was removed from the `ilm` theme because hikmah is not 'ilm, and keeping
it pulled in Divine-Name pages that merely say events happen by Allah's wisdom.

`edges.json` — the hand-stated edges — contains **six** entries and is meant to
stay tiny. What lands there is only what the corpus states in prose and no amount
of citation-matching would find: family relationships. Each one names where the
relationship is stated.

**Evidence mode** renders any claim together with its sources. **Journeys** are
curated reading paths whose every step is an id that exists in the corpus today —
a journey with a dangling step is not shipped. A journey is not a course: no
score, no unlocking, no streak.

---

## The corpus, counted

Real counts, from the shipped asset files:

| Collection | Entries |
| --- | --- |
| Prophets | 11 |
| Companions (sahabah) | 43 |
| Divine Names | 100 |
| Seerah chapters | 32 |
| Themes | 6 |
| Journeys | 5 |
| Scholars | 12 |
| Places | 12 |
| Hand-stated edges | 6 |

Discover shows these numbers, not rounder ones. There is no "new this week"
section, because the corpus carries no authoring dates and inventing them would
be a claim about content.

Ibn Kathir tafsir text ships under `assets/data/ibn_kathir/` and
`assets/data/ibn_kathir_processed/`. Arabic is set in Amiri (regular + bold,
bundled).

---

## Data sources

**UmmahAPI** (`https://ummahapi.com`) is the primary source for tafsir,
word-by-word data, mutashabihat, hadith and audio. Configuration lives in one
place, `lib/core/config/ummah_api_config.dart`:

- The key is sent **only** as the `X-API-Key` header. The API also accepts
  `?apikey=…` and that form is deliberately unused: a key in a query string lands
  in server access logs, proxy logs, crash reports and `Referer` headers — and,
  worst for a client that caches, in the cache key itself, which would mean
  storing a response in a file whose name contains the secret.
- The key is read from `.env` **at call time**, never captured into a `const` or
  a field, so there is exactly one definition of where it comes from and a build
  with an empty `.env` degrades instead of crashing.
- **Every endpoint answers without a key.** The key only lifts the rate limit
  from 5,000 requests / 15 min to unlimited. `isAuthenticated` is therefore a
  statement about quota, never about access, and nothing in the app is gated on
  it.
- `UMMAH_API_BASE_URL` can point the client at a staging host without a code
  change.

**Audio** has two sources and a deliberate fallback: ayah-by-ayah recitation from
everyayah.com, surah audio via MP3Quran. MP3Quran is kept in place until the
UmmahAPI migration is verified on real devices — removing a working audio path
before its replacement is proven is how an app ships silent.

Responses go through a shared on-disk cache (`api_cache`), keyed by the request
URI — which is safe to store precisely because the key never appears in it.

Reference documentation: [`docs/UMMAH_API.md`](docs/UMMAH_API.md) and
[`docs/UMMAH_API_IMPLEMENTATION.md`](docs/UMMAH_API_IMPLEMENTATION.md).

---

## The Mizan design system

Two themes, one token layer, no per-screen colour decisions.
[`docs/MIZAN_SCREEN_SPEC.md`](docs/MIZAN_SCREEN_SPEC.md) is the specification;
[`docs/DESIGN_SYSTEM_AUDIT.md`](docs/DESIGN_SYSTEM_AUDIT.md) records where the
code currently diverges from it.

**`MizanPalette.of(context)`** — `page`, `card`, `sunk`, `hairline`, `ink`,
`muted`, `accent`, `accentText`, `link`, `sage`, `onFilled`, plus `isLight`.

**`MizanGeometry`** — `gutter` 20, `cardPadding` 20, `cardPaddingTight` 18, `gap`
14, `cardRadius` 18, `rowRadius` 14, `pillRadius` 999, `tapTarget` 44,
`tabBarHeight` 64, `scrollBottomPadding` 96, `hairlineWidth` 1.

**`MizanTone`** — `page`, `card`, `sunk`, `inverse`, each able to resolve its own
foreground (`onColor`), muted, hairline and accent-text colours, so a component
placed on any surface stays legible without asking which theme is active.

**`MizanType`** — `screenTitle`, `cardHeadline`, `translation`, `body`,
`bodyStrong`, `sectionLabel`, `arabic`, `button`, `navLabel`, `wordmark`,
`tagline`.

**Components** (`lib/shared/widgets/mizan/`) — `MizanSurface`, `MizanButton`
(with `.secondary` / `.quiet` / `.chip`), `MizanIconTile`, `MizanRow`,
`MizanSectionLabel`, `MizanRule`, `MizanDiamond`, `MizanArch`, `MizanPressable`,
plus the brand set: `MizanMark`, `MizanGlyph`, `MizanWordmark`, `MizanTagline`,
`MizanLogo`, `MizanLogoRow`.

Rules worth knowing before editing a screen:

1. **Gold-family colours are never text on cream.** Use `accentText` (bronze on
   light, gold on dark).
2. **There is no error token.** A failure state borrows `accentText` rather than
   introducing a red that belongs to neither theme.
3. **`sage` is for good news and neutral notices**, not warnings.
4. **`inputDecorationTheme` is global** — a pill `sunk` fill, no border, a `link`
   focus ring. A plain `TextField` needs only `hintText`; restyling one is a
   sign something is wrong.
5. **Filled tiles must be checked in both themes.** Contrast that works on cream
   frequently fails on navy.
6. **One entry point per action.** If a control already exists for something,
   there is not a second one.
7. **A control keeps its label.** Never rename a button per item — that is how
   the reader ended up saying "Tafsir" in Al-Fatihah and "Reflect" everywhere
   else.

Brand assets are real files, not generated at runtime:
`assets/brand/mizan_glyph_{cream,navy}.png` and
`mizan_icon_{cream,navy}.png`, with 2.0x and 3.0x variants. The launcher icon is
user-switchable — see [`docs/APP_ICON_SWITCHING.md`](docs/APP_ICON_SWITCHING.md).

---

## Architecture

Riverpod throughout, three layers per feature, in one direction only:

```
presentation/   widgets and screens — watch providers, never touch a database
domain/         providers, notifiers, business rules
data/           repositories — the only code that knows about tables or endpoints
models/         plain data shapes with toMap / fromMap
```

A widget that reads SQLite directly is a bug. Repositories are interfaces, so
swapping a backend is a one-line change in a provider — which is exactly how
Halaqa works today:

```dart
final halaqaRepositoryProvider = Provider<HalaqaRepository>((ref) {
  final online = ref.watch(isOnlineIdentityProvider);
  return online ? SupabaseHalaqaRepository() : LocalHalaqaRepository();
});
```

Signed in, circles live in Postgres. Signed out, the same interface is served
from on-device SQLite, unchanged from before real auth existed. No screen knows
the difference.

**Shared surface**: `lib/core/` holds theme, router, config, network, knowledge
primitives, constants and utilities; `lib/shared/` holds cross-feature models
(`SharedContent`, `ReactionType`, `UserProfile`, `Reciter`) and widgets;
`lib/services/` holds the database and API services.

Key packages: `go_router ^13`, `flutter_riverpod ^2.5`, `supabase_flutter ^2.17`,
`sqflite ^2.3`, `just_audio ^0.10.6` with `audio_session ^0.2.4` declared
explicitly (iOS routes to the ambient stream and Android never requests audio
focus unless the session is configured), `dio ^5.4`, `http ^1.2`,
`flutter_dotenv ^5.1`, `flutter_local_notifications ^22.3`, `timezone`,
`flutter_timezone`, `google_fonts ^6.2`, `intl ^0.20.3`, `crypto ^3.0.6`,
`package_info_plus ^10.2`, `path_provider ^2.1.6`, `shared_preferences ^2.3`.

Dart SDK `>=3.3.0 <4.0.0`.

---

## Local database

`sqflite`, file `mizan.db`, **schema version 6**. Thirteen tables:

| Table | Holds |
| --- | --- |
| `vocab_words` | Vocabulary bank entries with SRS state |
| `layer_unlocks` | One row per `(surah, ayah, layer)` first-open |
| `reflections` | What the reader wrote in the Reflection layer |
| `hadith_cache` | Fetched narrations |
| `hadith_reflections` | Reflections on narrations (added in v6) |
| `api_cache` | Shared response cache, keyed by request URI |
| `user_profile` | The local (signed-out) identity |
| `halaqas` | Circles |
| `halaqa_members` | Membership, with `last_active_at` for nudges |
| `halaqa_shares` | Shared items, content stored as a JSON snapshot |
| `halaqa_reactions` | One row per member per reaction per share |
| `minbar_shares` | Public feed items |
| `minbar_reactions` | Public feed reactions |

Discover keeps its own database, `mizan_discover_v2.db`.

Shared content is stored as a JSON **snapshot**, not a reference. A card in a
feed renders instantly and cannot break later because the source moved.

Spaced repetition intervals are `[1, 3, 7, 14, 30, 90]` days, three reviews a
day (`dailyVocabReviewCount`).

---

## Supabase

Migrations in `supabase/migrations/`, applied in order:

| File | What it adds |
| --- | --- |
| `001_initial_schema.sql` | Base tables |
| `002_auth_rls.sql` | Auth, `public.users`, the sign-up mirror trigger, RLS policies |
| `003_halaqa_minbar_online.sql` | Online circles and feed — `last_active_at`, `shared_by_name`, `content_json`, the capacity trigger, `seerah` added to both content-type CHECKs |
| `BUNDLE_run_in_sql_editor.sql` | All of the above concatenated, for pasting into Supabase Studio |

**Any new migration must be appended to the bundle as well**, or a fresh project
set up through Studio will be missing it.

Notes that will save an afternoon:

- **`halaqa_members` has no `display_name` column.** Names are read through the
  `user_id → users.id` foreign key with a PostgREST embed:
  `.select('…, users(display_name)')`. This is unambiguous — it is the only
  foreign key from that table to `users` — and it means a member's name is always
  current instead of a copy that drifts. Writing a `display_name` here fails the
  whole insert.
- **A `public.users` row is a hard prerequisite** for joining a circle. It is
  written by a trigger on sign-up and mirrored again on **every login**, because
  an account created before the trigger existed would otherwise fail every circle
  it tried to join with nothing on screen to explain why. A missing row surfaces
  as SQLSTATE `23503`.
- **PostgREST has no cross-statement transaction.** `createHalaqa` writes the
  circle, then the creator's membership; if the second insert fails the first is
  compensated with an explicit delete. Without that, a failed create left an
  orphan circle invisible to its own creator — the list is built from
  memberships — while holding a spent invite code.
- **SQLSTATE mapping**: `23505` unique violation → already a member; `P0001`
  raised as `halaqa_full` by the capacity trigger → circle full; `23503` →
  missing profile row.
- **RLS does not hide circles by row.** `halaqas_select_authenticated` uses
  `USING (true)` on purpose: the invite code is the access secret, not row
  visibility. `halaqa_members_insert_self` uses
  `WITH CHECK (auth.uid() = user_id)`, which is what allows joining a circle you
  are not yet in.
- Empty circles are cleaned up by a server trigger that mirrors what the local
  repository does.

---

## Environment and secrets

Create `.env` in the repository root. **Only two keys are read anywhere in
`lib/`:**

```dotenv
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<anon key>
```

`SUPABASE_URL` defaults to `http://127.0.0.1:54321` when absent, which is a local
Supabase, not a working app.

Optional:

```dotenv
UMMAH_API_KEY=<key>            # lifts the rate limit only; every endpoint works without it
UMMAH_API_BASE_URL=<host>      # staging override
```

`.env.example` still advertises `GROQ_API_KEY`, `AZURE_OPENAI_*`,
`AZURE_SEARCH_*` and `SUNNAH_API_KEY`. **Nothing in `lib/` reads any of them.**
They are left over from an earlier design and are being removed.

> ⚠️ **`.env` is declared as a Flutter asset in `pubspec.yaml`, which means it is
> bundled into the APK.** Anyone who unzips a release build can read it. That is
> acceptable for the Supabase anon key, which is public by design and constrained
> by RLS, and for the UmmahAPI key, which only affects rate limits. **Never put a
> service-role key, a signing key, or any real secret in this file.** Secrets
> belong behind an Edge Function.

Self-service account deletion is deliberately not implemented client-side: it
needs a service-role key, which never belongs in client code. `deleteAccount()`
signs out and forgets the local flag.

---

## Running it

```bash
git clone https://github.com/Shahriyar31/ummahapp.git
cd ummahapp

# 1. Environment
cp .env.example .env      # then fill in SUPABASE_URL and SUPABASE_ANON_KEY

# 2. Dependencies
flutter pub get

# 3. Database
#    Either point .env at a Supabase project and paste
#    supabase/migrations/BUNDLE_run_in_sql_editor.sql into its SQL editor,
#    or skip it — the app runs fully signed out on local SQLite.

# 4. Run
flutter run
```

Signed out is a first-class mode, not a degraded one. Everything works except
anything that must cross devices: circles are local to the phone, and the feed is
local to the phone.

---

## Verifying changes

```bash
# Type-check specific paths (accepts files or directories) — fast
bash tools/analyze.sh lib/features/halaqa lib/features/settings

# Full analysis
flutter analyze

# Tests
flutter test
```

Test coverage is thin and honestly so: `test/unit/features/quran/layer_unlock_logic_test.dart`
and `test/widget_test.dart`. The layer unlock schedule is the one piece of logic
with real unit coverage, because it is the piece where an off-by-one silently
changes what a saved row means. `widget_test.dart` covers the theme layer —
that light and dark resolve independently, and that a `MizanButton` renders and
fires. Nothing pumps the real app root: it boots GoRouter, sqflite, dotenv and
SharedPreferences, none of which answer in a bare `flutter test`, and faking a
smoke test around that would prove less than the absence of one admits.

Other tools in `tools/`:

| Tool | Purpose |
| --- | --- |
| `analyze.sh` | Scoped type-check |
| `audit_corpus.dart` | Measures keyword hit distribution across all 186 corpus entries — the method behind every theme threshold |
| `validate_discover.py` | Checks Discover corpus files for structural problems |
| `reindex_discover.py` | Rebuilds Discover indexes |
| `model_conformance.py` | Checks data files against the Dart models |
| `ummah_probe.sh` | Probes UmmahAPI endpoints and reports what actually comes back |
| `CONTENT_BRIEF_*.md` | The authoring briefs for prophets, sahabah and seerah content |

---

## Building an APK

```bash
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

For a device on the same machine:

```bash
flutter build apk --debug
flutter install
```

> The `applicationId` is `io.github.shahriyar31.mizan`. It was `com.example.*`
> until now, which Google Play rejects outright; it was changed **before** any
> build went to anyone, because changing it afterwards means a fresh install
> rather than an update. Anyone forking this must change it to their own
> reverse-domain id.

---

## Known limitations

Written plainly, because a friend installing this build deserves to know what is
unfinished.

### Must change before any release

- **`LayerMeta.unlockInterval` is `Duration(seconds: 1)`**
  (`lib/features/quran/models/layer_unlock.dart:128`). Release value is
  `Duration(hours: 24)`. It is set low on purpose right now so the layer
  progression can be exercised on a device in one sitting; it must not be changed
  without saying so, because device testing depends on it.
- **No LICENSE file.** Without one, default copyright applies and nobody may
  legally reuse this code. Add one before making the repository public.

### Features that are not what they look like

- **Scholar AI ships locked.** One file, a placeholder. The earlier design
  (Azure OpenAI + Azure AI Search RAG) is not implemented and is not wired to
  anything. Nothing in the app generates religious content, which is the point.
- **Hadith topic search returns zero results for every topic.** Faith, Prayer,
  Patience — all of them show "Nothing returned." Direct hadith citation works
  (a specific collection and number resolves), so retrieval is partially
  functioning and the fault is in the topic-search layer: either the
  `/hadith/search` query parameter or the topic vocabulary not matching the API
  corpus. Diagnosing it requires network access to `ummahapi.com`; run
  `bash tools/ummah_probe.sh` to produce the per-topic result counts. **No topic
  should ship while it always returns zero.**
- **Only 5 of 408 hadith references in the corpus are currently fetchable.** The
  other 403 render as a citation with no narration text behind it.
- **`AppConstants.totalLayers` still says 5**, from before Similar existed. It is
  not what the reader uses — `LayerMeta.count` is — but it is stale and
  misleading to anyone reading the constants file.
- **Audio migration is incomplete by design.** MP3Quran and everyayah remain the
  working paths; the UmmahAPI audio route is present but not yet verified on real
  devices, which is why the fallback has not been removed.

### Half-migrated design system

The Mizan token layer is the intended surface, but the migration is not finished:
**40 files still import the legacy `lib/core/theme/app_colors.dart`**, against 33
on `mizan_tokens.dart`. `AppColors` is a single mutable static palette flipped at
runtime, which is why screens still on it can show the wrong theme's colours.
The notable ones:

- Discover's four tab bodies and every Discover detail screen
- `lib/features/quran/presentation/layer_screen.dart` — including two hardcoded
  `'$layersRead / 5 layers'` strings
- The whole Settings sub-screen tree (`audio`, `language`, `more`,
  `notifications`, `personalisation`, `system`, `settings_row.dart`)
- Growth's screens and the constellation view
- `lib/features/sharing/share_target_sheet.dart`
- Several shared widgets: `citation_block`, `reaction_bar`,
  `shared_content_card`, `word_tap_sheet`, `arabic_text`, `narrative_text`,
  `pill_layer_navigation`, `content_visuals`, `initial_avatar`

`lib/features/discover/widgets/entry_card.dart` (502 lines) is dead code —
nothing imports it. So are five service files, each superseded by another and
imported by nothing: `services/local/database_service.dart` (the live one is
`services/database/`), `services/ai/scholar_ai_service.dart` (duplicated by
`services/scholar_ai/`), `services/notifications/fcm_service.dart`, and both
`services/supabase/supabase_client.dart` and `supabase_service.dart` (the app
uses `Supabase.instance.client` directly). `Scholar_aiScreen` violates Dart's
UpperCamelCase convention. `quran_repository.dart` has no SQLite persistence
layer yet.

`docs/DESIGN_SYSTEM_AUDIT.md` carries the full list, including deliberate
deviations from the mockups and the reason for each. Where the mockup and the
data disagreed, the data won: Discover shows real counts (11 prophets, 43
companions, 100 names, 32 seerah chapters) rather than the round numbers in the
design, and the "recently added" strip is labelled honestly because the corpus
has no authoring dates.

### Leftover names

Resolved. The Dart package, both SQLite filenames, the notification channel, the
Android application id, the native window titles and every user-visible string
now read Mizan. What remains is three legacy constants used only to migrate
existing installs, and one content use of the Arabic word — both explained under
[The name](#the-name). The GitHub repository is still called `ummahapp`; that
rename is a manual step in GitHub's settings.

### Repository hygiene

The eleven spent one-off migration scripts that used to sit at the repository
root (`fix_*.py`, `generate_remaining_names.py`, `setup_structure.sh`) have been
deleted — they were applied once, months of the old name lived in them, and none
of them were part of the build. Still at the root: `docker-compose.yml` from an
abandoned local-Supabase workflow, and `PROJECT_CONTEXT.md`, which is a working
note rather than documentation.

---

## Repository layout

```
ummahapp/
├── lib/
│   ├── main.dart, app.dart
│   ├── core/
│   │   ├── theme/          mizan_tokens, mizan_theme, mizan_typography (+ legacy app_colors)
│   │   ├── router/         app_router.dart — one ShellRoute, six tabs
│   │   ├── config/         ummah_api_config.dart, hadith_api_config.dart
│   │   ├── network/        ummah_api_client.dart
│   │   ├── knowledge/      entity refs, reference parser, graph primitives
│   │   ├── constants/      app_constants.dart
│   │   └── utils/          logger, id_generator
│   ├── features/           12 areas — see the table above
│   ├── shared/
│   │   ├── models/         SharedContent, ReactionType, UserProfile, Reciter
│   │   └── widgets/        mizan/ components + shared cards, text, sheets
│   └── services/
│       ├── database/       database_service.dart — SQLite, v6
│       ├── audio/          session setup, MP3Quran, playback arbiter, recitation cache
│       ├── cache/          api_cache.dart
│       ├── hadith/         hadith_api_service.dart
│       ├── quran/          quran_api_service.dart
│       ├── notifications/  notification_service.dart
│       ├── scholar_ai/     the locked placeholder
│       └── seed/           social_seeder.dart
├── assets/
│   ├── brand/              Mizan glyph + icon, cream and navy, 2x/3x
│   ├── data/
│   │   ├── discover/       prophets, sahabah, names, seerah
│   │   ├── knowledge/      themes, journeys, scholars, places, edges
│   │   ├── ibn_kathir/     tafsir text
│   │   └── quran_metadata.json
│   └── fonts/              Amiri Regular + Bold
├── supabase/migrations/    001, 002, 003 + BUNDLE_run_in_sql_editor.sql
├── docs/                   design spec, design audit, knowledge platform, UmmahAPI
├── tools/                  analyze.sh, corpus audit, validators, API probe, content briefs
├── test/                   layer unlock logic, widget smoke test
└── android/ ios/ web/ linux/ macos/ windows/
```

---

## Author

Built by [Shahriyar](https://github.com/Shahriyar31) — reachable from the app's
own Settings screen, which links to the same profile.

No licence is declared yet; see [Known limitations](#known-limitations).
