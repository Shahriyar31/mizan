#!/usr/bin/env bash
#
# UmmahAPI probe — proves the key is honoured, and captures the response shapes.
#
# Two jobs, both of which have to happen on a machine with network access:
#
#   1. Authentication. On UmmahAPI a 200 response proves nothing about the key,
#      because every endpoint answers anonymously too. The only honest test is to
#      call the same endpoint three ways — no key, the real key, a deliberately
#      invalid key — and compare what comes back. If the real key and the bad key
#      produce identical limits, the key is being ignored and we should know that
#      before shipping a client that assumes otherwise.
#
#   2. Response schemas. The PDF documentation lists endpoints but no field
#      names, and parsers written against a guessed schema fail silently in the
#      worst possible way: they compile, they run, and they show nothing. So every
#      body is saved to disk for the field names to be read off directly.
#
# The key is read from .env and passed in the X-API-Key header only. It is never
# put in a URL, never echoed, and never written to any saved file — a key in a
# query string ends up in shell history, proxy logs and crash reports.
#
#     bash tools/ummah_probe.sh
#
# Output: tools/.ummah_samples/  (gitignored — bodies, headers, and a manifest)
set -uo pipefail

BASE="${UMMAH_API_BASE:-https://ummahapi.com}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env"
OUT="$ROOT/tools/.ummah_samples"
BAD_KEY="umh_deliberately_invalid_key_000000000000"

command -v curl >/dev/null || { echo "curl not found"; exit 1; }

# ── the key ──────────────────────────────────────────────────────────────
[ -f "$ENV_FILE" ] || { echo "no .env at $ENV_FILE"; exit 1; }
KEY="$(grep -E '^[[:space:]]*UMMAH_API_KEY[[:space:]]*=' "$ENV_FILE" | head -1 \
  | cut -d= -f2- \
  | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
        -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'\$/\1/")"
if [ -z "$KEY" ]; then echo "UMMAH_API_KEY is empty or missing in .env"; exit 1; fi
printf 'key loaded from .env: %s chars, prefix %s\n\n' "${#KEY}" "${KEY:0:4}"

rm -rf "$OUT"; mkdir -p "$OUT"

# get <name> <auth: none|key|bad> <path…>
get() {
  local name="$1" auth="$2" path="$3"
  local body="$OUT/$name.json" head="$OUT/$name.headers.txt"
  local code start ms args=(-sS --max-time 25 -o "$body" -D "$head" -w '%{http_code}')
  case "$auth" in
    key) args+=(-H "X-API-Key: $KEY") ;;
    bad) args+=(-H "X-API-Key: $BAD_KEY") ;;
  esac
  start=$(date +%s)
  code="$(curl "${args[@]}" "$BASE$path" 2>"$OUT/$name.curlerr")"
  ms=$(( ($(date +%s) - start) ))
  local size; size=$( [ -f "$body" ] && wc -c <"$body" | tr -d ' ' || echo 0 )
  printf '%-22s %-4s %-3s %7s bytes  %2ss  %s\n' "$name" "$auth" "${code:-ERR}" "$size" "$ms" "$path"
  printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$auth" "${code:-ERR}" "$size" "$path" >>"$OUT/manifest.tsv"
}

echo "── authentication ───────────────────────────────────────────────────"
get limits_anon        none "/api/limits"
get limits_keyed       key  "/api/limits"
get limits_badkey      bad  "/api/limits"
get usage_keyed        key  "/api/usage"
get usage_anon         none "/api/usage"
get health             none "/api/health"

echo
echo "── audio ────────────────────────────────────────────────────────────"
get reciters           key  "/api/quran/reciters"
get audio_surah_1      key  "/api/quran/audio/1"
get audio_ayah_2_255   key  "/api/quran/audio/2/255"

echo
echo "── tafsir ───────────────────────────────────────────────────────────"
get tafsir_list        key  "/api/tafsir"
# The tafsir key is whatever /api/tafsir says it is, so read it back rather than
# guessing. Falls through to a few plausible spellings if the shape surprises us.
TKEY="$(python3 - "$OUT/tafsir_list.json" <<'PY' 2>/dev/null
import json,sys
try: doc=json.load(open(sys.argv[1],encoding='utf-8'))
except Exception: sys.exit(1)
found=[]
def walk(n):
    if isinstance(n,dict):
        for k,v in n.items():
            if k in ('key','slug','id','identifier') and isinstance(v,str): found.append(v)
            else: walk(v)
    elif isinstance(n,list):
        for i in n: walk(i)
walk(doc)
for f in found:
    if 'kathir' in f.lower(): print(f); sys.exit(0)
