# Design System Audit — "Before" Map

*Read-only inventory taken 2026-08-22 at commit `c9b1945`, immediately before the UI/UX redesign and rename. Purpose: know exactly what exists today so the redesign is a deliberate migration rather than a guess. 129 Dart files, 25,618 LOC in `lib/`.*

---

## Executive summary — the seven things that matter

1. **`AppColors.gold` is not gold, it's blue** (`0xFF7FB7D0`) — and it has **261 references**, the single largest styling coupling in the codebase. Renaming or repaletting it touches everything.
2. **There are no spacing, radius, or elevation tokens at all.** Every margin, gap, and corner is a raw number. 13 distinct `EdgeInsets.all` values, 20 distinct `SizedBox(height:)` values, 13 distinct radii.
3. **Inter is not actually bundled.** Six places set `fontFamily: 'Inter'` as a raw string against a family that was never declared, so they silently render in Roboto — including the bottom navigation labels. This is a live bug, visible today.
4. **Two fonts are fetched over the network at runtime.** Lora and Inter come from `google_fonts` with no bundled offline fallback. For an offline-first app aiming at worldwide use, first launch on a poor connection degrades typography.
5. **The bottom nav has 5 items, not 6.** Growth has a route but no nav item, and because `/growth` isn't in the nav's route list the nav highlights HOME while Growth is on screen. Same for Settings.
6. **The app had two competing identities**: the Dart package was `taddabur`, every native platform `ummahapp`. Both were reconciled to `mizan` on 2026-08-23 — section 6 records what was found and what shipped.
7. **No brand assets exist yet.** Every launcher icon is the stock Flutter template, and the splash screen is still default white — a white flash before a dark app. `assets/` contains no imagery at all.

---

## 1. Colour

`lib/core/theme/app_colors.dart` — 48 tokens, all static getters resolved through `_pick(dark, light)`.

Despite being described as dark-theme-only, **the palette is fully dual-mode** and `lib/app.dart:40-49` honours a `themeModeProvider` supporting light, dark, and system. Decide during the redesign whether light mode is a supported product surface or dead weight; right now it is half-real.

### Palette groups (dark / light)

