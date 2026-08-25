#!/usr/bin/env python3
"""Generate the PWA icon set from the Midnight tile.

Run:  python3 tools/make_web_icons.py

Reuses `make_launcher_icons.py` rather than reimplementing it. That file already
solved the one hard problem in this artwork — the four white corner wedges left by
the way the square tiles are composited — and solved it with a corner-seeded flood
fill plus an anti-aliasing-skirt pass, after a blanket near-white replace was
found to eat the cream calligraphy on other variants. Copying a simplified version
of that here would mean the web icons regain a white fringe the launcher icon does
not have, and nobody would notice until the icon was on a home screen.

── What the four sizes are actually for ──────────────────────────────────

Every one of these exists for a different consumer, and they are not
interchangeable:

  Icon-192 / Icon-512        `purpose: any`. Browser install prompts, the Android
                             task switcher, the Chrome "Add to Home screen" sheet.
                             Drawn with the field's own margin, so the tile looks
                             like the tile.

  Icon-maskable-192 / -512   `purpose: maskable`. Android applies its own mask —
                             circle, squircle, rounded square, depending on the
                             launcher — and crops whatever it likes outside the
                             safe zone. So the art is inset into SAFE_ZONE
                             (72/108, the same value the shipped Android launcher
                             icon uses) on a full-bleed field. Getting this wrong
                             does not fail loudly; it clips the calligraphy on
                             some launchers and not others.

  apple-touch-icon-180       iOS home screen, and the reason this script exists
                             at all. **iOS ignores the manifest's `icons` array
                             entirely** — it reads the `<link rel="apple-touch-icon">`
                             tag — and it ignores `purpose: maskable` too. It also
                             flattens transparency onto BLACK, so a transparent PNG
                             becomes a mark floating in a black square. Hence the
                             opaque field, forced below. This is the icon the
                             people this PWA is for will actually look at.

  favicon                    The browser tab. 32px, where the calligraphy is
                             illegible at any inset, so it gets the full tile.
"""

import importlib.util
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
WEB = os.path.join(PROJECT, "web")
ICONS = os.path.join(WEB, "icons")

SOURCE = os.path.join(PROJECT, "assets", "logo", "square", "mizan_midnight.png")


def load_launcher_module():
    """Import make_launcher_icons.py as a module.

    By path rather than by name because `tools/` is not a package and this script
    may be run from anywhere. Safe to import: that file guards its entry point
    with `if __name__ == "__main__"`, so importing it defines functions and
    generates nothing.
    """
    path = os.path.join(HERE, "make_launcher_icons.py")
    spec = importlib.util.spec_from_file_location("make_launcher_icons", path)
    if spec is None or spec.loader is None:
        sys.exit("cannot load %s" % path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def flatten(im, bg):
    """Composite onto an opaque field.

    Not optional, and not only for iOS. A PWA icon with an alpha channel is
    composited by whoever displays it, against a colour this app does not choose
    — black on an iOS home screen, white in some Android launchers, the tab strip
    colour in a browser. Deciding it here is the only way the icon looks the same
    in all three.
    """
    out = Image.new("RGBA", im.size, tuple(bg) + (255,))
    out.alpha_composite(im)
    return out


def resize(im, size):
    return im.resize((size, size), Image.LANCZOS)


def inset_on_field(art, size, bg, fraction):
    """The maskable form: art shrunk to `fraction` of the canvas, centred on the
    field, full bleed to the edges."""
    canvas = Image.new("RGBA", (size, size), tuple(bg) + (255,))
    inner = max(1, int(round(size * fraction)))
    scaled = art.resize((inner, inner), Image.LANCZOS)
    offset = (size - inner) // 2
    canvas.alpha_composite(scaled, (offset, offset))
    return canvas


def near_white_count(im, threshold):
    px = im.convert("RGBA").load()
    w, h = im.size
    n = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 255 and r >= threshold and g >= threshold and b >= threshold:
                n += 1
    return n


def main():
    launcher = load_launcher_module()

    if not os.path.exists(SOURCE):
        sys.exit("missing source art: %s" % SOURCE)
    os.makedirs(ICONS, exist_ok=True)

    art = Image.open(SOURCE).convert("RGBA")
    print("source %s %dx%d" % (os.path.relpath(SOURCE, PROJECT), *art.size))

    field = launcher.field_colour(art)
    print("field  #%02X%02X%02X (sampled from the tile, not hardcoded)" % field)

    # Strip the wedges once, at full resolution, before any resize. LANCZOS has
    # negative lobes: downscale first and the hard white/field edge rings back
    # above the near-white threshold, so pale corners reappear in the output even
    # though the strip "worked". Order matters here.
    changed = launcher.strip_corner_white(art, field)
    print("strip  %d px replaced" % changed)

    art = flatten(art, field)

    # Same safe zone as the Android launcher icon, so a Mizan install on Android
    # shows the identical mark whether it came from the APK or from the browser.
    safe = launcher.SAFE_ZONE

    written = []

    for size in (192, 512):
        path = os.path.join(ICONS, "Icon-%d.png" % size)
        resize(art, size).save(path)
        written.append(path)

        path = os.path.join(ICONS, "Icon-maskable-%d.png" % size)
        inset_on_field(art, size, field, safe).save(path)
        written.append(path)

    # iOS home screen. 180 is the current 3x size; iOS downsamples it for 2x
    # devices, so one file covers every iPhone and iPad this is aimed at.
    apple = os.path.join(ICONS, "apple-touch-icon-180.png")
    resize(art, 180).save(apple)
    written.append(apple)

    favicon = os.path.join(WEB, "favicon.png")
    resize(art, 32).save(favicon)
    written.append(favicon)

    print()
    for path in written:
        im = Image.open(path)
        opaque = im.convert("RGBA").getchannel("A").getextrema() == (255, 255)
        print("  %-34s %3dx%-3d  %s" % (
            os.path.relpath(path, PROJECT), im.size[0], im.size[1],
            "opaque" if opaque else "HAS ALPHA — iOS would composite this on black",
        ))

    # The two checks worth failing on, rather than eyeballing the output.
    print()
    ok = True

    for path in written:
        im = Image.open(path).convert("RGBA")
        if im.getchannel("A").getextrema() != (255, 255):
            print("FAIL %s has transparent pixels" % os.path.basename(path))
            ok = False

    # The wedges are the whole reason this reuses the launcher module, so prove
    # they are gone rather than assuming the strip held through the resize.
    big = Image.open(os.path.join(ICONS, "Icon-512.png"))
    white = near_white_count(big, launcher.NEAR_WHITE)
    print("Icon-512: %d near-white px (>=%d) — %s"
          % (white, launcher.NEAR_WHITE,
             "clean" if white == 0 else "FAIL, wedges survived the resize"))
    if white:
        ok = False

    print()
    print("═══ %s ═══" % ("ALL CHECKS PASS" if ok else "SEE FAILURES ABOVE"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
