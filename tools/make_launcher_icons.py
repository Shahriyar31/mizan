#!/usr/bin/env python3
"""Bake the Android and iOS launcher icons from assets/logo/square/.

Why a script and not `flutter_launcher_icons`: adding that package to fetch and
run, to produce twenty-odd PNGs that are then committed anyway, buys nothing over
doing the resize here — and this way the icons regenerate with no network and no
pub resolution. The config the asset README suggests is honoured to the letter:

    image_path: "assets/logo/square/mizan_midnight.png"
    android: true
    ios: true
    remove_alpha_ios: true

Why the *square* tile and not the rounded one: both platforms apply their own
mask. Handing them art whose corners are already cut rounds the corner twice —
visible as a pale notch inside the system mask on Android, and on iOS as an
opaque black corner once the alpha is flattened.

Two Android shapes are produced from the same source:

  ic_launcher.png             the legacy square, full-bleed, for API < 26.
  ic_launcher_foreground.png  the adaptive foreground. Android renders this on a
                              108dp canvas but only the centre 72dp is
                              guaranteed visible — the outer 18dp on each side is
                              reserve the launcher may crop, rotate or parallax.
                              So the mark is inset to that safe zone, and the
                              field colour moves to the <background> drawable
                              instead of travelling in the bitmap.

Run from the package root:  python3 tools/make_launcher_icons.py

That bakes **Midnight** — the shipped launcher icon. To bake a different variant,
name it: `python3 tools/make_launcher_icons.py classic`, or pass a path outright.
Whichever tile is used, the adaptive background colour printed at the end has to
be copied into values/mizan_colors.xml by hand, or the background and the bitmap
disagree.
"""

import json
import os
import sys
from collections import deque

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit("Pillow is required: pip install --break-system-packages pillow")

SQUARE_DIR = os.path.join("assets", "logo", "square")

# A pixel counts as "near-white" when it is opaque and all three channels clear
# this. The Midnight tile's four corner wedges sit at ~254; the navy field and
# the gold calligraphy are nowhere near it, so this cleanly separates the defect
# from the art. Deliberately generous (228, not 250) so the anti-aliased skirt of
# each wedge is caught too and no pale fringe survives the resize.
NEAR_WHITE = 228

# Midnight, not Classic: this is the mark the launcher wears, and the in-app
# default in mizan_brand.dart is Midnight to match it.
DEFAULT_VARIANT = "midnight"


def resolve_source(argv):
    """The square tile to bake from — [1] as a variant name or a path."""
    if len(argv) < 2:
        return os.path.join(SQUARE_DIR, "mizan_%s.png" % DEFAULT_VARIANT)
    arg = argv[1]
    if arg.endswith(".png") or os.sep in arg:
        return arg
    return os.path.join(SQUARE_DIR, "mizan_%s.png" % arg)

# Legacy launcher bitmap: 48dp at each density.
ANDROID_LEGACY = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Adaptive foreground: the full 108dp canvas at each density.
ANDROID_ADAPTIVE = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}

# 72/108 — Android's documented safe-zone *square*, the region content is
# required to stay inside. The narrower guarantee is a 66dp circle, and 66 was
# the first value used here; it left visibly timid padding on a circular mask,
# because the artwork's calligraphy is already inset from its own tile edges, so
# a 66dp box put the visible mark at roughly 61/108 of the canvas. At 72 the only
# thing a 66dp circle can reach is the tile's four transparent corners, which
# carry nothing. Verified against circle, squircle and square masks.
SAFE_ZONE = 72.0 / 108.0

# The iOS set already on disk, by filename. Kept exactly as-is so Contents.json
# does not have to change.
IOS_SIZES = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}


def field_colour(im):
    """The tile's own background, read from a corner rather than hardcoded, so
    changing the source variant changes the adaptive background with it."""
    return im.convert("RGB").getpixel((2, 2))


def is_near_white(pixel):
    """Opaque and pale enough to be the white backing rather than the art."""
    r, g, b, a = pixel
    return a > 200 and r > NEAR_WHITE and g > NEAR_WHITE and b > NEAR_WHITE


def luminance(r, g, b):
    """Rec.601 luma — only ever used to compare a pixel against the field."""
    return 0.299 * r + 0.587 * g + 0.114 * b


# How much brighter than the field a pixel must be to count as part of the
# wedge's anti-aliased skirt. Small, because the skirt runs all the way down to
# the field colour and the point is to catch the whole ramp; the containment
# comes from connectivity, not from this number.
SKIRT_TOLERANCE = 20