| Group | Token | Dark | Light | Uses |
|---|---|---|---|---|
| Primary | `night` | `0xFF101720` | `0xFFFBF6EC` | 55 |
| | `slate` | `0xFF1B2733` | `0xFFF3EAD8` | 35 |
| | `jade` | `0xFF5E9FB6` | `0xFF2C7691` | 84 |
| | `jadeLight` | `0xFF9ACDDE` | `0xFF4E9CB4` | 4 |
| | `gold` | `0xFF7FB7D0` | `0xFF1F6E8C` | **261** |
| | `goldSoft` | `0xFFB7D9E6` | `0xFF3D8CA8` | 8 |
| | `goldPale` | `0xFFE8F3F7` | `0xFF2A6E86` | 1 |
| | `clay` | `0xFFE0916A` | `0xFFAD5A2B` | 3 |
| | `clayBg` | `0xFF2A1D14` | `0xFFF3E3D2` | **0** |
| Surfaces | `surface` | `0xFF17212B` | `0xFFFFFCF5` | 35 |
| | `surfaceElevated` | `0xFF22313D` | `0xFFF5EEDD` | 21 |
| | `surfaceDim` | `0xFF0D141B` | `0xFFEFE3C9` | 8 |
| Neutrals | `parchment` | `0xFFEAF1F4` | `0xFF16283A` | 16 |
| | `parchment2` | `0xFFD9E4E9` | `0xFF3E5468` | 1 |
| | `parchment3` | `0xFFC7D4DA` | `0xFF6C7F8C` | **0** |
| | `white` | `0xFFFFFFFF` | same | 13 |
| Text | `ink` | `0xFF111412` | same | 7 |
| | `textPrimary` | `0xFFEEF4F6` | `0xFF16283A` | **127** |
| | `textSecondary` | `0xFFC0CCD1` | `0xFF3E5468` | 43 |
| | `body` | `0xFFD5DEE3` | `0xFF33495C` | **0** |
| | `muted` | `0xFF91A0A8` | `0xFF6C7F8C` | **175** |
| | `border` | `0xFF31424D` | `0xFFE3D5B8` | 42 |
| | `borderLight` | `0xFFC7D4DA` | `0xFFEDE1C8` | **0** |
| Semantic | `success` | `0xFF34D399` | `0xFF15803D` | 5 |
| | `error` | `0xFFF87171` | `0xFFB91C1C` | 15 |
| | `amber` | `0xFFFBBF24` | `0xFFB45309` | 16 |
| | `violet` | `0xFF8B5CF6` | `0xFF6D28D9` | 9 |
| | `successDim`, `successBg`, `errorDim`, `amberDim`, `amberBg`, `violetBg` | — | — | **0** |
| | `errorBg`, `violetDim` | — | — | 1 each |
| Content cards | `cardQuranBg` | `0xFF0F1A28` | `0xFFE9F1F8` | 4 |
| | `cardSahabiBg` | `0xFF241C14` | `0xFFF8F0E4` | **0** |
| | `cardHadithBg` | `0xFF1E2D3D` | `0xFFEAF0F6` | 1 |
| | `cardNameBg` | `0xFF0B1120` | `0xFFEDEFF7` | 2 |
| | `cardProphetBg` | `0xFF0D2218` | `0xFFE6F3EC` | 1 |
| | `cardSeerahBg` | `0xFF171426` | `0xFFEFEDF8` | 2 |
| Quran | `quranSurface` | `0xFF1A2535` | `0xFFFFFDF7` | 10 |
| | `quranSurfaceDim` | `0xFF0D1626` | `0xFFF6EEDC` | 1 |
| | `quranBorder` | `0xFF2A3545` | `0xFFE3D5B8` | 2 |
| | `quranMuted` | `0xFF9CADB8` | `0xFF5D6E78` | 4 |
| Nav | `navActive` | alias → `gold` | — | **0** |
| | `navInactive` | `0xFF82929B` | `0xFF77878F` | 6 |
| | `navBg` | `0xFF121C25` | `0xFFFFFCF5` | 4 |

### What this tells us

**Eleven tokens are entirely dead**: `clayBg`, `parchment3`, `body`, `borderLight`, `successDim`, `successBg`, `errorDim`, `amberDim`, `amberBg`, `violetBg`, `navActive`. Eight more have two uses or fewer.

**The per-content-type card system was never adopted.** Six card background tokens exist for the six content types, with usage counts of 4, 0, 1, 2, 1, 2. The design intent — every shared piece of content is colour-coded by type — is present in the palette but absent from the UI.

**Naming is misleading.** `gold`, `goldSoft`, and `goldPale` are all blue; `jade` is blue-teal. This looks like a palette that shifted from warm to cool without renaming, and the old names stuck. Rename during the redesign, ideally to role-based names (`accent`, `accentMuted`) rather than colour-based ones, so the next repalette doesn't reintroduce the same lie.

**Opacity is doing the work tokens should do.** 184 `withValues(alpha:)` calls across 29 distinct alpha values, most commonly 0.15 (25×), 0.3 (20×), 0.5 (16×), 0.4 (16×). Shading is improvised per call site rather than defined once.

---

## 2. Typography

`lib/core/theme/app_typography.dart` — 17 static methods. Arabic is bundled Amiri; Latin is `google_fonts` (Lora for display, Inter for UI).

| Method | Family | Size | Weight | Height | Uses |
|---|---|---|---|---|---|
| `arabicHero` | Amiri | 32 | 400 | 1.9 | 3 |
| `arabicDisplay` | Amiri | 26 | — | 1.9 | 18 |
| `arabicBody` | Amiri | 20 | — | 1.85 | 9 |
| `arabicSmall` | Amiri | 16 | — | 1.8 | 2 |
| `displayLarge` | Lora | 26 | 700 | 1.3 | 10 |
| `displayMedium` | Lora | 22 | 600 | 1.35 | 6 |
| `displaySmall` | Lora | 18 | 600 | 1.4 | 35 |
| `quoteItalic` | Lora italic | 14 | — | 1.7 | 19 |
| `labelLarge` | Inter | 14 | 600 | — | 34 |
| `labelMedium` | Inter | 12 | 500 | — | 14 |
| `labelSmall` | Inter | 10 | 700 | — | **71** |
| `bodyLarge` | Inter | 14 | 400 | 1.75 | 16 |
| `bodyMedium` | Inter | 13 | 400 | 1.7 | 45 |
| `bodySmall` | Inter | 12 | — | 1.55 | **66** |
| `caption` | Inter | 10 | 600 | — | 40 |
| `buttonPrimary` | Inter | 14 | 700 | — | 4 |
| `buttonSecondary` | Inter | 13 | 600 | — | 11 |