print(found[0] if found else '')
PY
)"
[ -z "$TKEY" ] && TKEY="ibn-kathir"
echo "  tafsir key in use: $TKEY"
get tafsir_ayah        key  "/api/tafsir/$TKEY/surah/2/ayah/255"
get tafsir_surah_1     key  "/api/tafsir/$TKEY/surah/1"

echo
echo "── mutashabihat ─────────────────────────────────────────────────────"
get muta_root          key  "/api/quran/mutashabihat"
get muta_surah_2       key  "/api/quran/mutashabihat/2"
get muta_ayah_2_255    key  "/api/quran/mutashabihat/2/255"

echo
echo "── hadith ───────────────────────────────────────────────────────────"
get hadith_collections key  "/api/hadith/collections"
# bukhari 3207 is one of the five citations the existing corpus actually carries,
# so this doubles as a test of a reference the app will really request.
get hadith_bukhari3207 key  "/api/hadith/bukhari/3207"
get hadith_collection  key  "/api/hadith/bukhari"
get hadith_search_kw   key  "/api/hadith/search?q=patience"
get hadith_search_narr key  "/api/hadith/search?q=Abu%20Hurairah"

echo
echo "── word-by-word (fills the Words layer for all 6,236 ayat) ──────────"
get words_ayah_2_255   key  "/api/quran/words/2/255"
get words_surah_1      key  "/api/quran/words/1"

# ── verdicts ─────────────────────────────────────────────────────────────
echo
echo "── is the key actually honoured? ────────────────────────────────────"
python3 - "$OUT" <<'PY'
import json, os, sys, re
out = sys.argv[1]

def body(name):
    p = os.path.join(out, name + '.json')
    if not os.path.exists(p): return None
    try: return json.load(open(p, encoding='utf-8'))
    except Exception: return open(p, encoding='utf-8', errors='replace').read()[:400]

def rate_headers(name):
    p = os.path.join(out, name + '.headers.txt')
    if not os.path.exists(p): return {}
    keep = {}
    for line in open(p, encoding='utf-8', errors='replace'):
        if ':' not in line: continue
        k, v = line.split(':', 1)
        if re.search(r'rate|limit|quota|tier|remaining', k, re.I):
            keep[k.strip().lower()] = v.strip()
    return keep

anon, keyed, bad = rate_headers('limits_anon'), rate_headers('limits_keyed'), rate_headers('limits_badkey')
print('  rate-limit headers, anonymous :', anon or '(none sent)')
print('  rate-limit headers, real key  :', keyed or '(none sent)')
print('  rate-limit headers, bad key   :', bad or '(none sent)')
if anon and keyed:
    print('  real key CHANGES the limits    :', anon != keyed,
          '  <-- must be True, or the header name is wrong')
if keyed and bad:
    print('  bad key is REJECTED/differs    :', keyed != bad,
          '  <-- must be True, or any string is accepted')

for name in ('limits_anon', 'limits_keyed', 'limits_badkey', 'usage_keyed', 'usage_anon'):
    d = body(name)
    if isinstance(d, dict):
        inner = d.get('data', d)
        print(f'  {name:<14}', json.dumps(inner)[:220])

# ── schema outline: enough to write a parser, small enough to read ───────
def outline(node, depth=0, path='', lines=None):
    pad = '  ' * (depth + 1)
    if isinstance(node, dict):
        for k, v in list(node.items())[:24]:
            if isinstance(v, (dict, list)):
                n = len(v)
                lines.append(f'{pad}{k}: {type(v).__name__}({n})')
                if depth < 3: outline(v, depth + 1, f'{path}.{k}', lines)
            else:
                s = str(v).replace('\n', ' ')
                if len(s) > 90: s = s[:90] + f'… [{len(str(v))} chars]'
                lines.append(f'{pad}{k}: {type(v).__name__} = {s}')
    elif isinstance(node, list) and node:
        lines.append(f'{pad}[0] of {len(node)}:')
        if depth < 3: outline(node[0], depth + 1, path + '[0]', lines)

print()
print('── response schemas ─────────────────────────────────────────────────')
names = [l.split('\t')[0] for l in open(os.path.join(out, 'manifest.tsv'), encoding='utf-8')]
for name in names:
    d = body(name)
    print(f'\n{name}')
    if d is None: print('  (no body)'); continue
    if not isinstance(d, (dict, list)): print('  ' + str(d)[:300]); continue
    lines = []
    outline(d, 0, '', lines)
    print('\n'.join(lines[:60]) or '  (empty)')
PY

echo
echo "bodies and headers saved in tools/.ummah_samples/"
