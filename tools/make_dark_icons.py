#!/usr/bin/env python3
"""Bake assets/icons/dark/ from assets/icons/.

The asset README describes the dark set as "the teal ink remapped to gold
#D8B45A, with the original gold accents remapped to cream #F3EDE0" — but the
folder was never cut, so this script is that sentence made executable.

Why bake it rather than tint at runtime: README rule 1 forbids `color:` and
`ColorFiltered` outright, because these icons are two-colour artwork and a
runtime tint collapses both families onto one flat shape. A tint cannot send
teal to gold *and* gold to cream in the same pass; only two separate files can.

Why remap the shipped 1x/2x/3x rather than re-render from master/: the shipped
PNGs are already downsampled and hinted at each density. Recolouring those
exact pixels means the dark set has identical geometry and identical
anti-aliasing to the light set, so the tab bar does not shift by a subpixel
when the theme changes.

Gradients survive because the remap is a *ramp*, not a fill: each pixel keeps
its position within its own family's brightness range, and that position is
replayed against the target colour. Flattening every teal pixel to one gold
would erase the modelling the artwork carries.

Run from the package root:  python3 tools/make_dark_icons.py
"""

import colorsys
import os
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit("Pillow is required: pip install --break-system-packages pillow")

NAMES = [
    "home", "discover", "quran", "halaqa", "minbar",
    "hadith", "prophet", "sahaba", "names99", "settings",
]
DENSITIES = ["", "2.0x", "3.0x"]

GOLD = (0xD8, 0xB4, 0x5A)   # what the teal ink becomes
CREAM = (0xF3, 0xED, 0xE0)  # what the gold accents become

# The ramp each family is replayed across, as a multiple of the target colour.
# Teal is the *dark* ink in the light set and gold is the dark ink in the dark
# set, so the wider ramp stays on the ink and the narrower one on the accent —
# the relative ordering of the two families is preserved, not inverted.
#
# Both ramps are deliberately shallow. The source teal spans a wide brightness
# range, and replaying that full range against gold sent most of the ink to a
# dim olive: fine at 96px on white, muddy at 27px on navy and worse again at the
# 52% the inactive tab uses. A shallow ramp keeps the bulk of the ink at
# #D8B45A, where it was specified, and spends the remainder on shading.
INK_RAMP = (0.84, 1.00)
ACCENT_RAMP = (0.90, 1.00)

# Alpha below this is anti-aliasing so faint that its hue is unreliable; it is
# remapped with the ink ramp rather than classified.
FAINT_ALPHA = 24


def family(r, g, b):
    """'ink' (teal), 'accent' (gold), or 'neutral'."""
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    hue = h * 360
    if s < 0.12:
        return "neutral", v
    if 20 <= hue < 75:
        return "accent", v
    if 150 <= hue < 240:
        return "ink", v
    # Nothing in the shipped art lands here; treat it as ink so a stray pixel
    # is never left teal on a navy ground.
    return "ink", v


def span(values):
    """Robust brightness range — 2nd to 98th percentile, so one stray light
    pixel does not compress the whole ramp."""
    if not values:
        return 0.0, 1.0
    values = sorted(values)
    lo = values[int(0.02 * (len(values) - 1))]
    hi = values[int(0.98 * (len(values) - 1))]
    if hi - lo < 1e-3:
        return lo, lo + 1e-3
    return lo, hi


def remap(src_path, dst_path):
    im = Image.open(src_path).convert("RGBA")
    px = im.load()
    w, h = im.size

    classified = {}
    brightness = {"ink": [], "accent": [], "neutral": []}
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            fam, v = family(r, g, b)
            if a < FAINT_ALPHA:
                fam = "ink"
            classified[(x, y)] = (fam, v, a)
            brightness[fam].append(v)

    spans = {k: span(vs) for k, vs in brightness.items()}

    for (x, y), (fam, v, a) in classified.items():
        if fam == "neutral":
            # A handful of pixels per icon. Bright ones are highlight, dark
            # ones are shadow on the ink; send each to the nearer family.
            fam = "accent" if v > 0.60 else "ink"
        lo, hi = spans[fam] if brightness[fam] else (0.0, 1.0)
        t = (v - lo) / (hi - lo)
        t = 0.0 if t < 0.0 else (1.0 if t > 1.0 else t)
        target = GOLD if fam == "ink" else CREAM
        r0, r1 = INK_RAMP if fam == "ink" else ACCENT_RAMP
        k = r0 + (r1 - r0) * t
        px[x, y] = (
            min(255, round(target[0] * k)),
            min(255, round(target[1] * k)),
            min(255, round(target[2] * k)),
            a,
        )

    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    im.save(dst_path, optimize=True)
    return im.size


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    icons = os.path.join(root, "assets", "icons")
    if not os.path.isdir(icons):
        sys.exit("assets/icons not found — run this from the package root")

    written = 0
    for density in DENSITIES:
        for name in NAMES:
            src = os.path.join(icons, density, name + ".png")
            dst = os.path.join(icons, "dark", density, name + ".png")
            if not os.path.isfile(src):
                sys.exit("missing source icon: " + src)
            size = remap(src, dst)
            written += 1
            print("%-28s %s" % (os.path.relpath(dst, root), "x".join(map(str, size))))
    print("\n%d dark icons written" % written)


if __name__ == "__main__":
    main()