### Issues to resolve in the redesign

**Only Amiri is bundled** (`pubspec.yaml:60-65`: `Amiri-Regular.ttf`, `Amiri-Bold.ttf`). Lora and Inter are fetched at runtime by `google_fonts`, meaning first launch without connectivity renders fallback fonts. Bundling them is the fix if offline-first matters.

**Six sites request a font family that doesn't exist**, so they render in Roboto instead of Inter:

- `lib/shared/widgets/app_shell.dart:191` — the bottom nav labels
- `lib/features/quran/presentation/layer_screen.dart:225`
- `lib/features/quran/presentation/quran_screen.dart:452`
- `lib/features/growth/presentation/growth_screen.dart:236`
- `lib/features/growth/presentation/vocab_bank_screen.dart:250`
- `lib/features/growth/presentation/widgets/constellation_view.dart:240`

**The scale is bottom-heavy.** The three smallest styles (`labelSmall` 10pt, `bodySmall` 12pt, `caption` 10pt) account for 177 of ~400 usages. A lot of the interface is rendered at 10–12pt, which is worth revisiting for readability, especially for older users reading scripture.

**Two extra Arabic faces live outside the type system** — `GoogleFonts.scheherazadeNew` and `GoogleFonts.lateef` at `lib/features/settings/domain/reading_preferences_provider.dart:27,30`, as user-selectable Quran fonts. Fold these into the type system rather than leaving them as a side channel.

---

## 3. Spacing, radius, elevation

**No `AppSpacing`, `AppRadius`, or `AppDimens` class exists.** `lib/core/constants/app_constants.dart` holds only business-logic values. Every layout number in the app is a literal.

| Metric | Occurrences | Distinct values | Most common |
|---|---|---|---|
| `EdgeInsets.all(N)` | 66 | 13 | 16 (×22), 18 (×10), 14 (×8), 32 (×6), 24 (×5) |
| `EdgeInsets.symmetric(...)` | 67 | — | — |
| `SizedBox(height: N)` | 300 | 20 | 12 (×43), 8 (×41), 20 (×29), 16 (×27), 10 (×25) |
| `SizedBox(width: N)` | 92 | 9 | 12 (×19), 8 (×18), 10 (×14), 14 (×13) |
| `BorderRadius.circular(N)` | 159 | 13 | 99 (×44, pill), 20 (×25), 14 (×23), 12 (×23), 16 (×17) |

A 4pt grid is loosely implied but broken by 18, 14, 22, 6, 3, 5, 74, and 100, and by radii of 2, 3, 10, 14, 18, 22, 28. Introducing a token scale is the single highest-leverage structural change available, and it's mechanical rather than creative.

**Elevation is already consistent and deliberate**: zero `BoxShadow` anywhere in `lib/`, and `elevation:` appears four times, always `0`. Depth is expressed purely through surface tint plus 1px borders. This is a real design decision worth preserving explicitly in the new system.

---

## 4. Where screens bypass the system

### Hardcoded colours outside the theme — 12 occurrences in 4 files

- `lib/features/quran/presentation/layer_screen.dart:410,411,426,427,429` — seven raw gradient and border colours. Worst offender.
- `lib/features/discover/widgets/entry_card.dart:221-223,236` — a private palette that **copies token hex values verbatim** (`_onBlackAccent = 0xFF7FB7D0` is `gold`; `_onBlackMuted = 0xFFC0CCD1` is `textSecondary`). These will not follow a repalette and will silently drift.
- `lib/features/scholar_ai/presentation/scholar_ai_screen.dart:13` — `0xFF0B1120`, a copy of `cardNameBg`.
- `lib/features/home/presentation/home_screen.dart:1314` — `_purple = 0xFF7C6EAF`, entirely off-palette.

