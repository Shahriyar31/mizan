# Mizan — icons & logo assets

Everything here is already cut and in the project. Read this before wiring a single icon.

## What exists

```
assets/
  icons/                  1x, 32px   ← reference in code as assets/icons/<name>.png
    2.0x/                 2x, 64px   ← Flutter resolves these itself
    3.0x/                 3x, 96px
    master/               ~300px originals — DO NOT ship
    dark/                 gold set for the navy theme
      2.0x/  3.0x/  master/
  logo/
    mizan_classic.png     900×1046, rounded corners already transparent
    mizan_midnight.png
    mizan_light.png
    mizan_emerald.png
    mizan_plum.png
    mizan_lockup.png      900×992, the full "Mizan AI Assistant" mark
    square/               same six, opaque, padded to square — for launcher icons
```

Ten icons, two themes, identical filenames in both:

`home` · `discover` · `quran` · `halaqa` · `minbar` · `hadith` · `prophet` · `sahaba` · `names99` · `settings`

The five tab icons are `home`, `quran`, `discover`, `halaqa`, `minbar`.

## Rules — these are not preferences

1. **Never tint them.** No `color:`, no `ColorFiltered`, no `Icon()` substitution. Each icon is two-colour artwork (teal + gold, or gold + cream in the dark set); tinting collapses it to one flat shape.
2. **Never substitute a Material icon** because a name looks missing. All ten exist. If you need an eleventh, stop and ask.
3. **Logo tiles are not square** — 900×1046, and the lockup 900×992. Use `BoxFit.contain` or set one dimension only. A square box squashes the book at the bottom of the mark.
4. **`master/` stays out of the bundle.** Don't list it in `pubspec.yaml`.

## pubspec.yaml

The density folders are a Flutter convention: declare the 1x path and the framework picks `2.0x` / `3.0x` by device pixel ratio.

```yaml
flutter:
  assets:
    - assets/icons/
    - assets/icons/2.0x/
    - assets/icons/3.0x/
    - assets/icons/dark/
    - assets/icons/dark/2.0x/
    - assets/icons/dark/3.0x/
    - assets/logo/
    - assets/logo/square/
```

## Theme switching

Two sets, same names, so the theme only changes one path segment:

```dart
String mizanIcon(BuildContext context, String name) =>
    Theme.of(context).brightness == Brightness.dark
        ? 'assets/icons/dark/$name.png'
        : 'assets/icons/$name.png';
```

The dark set is the teal ink remapped to gold `#D8B45A`, with the original gold accents remapped to cream `#F3EDE0` — so the artwork stays two-tone on navy instead of flattening into one gold silhouette. On the cream theme the teal set reads at full strength; using the light set on navy makes the teal disappear, so don't shortcut the switch.

## Active tab state

The icons are **one state each** — there is no filled variant. The active tab is carried by three cues:

| | Active | Inactive |
|---|---|---|
| Icon | opacity **1.0** | opacity **0.52** |
| Label | 700 weight, `#0F3B4C` light / `#F3EDE0` dark | 400 weight, `#5A7684` light / `#A9BFC9` dark |
| Under label | 5px gold diamond, `rotate(45°)` — `#D4AF37` light / `#D8B45A` dark | empty 5px spacer so nothing shifts |

**The opacity goes on the image only, never on the whole tab column.** Fading the column drags the label down with it — a 10px label at 52% lands around 2:1 contrast and fails WCAG. This is the one mistake to avoid here.

```dart
Widget tab(BuildContext context, String name, String label, bool selected) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Opacity(                                   // image only
        opacity: selected ? 1.0 : 0.52,
        child: Image.asset(mizanIcon(context, name), width: 27, height: 27),
      ),
      const SizedBox(height: 5),
      Text(label, style: TextStyle(
        fontSize: 10,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        color: selected
            ? (dark ? const Color(0xFFF3EDE0) : const Color(0xFF0F3B4C))
            : (dark ? const Color(0xFFA9BFC9) : const Color(0xFF5A7684)),
      )),
      const SizedBox(height: 5),
      SizedBox(
        width: 5, height: 5,
        child: selected
            ? Transform.rotate(
                angle: 0.7854,
                child: ColoredBox(color: dark
                    ? const Color(0xFFD8B45A) : const Color(0xFFD4AF37)),
              )
            : null,
      ),
    ],
  );
}
```

Don't add a filled pill or circle behind the active icon. The artwork is already detailed and two-coloured; a container behind it turns the bar into noise.

## Launcher icon

Use `assets/logo/square/…` — iOS and Android both want a full-bleed opaque square and apply their own mask. The rounded versions in `assets/logo/` are for **in-app** use (splash, settings header, about screen), where the transparent corners are what you want.

```yaml
flutter_launcher_icons:
  image_path: "assets/logo/square/mizan_classic.png"
  android: true
  ios: true
  remove_alpha_ios: true
```

The in-app corners are cut at **22.37% of the width** — the iOS squircle ratio. Don't wrap them in another `ClipRRect` with a different radius or you'll get a visible double-rounded edge.

## Why PNG and not SVG

The source art is raster: soft gradients, layered shadows, real calligraphy. Tracing it would either band the gradients or produce a several-hundred-node path that renders slower than the PNG. SVG only wins for flat line work you intend to tint at runtime — and rule 1 says these are never tinted.

## Two things to raise rather than guess

- **A disabled or locked state.** If a tab or collection can be gated, ask for a third variant at reduced saturation instead of fading it in code on top of the inactive opacity.
- **Notification badges.** The icons have no reserved corner, so a badge must sit outside the 27px box. Ask before improvising placement.
