#!/usr/bin/env bash
# Mizan sandbox analyzer — type-checks the real lib/ without touching the
# project's own .dart_tool (which the user's `flutter run` depends on).
#
# It mirrors lib/ into /tmp and gives the mirror a package_config.json whose
# URIs are rewritten from host paths to sandbox mount paths. Same sources, same
# package graph, zero risk to the host build.
set -uo pipefail
MNT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"   # .../mnt/develop
PROJ="$MNT/ummahapp"
MIRROR=/tmp/mizan-analyze
DART="$MNT/flutter/bin/cache/dart-sdk/bin/dart"

mkdir -p "$MIRROR/.dart_tool"
rm -rf "$MIRROR/lib" "$MIRROR/test" "$MIRROR/tools"
cp -a "$PROJ/lib" "$MIRROR/lib"
[ -d "$PROJ/test" ] && cp -a "$PROJ/test" "$MIRROR/test"
# tools/ holds real Dart too — the corpus audit, the layout checks, the backup
# proof. Mirrored so `analyze.sh lib test tools` can cover them, and because
# tools/verify_backup.dart imports test/support/, which only resolves if both
# directories are present in the same mirror.
[ -d "$PROJ/tools" ] && cp -a "$PROJ/tools" "$MIRROR/tools"
cp -a "$PROJ/pubspec.yaml" "$MIRROR/pubspec.yaml"
[ -f "$PROJ/analysis_options.yaml" ] && cp -a "$PROJ/analysis_options.yaml" "$MIRROR/analysis_options.yaml"

python3 - "$PROJ" "$MIRROR" "file://$MNT/" <<'PY'
import json, sys
proj, mirror, develop_mnt = sys.argv[1], sys.argv[2], sys.argv[3]
cache_mnt = develop_mnt.rsplit('/develop/', 1)[0] + '/.pub-cache/'
d = json.load(open(proj + '/.dart_tool/package_config.json'))
for p in d['packages']:
    u = p['rootUri']
    u = u.replace('file:///home/shahriyar/develop/',
                  develop_mnt)
    u = u.replace('file:///home/shahriyar/.pub-cache/',
                  cache_mnt)
    if p['name'] in ('mizan', 'ummahapp', 'taddabur'):
        u = 'file://' + mirror
    p['rootUri'] = u
json.dump(d, open(mirror + '/.dart_tool/package_config.json', 'w'), indent=2)
PY

cd "$MIRROR" || exit 1
if [ "$#" -eq 0 ]; then set -- lib; fi
FLUTTER_ROOT="$MNT/flutter" "$DART" analyze "$@" 2>&1
