#!/usr/bin/env bash
# Release build for Mizan on Android, and proof that it carries no secret.
#
# ── Why a script and not a command ─────────────────────────────────────
# `.env` holds several things the app needs and two things it must never ship.
# `--dart-define-from-file=.env` would pass all of them, so the safe build cannot
# be the convenient one unless something enforces the difference. That is the
# whitelist in tools/lib/build_env.sh, plus the check below that everything else
# really is absent from the artefact.
#
# The whitelist and the leak check live in tools/lib/build_env.sh because
# tools/build_web.sh needs exactly the same guarantee, and a security rule kept in
# two files is a security rule that will eventually disagree with itself.
#
# ── What this does not claim ────────────────────────────────────────────
# A value passed with --dart-define is compiled into the binary and can be found
# there with `strings`. That is true of SUPABASE_URL and SUPABASE_ANON_KEY and it
# is fine: the anon key names the project and carries no privileges of its own,
# because every table is reached through row-level security. It would not be fine
# for GROQ_API_KEY or UMMAH_API_KEY, which is exactly why they are not passed.
# The permanent fix for those is a proxy that holds them server-side.
#
# Usage:
#   tools/build_release.sh              # universal release APK
#   tools/build_release.sh appbundle    # .aab for the Play Store
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
ROOT="$PWD"
ENV_FILE="$ROOT/.env"
TARGET="${1:-apk}"

# shellcheck source=tools/lib/build_env.sh
. "$ROOT/tools/lib/build_env.sh"

guard_env_not_asset "$ROOT"
[ -f "$ENV_FILE" ] || fail ".env not found at $ENV_FILE"

assemble_defines
guard_supabase

# ── Build ─────────────────────────────────────────────────────────────
# Not obfuscated on purpose. `--obfuscate` renames Dart symbols; it does not
# encrypt string constants, so it would add nothing to the guarantee this script
# is making, while making every crash report from a beta tester unreadable
# without the matching symbol files. Worth revisiting at Play Store release.
echo
bold "flutter build $TARGET --release"
flutter build "$TARGET" --release "${DEFINES[@]}" || fail "the build failed"

case "$TARGET" in
  apk)       ARTEFACT="$ROOT/build/app/outputs/flutter-apk/app-release.apk" ;;
  appbundle) ARTEFACT="$ROOT/build/app/outputs/bundle/release/app-release.aab" ;;
  *)         ARTEFACT="" ;;
esac

if [ -z "$ARTEFACT" ] || [ ! -f "$ARTEFACT" ]; then
  red "! Built, but the artefact was not where this script expected it."
  red "  Skipping the leak check — run it by hand before publishing."
  exit 0
fi

echo
green "Built $(basename "$ARTEFACT") ($(du -h "$ARTEFACT" | cut -f1))"

# ── Prove it ──────────────────────────────────────────────────────────
echo
if ! command -v unzip >/dev/null 2>&1; then
  red "! unzip not found, so the artefact could not be searched."
  red "  Install unzip and re-run, or check by hand before publishing."
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
unzip -qq -o "$ARTEFACT" -d "$WORK" || fail "could not open the artefact"

# An `.env` inside the bundle is the original bug, so it is named separately —
# a value search would find it too, but not say what to fix.
if find "$WORK" -name '.env' -print -quit | grep -q .; then
  fail "the artefact contains a .env file. Remove it from pubspec.yaml assets."
fi

check_for_leaks "$WORK"

echo
if [ "$LEAKED" -ne 0 ]; then
  fail "A withheld value is in the build. Do not publish this artefact.
    Find where it is read from and route it through BuildConfig, or through the
    proxy if it must stay secret at runtime."
fi

if [ "$SEARCH_WORKS" -eq 1 ]; then
  green "✓ No withheld value appears in $(basename "$ARTEFACT")."
else
  red "! Finished, but unverified. See above."
fi

echo
echo "Artefact: $ARTEFACT"
