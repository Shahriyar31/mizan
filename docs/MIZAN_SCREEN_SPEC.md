# MIZAN — Screen Build Spec

**Read this whole file before writing a line of Dart.** It is the contract for the
eight-screen rebuild. Every value in it comes from the user's `Mizan Tokens.pdf`,
`Mizan Light.pdf` and `Mizan Dark.pdf`, which are authoritative: *"the eight-screen
light and dark sets use only these tokens."*

---

## 0. The one command that matters

You can type-check this project yourself. **Do it before you hand anything back.**

```bash
bash /sessions/<session>/mnt/develop/ummahapp/tools/analyze.sh lib/features/<your_feature>
```

Substitute your actual session directory (the parent of `mnt/`). It mirrors `lib/` to
`/tmp` with sandbox-resolvable package paths and runs the real Dart analyzer. **Target:
zero `error -` lines in the files you touched.** `info -` lint suggestions are noise;
triage but don't chase them.

Do **not** run `flutter run`, `flutter build`, or `flutter pub get` — there is no network
and no display in the sandbox. You cannot see your screen render. Get layout right by
reasoning about constraints, not by looking.

---

## 1. Never invent Islamic content

This is the hardest rule in the project and it outranks visual fidelity.

Every scholarly claim needs a real citation: a Quran surah:ayah, a hadith with
collection + number + grade, or a named tafseer. If you need a fact and you do not have a
verified source for it, **you do not write the fact.** You either bind the widget to
existing sourced data in `assets/data/**`, or you build an honest empty state that says
there is nothing there yet.

Mockups contain placeholder copy. Placeholder copy is not a source. If the mockup shows a
hadith and you cannot find that hadith in the repo's assets, render the card bound to
whatever real data exists and note the gap in your hand-back report. **Never fabricate an
ayah, a hadith, a grade, a narrator, a date in the seerah, or an attribution.**

The same applies to numbers presented as facts — "2.3M reciters", "18 comments",
"streak: 47". If the app cannot compute it, it does not get displayed.

---

## 2. Product rules that override the mockups

These come from the user directly and beat anything drawn in a PDF.

- **Halaqa** — circles of 2–8 members, joined by invite code. A share may carry **one
  optional note of at most 100 characters**. Members respond with exactly three
  reactions: Du'a 🤲, Resonated 💙, Moved ✨. **There are no text replies, ever.** The
  "nudge" feature alerts *a circle member* to check in — it never notifies the person who
  drifted that they were noticed.
- **Minbar** — a public feed with reactions. **No comments.** The light-theme Minbar
  mockup shows a comment bubble with a count of 18; the user has confirmed the rule wins.
  **Omit the comment bubble entirely.** Do not build a disabled one.