def near_white_bounds(px, size):
    """Bounding box of every near-white pixel, or None if there are none.

    This is how the white backing's geometry is *derived* rather than assumed.
    On the Midnight tile it comes back as x[73,972] y[0,1045] — a 900x1046 band,
    which is the portrait asset's own footprint centred in the 1046 square with a
    73px field margin left and right and none top or bottom. Scanning for it
    means the same step still finds the backing if the source is switched to a
    variant with different padding, or if the artwork is ever re-exported at a
    different size.
    """
    w, h = size
    x0 = y0 = x1 = y1 = None
    for y in range(h):
        for x in range(w):
            if is_near_white(px[x, y]):
                if x0 is None or x < x0:
                    x0 = x
                if x1 is None or x > x1:
                    x1 = x
                if y0 is None or y < y0:
                    y0 = y
                if y1 is None or y > y1:
                    y1 = y
    if x0 is None:
        return None
    return x0, y0, x1, y1


# How far from each corner of the backing's bounding box to look for seeds, as a
# fraction of its shorter side. The Midnight wedge is ~156px across at its widest
# and has closed by ~135px in, so 0.15 of 900 = 135px reaches all of it including
# the few anti-aliased specks that are not 8-connected to the main body. Kept
# deliberately well below 0.25: at 0.25 the seed boxes on the Emerald and Plum
# tiles start landing on the *cream* book at the bottom corners, and the fill then
# walks up the calligraphy.
SEED_REACH = 0.15


def strip_corner_white(im, bg):
    """Fill the white wedges in the square tile's four corners with the field.

    ── The defect ────────────────────────────────────────────────────────
    The square tiles are built in three layers, outside in: a field-coloured
    margin, then an opaque WHITE rectangle the size of the portrait asset, then
    the rounded artwork tile on top of that. Because the artwork's corners are
    rounded but the white rectangle under it is a hard rectangle, the white shows
    through as four corner wedges. Those wedges are what put a white border on the
    corners of the generated launcher icon, and no amount of resizing removes
    them — they have to go before the resize, or LANCZOS just smears them.

    ── Why a flood fill and not "replace every near-white pixel" ─────────
    A blanket replace would be a trap. On the Midnight tile it happens to be
    equivalent, because the calligraphy is gold and nothing else in the picture is
    pale. But the Emerald and Plum tiles have *cream* calligraphy and a cream
    book, ~76,000 near-white pixels of real art each, and a blanket replace would
    eat all of it. So this seeds only inside the four corners of the white
    backing and fills the connected component from there: art in the middle of the
    picture is unreachable from a corner seed and therefore safe by construction.

    ── The pale-field guard ──────────────────────────────────────────────
    Two variants have a field that is itself near-white — Light (#FFFFFE) and
    Classic (#FDFAEC). On those the corner seeds would be indistinguishable from
    the field, the flood would escape across the whole tile, and the icon would be
    erased. There is also nothing to strip: a white wedge on a white field is
    invisible. So when the sampled field is near-white this returns without
    touching a pixel and says so.

    ── Why the anti-aliased skirt has to go too ──────────────────────────
    Clearing only the near-white pixels leaves a ~10px ramp tracing each wedge,
    grey fading from the field up to the 228 threshold. That ramp is still visibly
    pale — and worse, LANCZOS has negative lobes, so downscaling the hard
    field/ramp edge it leaves behind *rings back above* 228 and near-white pixels
    reappear in the output corners even though the source no longer had any. That
    is not theoretical: before this second stage the 1024 iOS icon came out with
    422 near-white corner pixels. So stage two grows the fill outward through
    every pixel brighter than the field that connects to what stage one cleared,
    absorbing the whole ramp. Connectivity still contains it — the ramp touches
    only the wedge, and the artwork tile's interior is *darker* than the field,
    which moats the calligraphy off.

    Returns the number of pixels changed.
    """
    if is_near_white(tuple(bg) + (255,)):
        print("  strip: skipped — field #%02X%02X%02X is itself near-white, so "
              "there is no wedge to see and a corner-seeded fill would escape "
              "across the whole tile" % bg)
        return 0

    w, h = im.size
    px = im.load()
    bounds = near_white_bounds(px, im.size)
    if bounds is None:
        print("  strip: no near-white pixels — nothing to do")
        return 0

    x0, y0, x1, y1 = bounds
    reach = max(4, round(SEED_REACH * min(x1 - x0 + 1, y1 - y0 + 1)))

    # Seeds: near-white pixels inside a `reach`-sized box at each of the four
    # corners of the backing's bounding box. Nothing in the middle is ever a seed.
    seeds = []
    for cx, cy in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        xa, xb = (cx, cx + reach) if cx == x0 else (cx - reach, cx)
        ya, yb = (cy, cy + reach) if cy == y0 else (cy - reach, cy)
        for y in range(max(0, ya), min(h, yb + 1)):
            for x in range(max(0, xa), min(w, xb + 1)):
                if is_near_white(px[x, y]):
                    seeds.append((x, y))

    # 8-connectivity, so a wedge joined to its own anti-aliased skirt only
    # diagonally is still one component.
    fill = tuple(bg) + (255,)
    seen = bytearray(w * h)
    queue = deque()
    for x, y in seeds:
        i = y * w + x
        if not seen[i]:
            seen[i] = 1
            queue.append((x, y))

    changed = 0
    core = deque()
    while queue:
        x, y = queue.popleft()
        px[x, y] = fill
        changed += 1
        core.append((x, y))
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h:
                    j = ny * w + nx
                    if not seen[j] and is_near_white(px[nx, ny]):
                        seen[j] = 1
                        queue.append((nx, ny))

    wedge = changed

    # Stage two: absorb the wedge's anti-aliased skirt. Seeded strictly from the
    # pixels stage one cleared — not from the whole field-coloured margin, which
    # would let any pale pixel anywhere along the tile's edge be swallowed.
    field_lum = luminance(*bg)
    while core:
        x, y = core.popleft()
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h:
                    j = ny * w + nx
                    if seen[j]:
                        continue
                    r, g, b, a = px[nx, ny]
                    if a > 200 and luminance(r, g, b) > field_lum + SKIRT_TOLERANCE:
                        seen[j] = 1
                        px[nx, ny] = fill
                        changed += 1
                        core.append((nx, ny))

    print("  strip: white backing bbox x[%d,%d] y[%d,%d] (%dx%d), seed reach %dpx"
          % (x0, x1, y0, y1, x1 - x0 + 1, y1 - y0 + 1, reach))
    print("  strip: filled %d px with #%02X%02X%02X — %d near-white wedge + %d "
          "anti-aliased skirt (%.2f%% of canvas)"
          % ((changed,) + tuple(bg)
             + (wedge, changed - wedge, 100.0 * changed / (w * h))))
    return changed


