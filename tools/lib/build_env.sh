#!/usr/bin/env bash
# Shared build-variable handling for Mizan's release scripts.
#
# Sourced by tools/build_release.sh (Android) and tools/build_web.sh (PWA).
# Defines no behaviour of its own beyond the helpers below — sourcing it is safe
# and builds nothing.
#
# ── Why this is one file and not two copies ────────────────────────────
# The whitelist below IS the security guarantee: it is the only reason
# GROQ_API_KEY and UMMAH_API_KEY are not compiled into a published build. A
# guarantee that exists in two places is a guarantee that will eventually
# disagree with itself, and the copy that silently falls out of date is the one
# nobody is looking at. Both targets now read the same list, so a secret added to
# `.env` tomorrow is withheld from the APK and the PWA by the same line of code.
#
# The web target needs this more than Android does, not less. An APK hides a
# compiled string behind a download and an `unzip`; `build/web/main.dart.js` is a
# plain text file served at a public URL, so anything compiled into it can be
# found with a browser's own Find command. Same whitelist, higher stakes.

# ── Every name a release is allowed to know ───────────────────────────
# Nothing else is passed, whatever else is in .env. A whitelist rather than a
# blocklist, deliberately: add a new secret to .env and a blocklist ships it
# until somebody remembers to add a line, while a whitelist leaves it out by
# default and the artefact check then confirms it.
#
# The flags are here because they decide what the app does rather than authorise
# anything — dropping them would silently ship finished features in their
# fallback state, which is a behaviour change disguised as a security measure.
ALLOWED=(
  SUPABASE_URL
  SUPABASE_ANON_KEY
  FEATURE_HALAQA
  FEATURE_MINBAR
  FEATURE_SCHOLAR_AI
  FEATURE_SEED_SOCIAL
  FEATURE_MULTILINGUAL
)

red()   { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
bold()  { printf '\033[1m%s\033[0m\n' "$1"; }

fail() { red "✗ $1"; exit 1; }

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

# ── Guard: .env must not be an asset ──────────────────────────────────
# The whole point of these scripts is defeated if `.env` is in the bundle, so a
# build refuses rather than trusting that nobody put the line back.
guard_env_not_asset() {
  if grep -qE '^[[:space:]]*-[[:space:]]*\.env[[:space:]]*$' "$1/pubspec.yaml"; then
    fail "pubspec.yaml lists .env as an asset. That puts every key in the build in
    plaintext — and on web it would be served at <site>/assets/.env. Remove the
    line before building a release."
  fi
}

# ── Assemble the defines ──────────────────────────────────────────────
# Fills the global arrays DEFINES and EXCLUDED, and prints what it did. Lengths
# only, never values: a script that printed the values would recreate the problem
# it exists to fix, in the terminal and in whatever CI log is watching.
assemble_defines() {
  bold "Build variables"
  DEFINES=()
  local name value
  for name in "${ALLOWED[@]}"; do
    value="$(read_env "$name")"
    if [ -z "$value" ]; then
      printf '  %-22s absent\n' "$name"
      continue
    fi
    DEFINES+=(--dart-define="$name=$value")
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
}

# ── Guard: Supabase must be real ──────────────────────────────────────
# Without these two, accounts, circles and Al-Minbar fail everywhere the build
# reaches — and they fail as network errors, which look like the server is down
# rather than like a bad build. Cheaper to stop here.
guard_supabase() {
  [ -n "$(read_env SUPABASE_URL)" ] || fail "SUPABASE_URL is not set in .env"
  [ -n "$(read_env SUPABASE_ANON_KEY)" ] \
    || fail "SUPABASE_ANON_KEY is not set in .env"

  case "$(read_env SUPABASE_URL)" in
    *localhost*|*127.0.0.1*|*10.0.2.2*)
      fail "SUPABASE_URL points at localhost. That is the visitor's own machine,
    so every account would fail for everybody you send this to." ;;
  esac
}

# ── Search a built artefact for withheld values ───────────────────────
# $1 is a directory holding the unpacked build. Sets LEAKED=1 if any withheld
# value is present.
#
# The control check first: before trusting any "not found", confirm the search can
# see a value that is certainly in there. SUPABASE_ANON_KEY was compiled in a
# moment ago; if grep cannot find that, then compiled strings are not visible to
# this method and every absence afterwards would be meaningless rather than
# reassuring.
check_for_leaks() {
  local work="$1" control name value search_works
  bold "Checking the artefact for withheld values"

  control="$(read_env SUPABASE_ANON_KEY)"
  if grep -r -a -q -F -- "$control" "$work" 2>/dev/null; then
    echo "  search verified — a known compiled value was found in the artefact"
    search_works=1
  else
    red "! Could not find a value known to be compiled in."
    red "  This search cannot see compiled strings in this build, so the results"
    red "  below prove nothing. Check by hand before publishing."
    search_works=0
  fi

  LEAKED=0
  for name in "${EXCLUDED[@]}"; do
    value="$(read_env "$name")"
    # Short values are words, not secrets, and would match by coincidence.
    [ "${#value}" -ge 12 ] || continue
    if grep -r -a -q -F -- "$value" "$work" 2>/dev/null; then
      red "  ✗ $name — its value is inside the artefact"
      LEAKED=1
    else
      echo "  ✓ $name absent"
    fi
  done

  SEARCH_WORKS="$search_works"
}
