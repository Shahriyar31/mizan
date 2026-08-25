#!/usr/bin/env bash
# Release build for Mizan, and proof that it carries no secret.
#
# ── Why a script and not a command ─────────────────────────────────────
# `.env` holds six things the app needs and two things it must never ship.
# `--dart-define-from-file=.env` would pass all eight, so the safe build cannot
# be the convenient one unless something enforces the difference. That is this
# file: a whitelist of names, and a check afterwards that everything else really
# is absent from the artefact.
#
# A whitelist rather than a blocklist, deliberately. Add a new secret to `.env`
# tomorrow and a blocklist ships it until somebody remembers to add a line; a
# whitelist leaves it out by default and the check below then confirms it.
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

red()   { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
bold()  { printf '\033[1m%s\033[0m\n' "$1"; }

fail() { red "✗ $1"; exit 1; }

# Every name the release is allowed to know. Nothing else is passed, whatever
# else is in .env.
#
# The four flags are here because they decide what the app does rather than
# authorise anything — dropping them would silently ship three finished features
# in their fallback state, which is a behaviour change disguised as a security
# measure.
ALLOWED=(
  SUPABASE_URL
  SUPABASE_ANON_KEY
  FEATURE_HALAQA
  FEATURE_MINBAR
  FEATURE_SCHOLAR_AI
  FEATURE_SEED_SOCIAL
  FEATURE_MULTILINGUAL
)

# ── Guard: .env must not be an asset ──────────────────────────────────
# The whole point of this script is defeated if `.env` is in the bundle, so the
# build refuses rather than trusting that nobody put the line back.
if grep -qE '^[[:space:]]*-[[:space:]]*\.env[[:space:]]*$' "$ROOT/pubspec.yaml"; then
  fail "pubspec.yaml lists .env as an asset. That puts every key in the APK in
    plaintext. Remove the line before building a release."
fi

[ -f "$ENV_FILE" ] || fail ".env not found at $ENV_FILE"

# ── Read one value ────────────────────────────────────────────────────
# Last definition wins, which matches how dotenv and the shell both behave and
# means a commented-out local override above the real value cannot win. Comment
# lines cannot match: the pattern requires the name immediately after optional
# leading space, and a comment starts with '#'.
read_env() {
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$ENV_FILE" \
    | tail -n 1 \
    | tr -d '\r' \
    | sed -e 's/[[:space:]]*$//' -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"
}

# Every name defined in .env, in file order, comments excluded.
all_keys() {
  grep -oE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=' "$ENV_FILE" \
    | tr -d ' \t=' \
    | tr -d '\r'
}

is_allowed() {
  local candidate="$1" name
  for name in "${ALLOWED[@]}"; do
    [ "$name" = "$candidate" ] && return 0
  done
  return 1
}

# ── Assemble the defines ──────────────────────────────────────────────
bold "Build variables"
DEFINES=()
for name in "${ALLOWED[@]}"; do
  value="$(read_env "$name")"
  if [ -z "$value" ]; then
    printf '  %-22s absent\n' "$name"
    continue
  fi
  DEFINES+=(--dart-define="$name=$value")
  # Length only. A script that prints the values would recreate the problem it
  # exists to fix, in the terminal and in whatever CI log is watching.
  printf '  %-22s passed (%d chars)\n' "$name" "${#value}"
done

EXCLUDED=()
while IFS= read -r name; do
  is_allowed "$name" || EXCLUDED+=("$name")
done < <(all_keys)

if [ "${#EXCLUDED[@]}" -gt 0 ]; then
  bold "Withheld from this build"
  for name in "${EXCLUDED[@]}"; do
    printf '  %-22s withheld\n' "$name"
  done
fi

# Without these two, accounts, circles and Al-Minbar fail on every phone the APK
# reaches — and they fail as network errors, which look like the server is down
# rather than like a bad build. Cheaper to stop here.
[ -n "$(read_env SUPABASE_URL)" ] || fail "SUPABASE_URL is not set in .env"
[ -n "$(read_env SUPABASE_ANON_KEY)" ] || fail "SUPABASE_ANON_KEY is not set in .env"

case "$(read_env SUPABASE_URL)" in
  *localhost*|*127.0.0.1*|*10.0.2.2*)
    fail "SUPABASE_URL points at localhost. On a phone that is the phone itself,
    so every account would fail for everybody you send the APK to." ;;
esac

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
bold "Checking the artefact for withheld values"

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

# ── The control ───────────────────────────────────────────────────────
# Before trusting any "not found", confirm the search can see a value that is
# certainly in there. SUPABASE_ANON_KEY was compiled in a moment ago; if grep
# cannot find that, then compiled strings are not visible to this method and
# every absence below would be meaningless rather than reassuring.
CONTROL="$(read_env SUPABASE_ANON_KEY)"
if grep -r -a -q -F -- "$CONTROL" "$WORK" 2>/dev/null; then
  echo "  search verified — a known compiled value was found in the artefact"
  SEARCH_WORKS=1
else
  red "! Could not find a value known to be compiled in."
  red "  This search cannot see compiled strings in this build, so the results"
  red "  below prove nothing. Check by hand before publishing."
  SEARCH_WORKS=0
fi

LEAKED=0
for name in "${EXCLUDED[@]}"; do
  value="$(read_env "$name")"
  # Short values are words, not secrets, and would match by coincidence.
  [ "${#value}" -ge 12 ] || continue
  if grep -r -a -q -F -- "$value" "$WORK" 2>/dev/null; then
    red "  ✗ $name — its value is inside the artefact"
    LEAKED=1
  else
    echo "  ✓ $name absent"
  fi
done

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