### Flutter built-in colours — 42 occurrences in 19 files

23 are benign `Colors.transparent`, leaving 19 real bypasses. The worst is `lib/features/discover/screens/quiz_screen.dart` (10 occurrences): the entire correct/incorrect feedback palette uses `Colors.green.shade400/900/300` and `Colors.red.shade...` at lines 160-166, 219, 224, ignoring the `success` and `error` tokens. Then `entry_card.dart` (6) and `home_screen.dart:1051,1455,1458`.

### Raw `TextStyle(` bypassing the type system — 43 occurrences, 37 outside `core/theme`

Concentrated in `layer_screen.dart` (11), `home_screen.dart` (8), `discover_screen.dart` (4).

**Two files are near-total opt-outs of the design system** and should be treated as rewrites rather than restyles:

- `layer_screen.dart` — 11 raw TextStyle, 5 raw Color, 18 BoxDecoration
- `home_screen.dart` — 8 raw TextStyle, 1 raw Color, 20 BoxDecoration, 1,655 lines

---

## 5. Component inventory

`lib/shared/widgets/` — 14 files.

| Widget | Purpose | External consumers |
|---|---|---|
| `app_shell.dart` | Scaffold + bottom nav | 1 (router) |
| `layer_story_scaffold.dart` | 5-layer story reader scaffold | 4 |
| `tactile.dart` | Press-feedback wrappers | 6 total |
| `initial_avatar.dart` | Initials avatar circle | 3 |
| `reaction_bar.dart` | Emoji reaction pill row | 2 |
| `shared_content_card.dart` | Feed card for shared content | 2 |
| `content_visuals.dart` | Per-type icon/colour lookup | 1 |
| `fade_slide_in.dart` | Entrance animation | 1 |
| `responsive.dart` | Tablet width cap | 1 |
| `word_tap_sheet.dart` | Arabic word-tap sheet | 1 |
| `arabic_text.dart` | — | **0 (dead)** |
| `citation_block.dart` | — | **0 (dead)** |
| `narrative_text.dart` | — | **0 (dead)** |
| `pill_layer_navigation.dart` | — | **0 (dead)** |

### Patterns re-implemented instead of shared

These are the consolidation targets, and they're the reason a redesign currently costs six edits per change:

- **Empty states — written 6 times**: `quran_screen.dart:531`, `halaqa_screen.dart:97`, `discover_browser.dart:567`, `vocab_bank_screen.dart:258`, plus `_EmptyFeed` in `minbar_screen.dart:161` and `halaqa_circle_screen.dart:345`.
- **Loading/error views — written 7 times** under three different naming conventions (`_LoadingView`/`_ErrorView`, `_LoadingState`/`_ErrorState`, `_LoadingPage`/`_ErrorPage`), plus 24 raw `CircularProgressIndicator` across 20 files.
- **Cards — 147 `BoxDecoration(` with no shared card widget** (home 20, layer 18, discover 14).
- **Bottom sheets — hand-rolled in 5 places.**
- **No shared section-header widget at all.**

---

## 6. Rename checklist

> **Status: executed 2026-08-23.** Everything below is the "before" survey and is
> kept as a record of what was found, not as outstanding work. What actually
> shipped: `pubspec.yaml` `name: mizan` and every `package:` import rewritten;
> `TadabburApp` → `MizanApp`; `AboutTaddaburScreen` → `AboutMizanScreen`; all
> user-visible strings and the four notification bodies; `mizan.db` and
> `mizan_discover_v2.db` **each with a rename-on-open migration** so existing
> data survives; channel id `mizan_daily` with the legacy channel deleted on
> launch; `applicationId`/`namespace` → `io.github.shahriyar31.mizan` with the
> MainActivity package and directory moved; iOS/web/Linux/Windows names;
> `test/widget_test.dart` rewritten (it was uncompilable boilerplate). Two things
> deliberately left: the seerah JSON's content use of the word, and the macOS
> Xcode product references (macOS is not a build target, and sed-ing a pbxproj
> product reference breaks builds for no gain). The GitHub repository name is a
> manual step for the account owner.

