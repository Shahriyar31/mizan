#!/usr/bin/env bash
# PWA build for Mizan, and proof that it carries no secret.
#
# ── Read this before building the web app by hand ─────────────────────
# The obvious command is the dangerous one:
#
#     flutter build web --release --dart-define-from-file=.env     # DO NOT
#
# `--dart-define` values are compiled in as literal strings, and on web the
# compiled output is `build/web/main.dart.js` — a plain text file served at a
# public URL. So that command publishes GROQ_API_KEY and UMMAH_API_KEY in a file
# anybody can open and search with Ctrl+F. No download, no `unzip`, no tooling.
# It is strictly worse than the APK bug this project already fixed.
#
# This script passes the same whitelist the Android release uses
# (tools/lib/build_env.sh) and then searches the built output to prove the rest is
# absent. The search is more trustworthy here than on Android, because the
# artefact is text: if a value were present, grep would certainly find it.
#
# Usage:
#   tools/build_web.sh                     # deploy at a domain root (Vercel)
#   tools/build_web.sh /mizan/             # deploy in a subdirectory
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
ROOT="$PWD"
ENV_FILE="$ROOT/.env"
BASE_HREF="${1:-/}"
OUT="$ROOT/build/web"

# shellcheck source=tools/lib/build_env.sh
. "$ROOT/tools/lib/build_env.sh"

guard_env_not_asset "$ROOT"
[ -f "$ENV_FILE" ] || fail ".env not found at $ENV_FILE"

# ── base href must be a directory path ────────────────────────────────
# Flutter substitutes this into `<base href="$FLUTTER_BASE_HREF">` in index.html,
# and the browser resolves every asset against it. Without the trailing slash the
# last segment is treated as a filename and dropped, so `/mizan` would make the
# app fetch `/main.dart.js` instead of `/mizan/main.dart.js` — a blank page with
# 404s in the console and nothing obviously wrong with the build.
case "$BASE_HREF" in
  /*/|/) ;;
  *) fail "base href must start and end with '/' — you gave '$BASE_HREF'.
    Use '/' for a domain root, or '/mizan/' for a subdirectory." ;;
esac

# ── Guard: the SQLite runtime files must be present ───────────────────
# sqflite on web is real SQLite compiled to WebAssembly, and two of its pieces
# are fetched by the browser at runtime rather than compiled into the Dart bundle.
# `flutter build web` does not produce them and does not miss them: the build
# succeeds and the app then fails on its first query, which is the worst place to
# discover it. They are downloaded once by the setup command below and belong in
# `web/` alongside index.html, where they are committed like any other asset.
MISSING=()
for f in sqlite3.wasm sqflite_sw.js; do
  [ -f "$ROOT/web/$f" ] || MISSING+=("web/$f")
done
if [ "${#MISSING[@]}" -gt 0 ]; then
  fail "missing SQLite runtime file(s): ${MISSING[*]}

    Without them the build succeeds and then every screen fails to load its data,
    because sqflite has no database to open. Fetch them once (needs internet):

        dart run sqflite_common_ffi_web:setup

    then commit them and run this script again."
fi

assemble_defines
guard_supabase

# ── Build ─────────────────────────────────────────────────────────────
# No --web-renderer flag and no --wasm, on purpose.
#
# The default output is JavaScript with CanvasKit, which is the combination iOS
# Safari actually runs well — and iPhone and iPad users are the entire reason this
# build exists. `--wasm` (dart2wasm) produces a smaller, faster bundle but needs
# WasmGC, which only reached Safari very recently; choosing it would trade the
# audience for a benchmark. Revisit when the iOS floor is higher.
echo
bold "flutter build web --release --base-href $BASE_HREF"
flutter build web --release --base-href "$BASE_HREF" "${DEFINES[@]}" \
  || fail "the build failed"

[ -d "$OUT" ] || fail "the build reported success but $OUT does not exist"

echo
green "Built build/web ($(du -sh "$OUT" | cut -f1))"

# ── Guard: everything the app needs at runtime actually shipped ───────
# `flutter build web` copies `web/` into `build/web/`, so these should be present
# — but a missing icon or manifest degrades quietly (an install prompt that never
# appears, a home-screen icon that falls back to a screenshot) rather than
# failing, and quiet degradation is what this project keeps refusing to ship.
echo
bold "Checking the output is installable"
REQUIRED=(
  index.html
  manifest.json
  favicon.png
  flutter_bootstrap.js
  main.dart.js
  sqlite3.wasm
  sqflite_sw.js
  icons/Icon-192.png
  icons/Icon-512.png
  icons/Icon-maskable-192.png
  icons/Icon-maskable-512.png
  icons/apple-touch-icon-180.png
)
GONE=0
for f in "${REQUIRED[@]}"; do
  if [ -f "$OUT/$f" ]; then
    printf '  ✓ %s\n' "$f"
  else
    red "  ✗ $f is missing from build/web"
    GONE=1
  fi
done
[ "$GONE" -eq 0 ] || fail "the output is incomplete — see the missing files above"

# The base href has to end up in the served HTML, and getting it wrong is a blank
# page rather than an error, so read it back rather than trusting the flag.
if grep -q "<base href=\"$BASE_HREF\">" "$OUT/index.html"; then
  echo "  ✓ <base href=\"$BASE_HREF\"> written into index.html"
else
  red "  ! could not confirm <base href> in build/web/index.html — check it by hand"
fi

# ── Prove it ──────────────────────────────────────────────────────────
# No unpacking step: build/web is already a directory of mostly plain text, which
# is precisely why this check matters more here than on Android.
echo
if find "$OUT" -name '.env' -print -quit | grep -q .; then
  fail "build/web contains a .env file, which would be served at
    <site>/assets/.env in plaintext. Remove it from pubspec.yaml assets."
fi

check_for_leaks "$OUT"

echo
if [ "$LEAKED" -ne 0 ]; then
  fail "A withheld value is inside build/web. Do NOT deploy this.
    On web that value is readable by anyone who opens main.dart.js in a browser.
    Find where it is read from and route it through BuildConfig, or through the
    proxy if it must stay secret at runtime."
fi

if [ "$SEARCH_WORKS" -eq 1 ]; then
  green "✓ No withheld value appears anywhere in build/web."
else
  red "! Finished, but unverified. See above."
fi

echo
echo "Output:  $OUT"
echo "Preview: cd build/web && python3 -m http.server 8000"
echo
echo "Preview it over http://localhost:8000 rather than by opening index.html"
echo "directly — a file:// page cannot register a service worker, so installing"
echo "to the home screen will not be offered and the offline cache will not work."
