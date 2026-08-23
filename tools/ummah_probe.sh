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

# ── the ten topics ───────────────────────────────────────────────────────
#
# The one thing that cannot be established without a network: whether each of
# the ten doors in the learning section actually has narrations behind it.
#
# Two numbers per topic, and the gap between them is the whole diagnosis:
#
#   raw    — rows the service sent. Zero means the term finds nothing, or the
#            query parameter is not the one being used.
#   citable— rows that carried BOTH a collection we can resolve AND a hadith
#            number, which is what the app requires before it will show a
#            narration. `id` is not accepted as a number: a row identifier
#            printed as "Sahih al-Bukhari 84712" is a fabricated citation.
#
# raw > 0 with citable == 0 is a field-name problem in the app, and the
# collection names printed underneath say which spelling to teach it. raw == 0
# for every term is a term problem, or a topic that should not ship.
echo
echo "── the ten topics ───────────────────────────────────────────────────"

TOPIC_OUT="$OUT/topics"; mkdir -p "$TOPIC_OUT"

# search <outfile> <param> <term> — GET the search, URL-encoding the term.
search() {
  curl -sS --max-time 25 -G \
    -H "X-API-Key: $KEY" \
    --data-urlencode "$2=$3" \
    --data-urlencode "limit=40" \
    -o "$1" -w '%{http_code}' \
    "$BASE/api/hadith/search" 2>>"$TOPIC_OUT/curlerr.txt"
}

# rows <file> — how many result rows the body holds, or -1 if unreadable.
rows() {
  python3 - "$1" <<'PY' 2>/dev/null || echo -1
import json,sys
try: doc=json.load(open(sys.argv[1],encoding='utf-8'))
except Exception: sys.exit(1)
def rowsof(d):
    if isinstance(d,list): return [x for x in d if isinstance(x,dict)]
    if isinstance(d,dict):
        for k in ('hadiths','results','data','items'):
            v=d.get(k)
            if isinstance(v,list): return rowsof(v)
        for v in d.values():
            if isinstance(v,(dict,list)):
                r=rowsof(v)
                if r: return r
    return []
print(len(rowsof(doc)))
PY
}

# The parameter name is not documented, so it is discovered the same way the app
# discovers it — and judged the same way: on the RAW row count, never on how many
# rows turned out to be citable.
PARAM=""
for cand in q query keyword search text; do
  code="$(search "$TOPIC_OUT/param_$cand.json" "$cand" patience)"
  n="$(rows "$TOPIC_OUT/param_$cand.json")"
  printf '  param %-8s status %-3s raw rows %s\n' "$cand" "${code:-ERR}" "$n"
  if [ "${code:-0}" = "200" ] && [ "${n:-0}" -gt 0 ] 2>/dev/null; then
    PARAM="$cand"; break
  fi
done

if [ -z "$PARAM" ]; then
  echo
  echo "  no query parameter returned any rows — the app cannot search until this"
  echo "  is resolved. Read $TOPIC_OUT/param_q.json for what the service did say."
else
  echo
  echo "  query parameter that worked: $PARAM"
  echo
  printf '  %-12s %-14s %5s %8s\n' TOPIC TERM RAW CITABLE
  printf '  %-12s %-14s %5s %8s\n' ------------ -------------- ----- --------

  # id → terms, in the same order as HadithTopics.all. Kept here rather than
  # parsed out of the Dart so the probe runs with nothing but curl and python.
  TOPICS=(
    "faith|faith belief oneness worship"
    "prayer|prayer prostration congregation"
    "patience|patience patient affliction"
    "knowledge|knowledge learn teach"
    "character|character manners truthful modesty"
    "repentance|repentance repent forgiveness"
    "family|parents mother children kinship"
    "leadership|leader ruler authority shepherd"
    "companions|companions ansar muhajirun"
    "signs|the hour;resurrection;signs"
  )

  for entry in "${TOPICS[@]}"; do
    id="${entry%%|*}"; termspec="${entry#*|}"
    # Semicolons separate multi-word terms; spaces separate single-word ones.
    if [[ "$termspec" == *";"* ]]; then
      IFS=';' read -r -a terms <<<"$termspec"
    else
      read -r -a terms <<<"$termspec"
    fi

    used=""; raw=0; citable=0
    for term in "${terms[@]}"; do
      f="$TOPIC_OUT/$id.json"
      code="$(search "$f" "$PARAM" "$term")"
      raw="$(rows "$f")"
      used="$term"
      [ "${raw:-0}" -gt 0 ] 2>/dev/null && break
    done

    if [ "${raw:-0}" -gt 0 ] 2>/dev/null; then
      citable="$(python3 - "$TOPIC_OUT/$id.json" <<'PY' 2>/dev/null || echo -1