The app currently has **two identities**: the Dart package is `taddabur`, every native platform target is `ummahapp`. Both need reconciling to the new name. Build artefacts excluded.

### Dart package name — 30 `package:taddabur` references in 10 files

`pubspec.yaml:1` (`name: taddabur`) is the root; changing it breaks every reference below.

`lib/features/discover/widgets/entry_card.dart:8,9` · `discover_browser.dart:23,24` · `screens/quiz_screen.dart:11,12` · `screens/prophet_detail_screen.dart:4-8` · `sahabi_detail_screen.dart:4-8` · `divine_name_detail_screen.dart:4-8` · `seerah_detail_screen.dart:4-8` · `screens/discover_screen.dart:7,8` · `presentation/discover_screen.dart:2` · `test/unit/features/quran/layer_unlock_logic_test.dart:6`

⚠️ **`test/widget_test.dart:11` imports `package:ummahapp/main.dart` and is already broken today** — it predates the package rename to `taddabur`.

### User-visible strings

- `lib/app.dart:52` — `title: 'Taddabur'` (app switcher / task manager)
- `lib/features/settings/presentation/more_screen.dart:31,46,54` — "How Taddabur Works", "About Taddabur", `applicationName`
- `lib/features/settings/presentation/more_content_screens.dart:57,133,134,139,142` — including class `AboutTaddaburScreen` and the string `'تَدَبُّر — Taddabur'`
- `lib/core/router/app_router.dart:198` — `AboutTaddaburScreen()`
- `lib/features/settings/domain/notification_preferences_provider.dart:143,145,147,149` — four push notification bodies say "in Taddabur"
- Doc comments: `lib/main.dart:1`, `core/theme/app_theme.dart:1`, `app_colors.dart:1`, `app_typography.dart:1`
- `lib/l10n/app_en.arb` has **no** app-name key — add one so the name is localisable rather than hardcoded

### ⚠️ Persistent identifiers — renaming these destroys existing user data

Changing these strings makes the app look for a database that doesn't exist, silently orphaning everything the user has saved. **Either leave them as-is, or write a migration.**

- `lib/services/database/database_service.dart:26` — `'taddabur.db'`
- `lib/features/discover/data/discover_database.dart:12` — `'taddabur_discover_v2.db'`
- `lib/services/notifications/notification_service.dart:82` — notification channel id `'taddabur_daily'` (changing it silently kills already-scheduled notifications)

### Native platforms

**Android** — `android/app/src/main/AndroidManifest.xml:6` (`android:label="ummahapp"`) · `android/app/build.gradle.kts:8` (namespace), `:21` (`applicationId = "com.example.ummahapp"`) · `android/app/src/main/kotlin/com/example/ummahapp/MainActivity.kt:1` (package declaration **and** directory path)

**iOS** — `ios/Runner/Info.plist:10` (`CFBundleDisplayName`), `:18` (`CFBundleName`) · `ios/Runner.xcodeproj/project.pbxproj:386,402,419,434,567,589` (`PRODUCT_BUNDLE_IDENTIFIER`)

**macOS** — `macos/Runner/Configs/AppInfo.xcconfig:8,11` · `macos/Runner.xcodeproj/project.pbxproj:68,137,227,398,401,412,415,426,429` · `Runner.xcscheme:18,36,52,87,104`

**Web** — `web/manifest.json:2,3` · `web/index.html:26,32`

**Linux** — `linux/CMakeLists.txt:7,10` · `linux/runner/my_application.cc:48,52`

**Windows** — `windows/CMakeLists.txt:3,7` · `windows/runner/Runner.rc:93,95,97,98` · `windows/runner/main.cpp:30`

⚠️ `applicationId` / `PRODUCT_BUNDLE_IDENTIFIER` were `com.example.*`, which **cannot be published** to either store. Both are now `io.github.shahriyar31.mizan`.

