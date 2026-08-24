#!/usr/bin/env python3
"""Bake the Android and iOS launcher icons from assets/logo/square/.

Why a script and not `flutter_launcher_icons`: adding that package to fetch and
run, to produce twenty-odd PNGs that are then committed anyway, buys nothing over
doing the resize here — and this way the icons regenerate with no network and no
pub resolution. The config the asset README suggests is honoured to the letter:

    image_path: "assets/logo/square/mizan_classic.png"
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
"""

import json
import os
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit("Pillow is required: pip install --break-system-packages pillow")

SOURCE = os.path.join("assets", "logo", "square", "mizan_classic.png")

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


def main():
    if not os.path.isfile(SOURCE):
        sys.exit("missing " + SOURCE + " — run this from the package root")

    src = Image.open(SOURCE).convert("RGBA")
    bg = field_colour(src)
    print("source %s  %sx%s  field #%02X%02X%02X" % ((SOURCE,) + src.size + bg))

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