def main():
    source = resolve_source(sys.argv)
    if not os.path.isfile(source):
        sys.exit("missing " + source + " — run this from the package root")

    src = Image.open(source).convert("RGBA")
    bg = field_colour(src)
    print("source %s  %sx%s  field #%02X%02X%02X" % ((source,) + src.size + bg))

    # Remove the white corner wedges before anything is resized. Every Android
    # mipmap and every iOS icon below is derived from `src`, so stripping here
    # fixes all 25 outputs at once, and does it on pixels the resize has not yet
    # blurred. The brand PNGs under assets/logo/ are left untouched — the strip
    # lives here so the source files other code renders are not edited.
    strip_corner_white(src, bg)

    res = os.path.join("android", "app", "src", "main", "res")

    for folder, px in ANDROID_LEGACY.items():
        out = os.path.join(res, folder, "ic_launcher.png")
        # Flattened onto the field colour: a legacy icon has no mask behind it,
        # so any alpha here shows the launcher wallpaper through the tile.
        tile = Image.new("RGB", (px, px), bg)
        scaled = src.resize((px, px), Image.LANCZOS)
        tile.paste(scaled, (0, 0), scaled)
        tile.save(out, optimize=True)
        print("  %-46s %dx%d" % (out, px, px))

    for folder, px in ANDROID_ADAPTIVE.items():
        out = os.path.join(res, folder, "ic_launcher_foreground.png")
        inner = max(1, round(px * SAFE_ZONE))
        # Transparent canvas: the field colour is the <background> drawable, so
        # the launcher can parallax the two layers independently.
        canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
        canvas.alpha_composite(
            src.resize((inner, inner), Image.LANCZOS),
            ((px - inner) // 2, (px - inner) // 2),
        )
        canvas.save(out, optimize=True)
        print("  %-46s %dx%d (mark %d)" % (out, px, px, inner))

    ios = os.path.join("ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.isdir(ios):
        for name, px in IOS_SIZES.items():
            out = os.path.join(ios, name)
            # remove_alpha_ios: the App Store rejects an icon with an alpha
            # channel outright, so these are RGB with the field flattened in.
            tile = Image.new("RGB", (px, px), bg)
            scaled = src.resize((px, px), Image.LANCZOS)
            tile.paste(scaled, (0, 0), scaled)
            tile.save(out, optimize=True)
            print("  %-46s %dx%d" % (out, px, px))
        contents = os.path.join(ios, "Contents.json")
        with open(contents) as f:
            listed = {
                e["filename"] for e in json.load(f)["images"] if e.get("filename")
            }
        missing = listed - set(IOS_SIZES)
        if missing:
            print("\n!! Contents.json lists files this script does not write: "
                  + ", ".join(sorted(missing)))

    print("\nadaptive background colour should be #%02X%02X%02X "
          "(android/app/src/main/res/values/mizan_colors.xml)" % bg)


if __name__ == "__main__":
    main()