### Infra and docs

`.env:1` · `.env.example:2,22` (`AZURE_SEARCH_INDEX_NAME=taddabur-knowledge-base`) · `supabase/migrations/001_initial_schema.sql:2` · `BUNDLE_run_in_sql_editor.sql:1,8` · `README.md` (5) · `PROJECT_CONTEXT.md` (3) · `setup_structure.sh` (16) · `tools/CONTENT_BRIEF_*.md` · 10 root `fix_*.py`/`generate_*.py` scripts · `.idea/modules.xml:5,6` and `ummahapp.iml` (rename the file itself)

One content string mentions the app name in prose — `assets/data/discover/seerah/first_revelation.json:263`. Probably intentional; review rather than bulk-replace.

### Brand assets — nothing custom exists

Every icon is the stock Flutter template:

- `android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` (15 PNGs)
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/` (7 PNGs)
- `web/favicon.png`, `web/icons/Icon-{192,512}.png`, `Icon-maskable-{192,512}.png`
- `windows/runner/resources/app_icon.ico`

**Splash is untouched default**: `android/app/src/main/res/drawable{,-v21}/launch_background.xml` are both `@android:color/white`, producing a white flash before a dark app. `flutter_native_splash` and `flutter_launcher_icons` are **not** in `pubspec.yaml` — add both to generate all sizes from one source image.

**`assets/` holds no imagery whatsoever** — only `assets/fonts/Amiri-*.ttf` and JSON data directories. A logo means adding an image path to `pubspec.yaml` from scratch.

---

## 7. Navigation

`lib/shared/widgets/app_shell.dart` wraps `ResponsiveCenter` in a `Scaffold` with a hand-rolled `_TadabburBottomNav` (note the misspelling) of custom `_NavItem`s rather than Material's `NavigationBar`. The active tab is derived by `location.startsWith()` against a const list at `app_shell.dart:29-35`.

**The nav has 5 items**: `/home`, `/quran`, `/discover`, `/halaqa`, `/minbar` — labelled HOME, QURAN, DISCOVER, HALAQA, MINBAR (`app_shell.dart:99-127`).

⚠️ **Growth is a tab with no tab.** `/growth` has a shell branch (`app_router.dart:121`) but no nav item, reachable only from `home_screen.dart:462` and `:1544`. Because `/growth` isn't in `_routes`, the index resolves to −1 and falls back to 0 — **so the nav highlights HOME while Growth is on screen.** Settings has the same defect. This is a navigation model decision the redesign has to settle: five tabs with Growth promoted from Home, or six tabs.

### Route map

`/quran/:surahNumber` · `/discover/{prophet,sahabi,seerah,name}/:id` · `/halaqa/circle/:halaqaId` · `/growth/{map,meezan,vocab,muhasabah}` · `/settings/{notifications,personalisation,audio,system,language,more}` with `/more/{faq,how-it-works,terms,privacy,about}` · `/auth`

---

## Recommended sequencing for the redesign

1. **Settle the navigation model first** (5 tabs vs 6, and where Growth lives). It's the highest-level decision and it constrains every screen layout below it.
2. **Introduce spacing/radius tokens** before restyling anything. Mechanical, low-risk, and it makes every later change one edit instead of many.
3. **Rename the colour tokens to role-based names** while replacing the palette, so `gold`-that-is-blue can't recur. Do this as one mechanical commit across all 261 references, separate from any visual change, so the diff is reviewable.
4. **Build the missing shared components** (card, section header, empty state, loading/error) and delete the four dead widgets. This collapses the 147 ad hoc `BoxDecoration`s and the 6 duplicate empty states.
5. **Rewrite `home_screen.dart` and `layer_screen.dart`** rather than restyling them — they opt out of the system so thoroughly that patching costs more than replacing.
6. **Do the rename as its own commit series**, native platforms included, and decide the persistent-identifier question deliberately (leave DB/channel names, or migrate).
7. **Add brand assets last**, once the name is locked: `flutter_launcher_icons` + `flutter_native_splash` from a single source logo, and fix the white splash flash.