import json,re,sys
doc=json.load(open(sys.argv[1],encoding='utf-8'))
def rowsof(d):
    if isinstance(d,list): return [x for x in d if isinstance(x,dict)]
    if isinstance(d,dict):
        for k in ('hadiths','results','data','items'):
            v=d.get(k)
            if isinstance(v,list): return rowsof(v)
        for v in d.values():
            if isinstance(v,(dict,list)):
                r=rowsof(v)
                if r: return r
    return []
norm=lambda s: re.sub(r'[^a-z0-9]','',s.lower())
# The app's accepted number fields. `id` is deliberately not among them.
NUM={norm(x) for x in ('number','hadith_number','hadith_no','hadith_num',
                       'reference_number','number_in_book')}
COL={norm(x) for x in ('collection','collection_name','collection_slug',
                       'book_slug','source','collection_id','book')}
TXT={norm(x) for x in ('arabic','arab','hadith_arabic','text_ar','arabicText',
                       'english','hadith_english','text_en','englishText',
                       'translation','body','text')}
# Only what UmmahAPI carries and our slugs accept; ahmad/darimi/bulugh/nawawi
# are declined on purpose, so a row naming them is correctly uncitable.
ALIASES={'bukhari':'bukhari','sahih bukhari':'bukhari','muslim':'muslim',
         'sahih muslim':'muslim','abu dawud':'abudawud','abudawud':'abudawud',
         'abudawood':'abudawud','tirmidhi':'tirmidhi','nasai':'nasai',
         'ibn majah':'ibnmajah','ibnmajah':'ibnmajah','muwatta':'malik',
         'malik':'malik'}
def field(row,names):
    for k,v in row.items():
        if norm(k) in names and v not in (None,''):
            if isinstance(v,(str,int,float)) and str(v).strip(): return str(v).strip()
    return None
def slug(row):
    for k,v in row.items():
        if norm(k) not in COL or not isinstance(v,(str,int,float)): continue
        s=re.sub(r"['’‘`]",'',str(v).lower())
        if any(t in s for t in ('40','forty','arbain')): continue
        for a,sl in ALIASES.items():
            if a in s: return sl
    return None
rs=rowsof(doc); ok=0; names={}
for r in rs:
    sl=slug(r)
    if sl is None:
        for k,v in r.items():
            if norm(k) in COL and isinstance(v,(str,int,float)):
                names[str(v)]=names.get(str(v),0)+1
        continue
    if field(r,NUM) is None: continue
    if field(r,TXT) is None: continue
    ok+=1
print(ok)
open(sys.argv[1]+'.unresolved','w').write(json.dumps(names))
PY
)"
    fi

    printf '  %-12s %-14s %5s %8s\n' "$id" "$used" "${raw:-0}" "${citable:-0}"
  done

  echo
  echo "  collection names that could not be resolved (per topic, if any):"
  found=0
  for f in "$TOPIC_OUT"/*.json.unresolved; do
    [ -f "$f" ] || continue
    [ "$(cat "$f")" = "{}" ] && continue
    printf '    %-14s %s\n' "$(basename "$f" .json.unresolved)" "$(cat "$f")"
    found=1
  done
  [ "$found" = 0 ] && echo "    (none — every row named a collection the app knows)"

  echo
  echo "  A topic showing raw 0 for every term is a topic that should not ship."
  echo "  A topic showing raw > 0 and citable 0 is a field-name fix in the app."
fi

echo
echo "topic bodies saved in tools/.ummah_samples/topics/"