- **No scoring of deeds** (Rule #4 below). Nothing totals, ranks, grades, or congratulates.

---

## 3. The seven non-negotiable design rules

1. **Gold is trim, not ink.** On cream, gold appears only as a fill, a 1px rule, or the
   diamond glyph. Gold *text* on cream must be bronze `#9A7B2F` — that is `p.accentText`.
   On navy, gold is free to be text.
2. **One image per screen, maximum.** Illustration is a hero device, never card
   decoration. Everything else uses the arch outline (`MizanArch`), a 5%-opacity pattern,
   or nothing.
3. **Theme is global.** Every screen must exist in both light and dark. No screen is
   permanently dark. This falls out of using the palette instead of literal colours.
4. **No scoring of deeds.** The Mizan strip records what you engaged with today; it never
   totals, ranks, or grades. No "+1", no percentage, no verdict.
5. **Content clears the tab bar.** Every scroll view ends with `MizanGeometry.scrollBottomPadding`
   (96px) of bottom padding.
6. **Arabic is never decoration.** Amiri, right-aligned, line-height ≥1.9, `TextDirection.rtl`,
   and **always** paired with a transliteration or a translation in the same card.
7. **One grey per theme.** `p.muted` is the only secondary text colour, for every tier
   including nav labels. There is no third grey.

---

## 4. Hard prohibitions

- **Zero literal colours.** No `Color(0x...)`, no `Colors.blue`, no hex anywhere in
  presentation code. The single legal exception is `Colors.transparent`. Everything else
  comes off `MizanPalette`. If you think you need a shade that isn't in the palette, you
  are wrong — use the nearest token or say so in your report.
- **Never import `core/theme/app_colors.dart`.** That is the dead legacy palette. If the
  file you are rebuilding imports it, removing that import is part of your job.
- **Never hardcode a font family or call `GoogleFonts` directly.** Use `MizanType`.
- **Do not touch files you do not own** (§6). Another agent is editing them right now.

---

## 5. The API you build with

### Palette — `core/theme/mizan_tokens.dart`

```dart
final p = MizanPalette.of(context);
```

| Field | Light | Dark | Use |
|---|---|---|---|
| `p.page` | `#FAF6EE` | `#0A2233` | Scaffold background, tab bar |
| `p.card` | `#FFFDF7` | `#0F3B4C` | Raised surfaces, list rows |
| `p.sunk` | `#EADCC8` | `#14495C` | Search fields, inset wells, chips |
| `p.hairline` | `#E3D6BE` | gold @18% | Every 1px border and rule |
| `p.ink` | `#0F3B4C` | `#F3EDE0` | Primary text, filled CTAs |
| `p.muted` | `#5A7684` | `#A9BFC9` | **The only** secondary text colour |
| `p.accent` | `#D4AF37` | `#D8B45A` | Gold **fills, rules, diamonds** |
| `p.accentText` | `#9A7B2F` bronze | `#D8B45A` gold | Gold-family **text**. Rule #1 lives here. |
| `p.link` | `#1E5C72` | `#7FB0C6` | Links, selected states, section labels |
| `p.sage` | `#7F9D8C` | `#8FB3A1` | Growth and success **only** |
| `p.onFilled` | — | — | Label colour on a primary-filled button |
| `p.restShadow` / `p.pressShadow` | — | — | Neumorphic shadow lists |
| `p.isLight` | — | — | Branch when the two themes genuinely differ |

### Type — `core/theme/mizan_typography.dart`

All are `static TextStyle fn({Color? color})`; pass the colour explicitly every time.

| Call | Spec |
|---|---|
| `MizanType.screenTitle()` | Playfair Display 600 · 32/37 · -0.01em |
| `MizanType.cardHeadline()` | Playfair Display 600 · 23/29 |
| `MizanType.translation()` | **Playfair italic 400 · 17/26** — every translation and sub-prompt |
| `MizanType.body()` | DM Sans 400 · 15/24 |
| `MizanType.bodyStrong()` | DM Sans 600 — list titles |
| `MizanType.sectionLabel()` | DM Sans 700 · 11 · 0.16em uppercase |
| `MizanType.arabic({double fontSize = 30})` | Amiri 400 · 1.9 line-height |
| `MizanType.button()` | DM Sans, CTA labels |
| `MizanType.navLabel()` | DM Sans 600 · 11 |

Size overrides go through `.copyWith(fontSize: …)` — never a raw `TextStyle`.

### Geometry — `MizanGeometry`

`gutter` 20 · `cardPadding` 20 · `cardPaddingTight` 18 · `gap` 14 · `cardRadius` 18 ·
`rowRadius` 14 · `pillRadius` 999 · `tapTarget` 44 · `tabBarHeight` 64 ·
`scrollBottomPadding` 96 · `hairlineWidth` 1 · `cardBorderRadius` · `rowBorderRadius` ·
`pagePadding`.

### Components — `shared/widgets/mizan/mizan_components.dart`

Use these before writing a `Container`. If you find yourself styling a raw box, a
component already exists.

- **`MizanSurface`** — the card. `{child, tone, padding, radius, showBorder, onTap}`.
  Passing `onTap` makes it a raised touchable; leaving it null keeps it flat with a
  hairline, which is what Rule "stays flat" wants for text-only cards.
- **`MizanTone`** — `page` · `card` · `sunk` · `inverse`. `inverse` is **a navy panel in
  both themes** — the Today's Thread hero and the Halaqa quote card. On light it is the
  one dark surface on screen; on dark it is a normal card. Its helpers
  `tone.resolve(p)`, `.onColor(p)`, `.mutedOn(p)`, `.hairlineOn(p)`, `.accentTextOn(p)`
  give you correctly-inverted colours — **use them instead of branching by hand.**
- **`MizanButton`** — `{label, onPressed, kind, icon, trailingIcon, selected, expand, onInverse}`.
  `MizanButtonKind`: `primary` (ink fill/cream label on light; gold fill/navy label on
  dark) · `secondary` (outline) · `quiet` (sunk fill light, raised fill dark) · `chip`
  (full-radius outline, smaller type — filters and layer tabs). Set `onInverse: true`
  when the button sits on a `MizanTone.inverse` panel.
- **`MizanIconTile`** — the round/rounded icon button. `{icon, onTap, size, iconSize,
  circle, tone, iconColor, filled, semanticLabel, badge}`.
- **`MizanRow`** — a list row. `{title, subtitle, leading, trailing, onTap, showChevron,
  tone, footer}`.
- **`MizanSectionLabel`** — the uppercase tracked label. `{text, color, onInverse}`.
- **`MizanRule`** — a 1px hairline. `{color, indent}`.
- **`MizanDiamond`** — the gold diamond glyph. `{size = 7, filled, color}`. Lays out at
  `size * 1.42`; reserve that box when toggling one on and off so nothing shifts.
- **`MizanArch`** — the mihrab arch outline, for backgrounds only. `{color, strokeWidth,
  opacity, rings}`. This is how you add visual interest without breaking Rule #2.
- **`MizanPressable`** (`mizan_pressable.dart`) — the tactile primitive under everything
  above. `{child, onTap, onLongPress, borderRadius, fill, border, padding,
  shadowsEnabled, semanticLabel}`. Reach for it only when no component fits. Pass
  `fill: Colors.transparent, shadowsEnabled: false` for something that must stay flat but
  still respond.
- **Logo** (`mizan_logo.dart`) — `MizanMark`, `MizanGlyph`, `MizanWordmark`,
  `MizanTagline`, `MizanLogo`, `MizanLogoRow`.

### Shadows — who gets depth

Gets the neumorphic treatment: buttons, icon tiles, chips, tappable list rows, tab-bar
items, the compose button, audio controls. **Stays flat with a hairline and no shadow:**
ayah cards, the Thread hero, feed posts, section wells — anything that only holds text.
Press nudges 1px down over 130ms. **Depth never carries meaning** — a selected or
disabled state must also read through colour, border, or label.

---

## 6. File ownership — do not cross these lines

Seven agents are working in parallel. Touching another agent's file will lose work.

| Agent | Owns | Mockup |
|---|---|---|
| Quran | `features/quran/presentation/quran_screen.dart` | `02-quran-{light,dark}.png` |
| Reader | `features/quran/presentation/ayah_detail_screen.dart` | `03-reader-{light,dark}.png` |
| Discover | `features/discover/screens/discover_screen.dart` (the `presentation/` file of the same name is a 2-line re-export — leave it alone) | `04-discover-{light,dark}.png` |
| Halaqa | `features/halaqa/presentation/halaqa_screen.dart` | `05-halaqa-{light,dark}.png` |
| Minbar | `features/minbar/presentation/minbar_screen.dart` | `06-minbar-{light,dark}.png` |
| Growth | `features/growth/presentation/growth_screen.dart` | `07-growth-{light,dark}.png` |
| Settings | `features/settings/presentation/settings_screen.dart` | `08-settings-{light,dark}.png` |

You may also create **new** files inside your own feature folder (a `widgets/`
subdirectory, a domain provider). Name them distinctly.

**Owned by nobody — read freely, never edit:**
`core/theme/**` · `shared/widgets/mizan/**` · `shared/widgets/app_shell.dart` ·
`shared/widgets/responsive.dart` · `core/router/app_router.dart` ·
`features/home/**` · `features/onboarding/**` · `main.dart` · `app.dart` · `pubspec.yaml`

If your screen needs a router change, an asset declaration, or an edit outside your
folder, **do not make it** — describe it in your report and it will be applied centrally.

---

## 7. The reference implementation

`features/home/presentation/home_screen.dart` is already rebuilt to this standard and
analyzes clean. **Read it first.** Copy its conventions: a `StatelessWidget` screen over a
`ListView` with `MizanGeometry` padding, small private `_Widget` classes per card,
`ConsumerWidget` only where a provider is actually watched, and doc comments that explain
*why* a choice was made — especially where the implementation deviates from the mockup and
what would have to become true to change it back.

Match its commenting depth. A future reader must be able to tell an intentional deviation
from a bug.

---

## 8. What to hand back

Keep it short and specific. Prose, no filler.

1. Files created or modified.
2. The analyzer result for your feature — paste the tail. Zero errors, or explain.
3. **Every deviation from the mockup**, with the reason. Especially: anything the mockup
   showed that you could not build honestly because the data or the citation does not
   exist.
4. Anything you needed outside your ownership (a route, an asset, a provider) — as a
   precise request, not a change.
5. Open questions for the user, if any. One line each.
