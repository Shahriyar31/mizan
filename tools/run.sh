#!/usr/bin/env bash
# Run Mizan in development, with `.env` delivered rather than bundled.
#
# `.env` is no longer a Flutter asset — see lib/core/config/build_config.dart for
# why — so `flutter run` on its own starts an app with no server settings. It
# still starts, and says so on the sign-in screen, but nothing that needs
# Supabase will work. This passes the whole file in as --dart-define constants,
# which is safe here because a debug build never leaves your machine.
#
# For a build you intend to give somebody, use tools/build_release.sh instead:
# that one passes a whitelist and then checks the artefact for everything it
# withheld.
#
# Usage:
#   tools/run.sh                  # first attached device
#   tools/run.sh -d chrome        # any flutter run argument passes through
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

if [ ! -f .env ]; then
  printf '\033[31m✗ .env not found.\033[0m\n'
  echo "  Copy .env.example to .env and fill in SUPABASE_URL and SUPABASE_ANON_KEY."
  exit 1
fi

exec flutter run --dart-define-from-file=.env "$@"
