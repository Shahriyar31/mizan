# UmmahAPI — key verification, authentication, and the requests production will make

Status: **verification complete; all five phases are now implemented.** This
document is kept as the key-verification record and endpoint reference. For what
was built, see `docs/UMMAH_API_IMPLEMENTATION.md`.

Where this document says "not yet implemented" or "no client code written", read it
as describing the state at verification time, not today.

---

## 1. Is the key being loaded correctly?

Yes — and this was checked with `flutter_dotenv`'s own parser rather than a
lookalike, because the failure modes that matter live inside that parser. Its
`_comment` regex strips `#…` to end-of-line, `_surroundQuotes` unwraps quotes, and
`_bashVar` substitutes `$NAME` sequences; any of those can silently rewrite a key
that "looks fine" in the file. So `flutter_dotenv 5.2.1`'s `Parser` was run over
the real `.env` and asked what it produced.

| Check | Result |
| --- | --- |
| Variable name | `UMMAH_API_KEY` — exact match to the brief |
| Present in `.env` | yes, line 25, defined once (no shadowing duplicate) |
| Parsed by `flutter_dotenv 5.2.1` `Parser` | yes |
| Length after parse | 44 characters — **identical to the raw length**, so nothing was stripped, unquoted or `$`-substituted in transit |
| Prefix | `umh_`, matching the documented key format |
| Quotes / trailing whitespace / inline `#` comment / non-ASCII | none |
| `.env` declared in `pubspec.yaml` assets | yes (line 63) — without this `dotenv.load()` throws at startup |
| `dotenv.load(fileName: '.env')` runs before anything reads it | yes, `lib/main.dart:18` |
| `.env` git-ignored and untracked | yes (`.gitignore:51`, `git ls-files` empty) |
| Key literal anywhere in `lib/` or `docs/` | none — nothing is hardcoded |
| Anything in `lib/` reads `UMMAH_API_KEY` today | **no** — no client exists yet; this is the gap Phase 1 fills |

Two fixes went in alongside the check, both configuration rather than feature code:
`UMMAH_API_KEY` was missing from `.env.example`, so a fresh clone had no way to
learn it was required; and `tools/.ummah_samples/` is now git-ignored so probe
output can never be committed.

## 2. Why I cannot complete the authentication test from here

Outbound network from this sandbox is blocked at the host allowlist:

```
Host "ummahapi.com" is not on the network allowlist (cowork-egress-blocked).
Allowed: agentrouter.org
```

That is a hard limit, not a retry-able failure, and I am not permitted to route
around it with `curl` or `python`. So the request half of the test has to run on
your machine. `tools/ummah_probe.sh` does it in one command.

## 3. The test design — because a 200 proves nothing on this API

The documentation is explicit: *"All endpoints work without authentication… Keys
are optional for higher limits."* So calling `/api/hadith/bukhari/3207` with the
key and getting a hadith back does **not** show the key was read, accepted, or
even parsed. An ignored key and a working key produce byte-identical hadith.

What separates them is the quota, so the probe calls the *same* endpoint three
ways and compares:

| Request | Expected if the key works |
| --- | --- |
| `GET /api/limits` with no key | anonymous tier — 5,000 / 15 min |
| `GET /api/limits` with `X-API-Key: umh_…` | raised tier — unlimited / 100K cap |
| `GET /api/limits` with a deliberately invalid `umh_…` string | rejected, or at least *not* the raised tier |
| `GET /api/usage` with the key | usage attributed to this key's identity |

Two assertions come out of that, and both must hold:

- the real key **changes** the limits relative to anonymous — otherwise the key is
  being ignored and the header name is wrong;
- the invalid key does **not** get the raised tier — otherwise any string is
  accepted and the "authenticated" state is an illusion.

The probe reads the `x-ratelimit-*` response headers as well as the bodies,
because a server that silently ignores an unknown header will still betray it in
the quota numbers.

## 4. The requests production will make

Base URL `https://ummahapi.com`. Every response is documented to carry `success`,
`service`, `data`, `timestamp`, so `data` is the only field a parser should reach
into and `success == false` is the error branch.

### Authentication: header, never query string

```http
GET /api/hadith/bukhari/3207 HTTP/1.1
Host: ummahapi.com
X-API-Key: umh_••••••••••••••••••••••••••••••••••••••••
Accept: application/json
```

The documentation offers `?apikey=umh_…` as an alternative. Production will not
use it. A key in a query string ends up in server access logs, proxy logs, crash
reports, `Referer` headers and — worst here — in any HTTP cache key, which would
mean a cached response keyed by the secret. The header form has none of those
paths. This matches the rule already enforced in `RemoteHadithSource`, which logs
the request **host and status code only**, never the URI, precisely so a key can
never reach a log line.

### Audio

```
GET /api/quran/reciters                    → reciter list (12) with ids + names
GET /api/quran/audio/1                     → full-surah audio for al-Fatihah
GET /api/quran/audio/2/255                 → single-ayah audio for 2:255
```

These replace two things the app currently guesses. `mp3quran.net` server paths
are assembled by hand, and `everyayah.com` folder names
(`Alafasy_128kbps`, `Abdul_Basit_Murattal_192kbps`, …) are hardcoded strings that
have never been verified against the host — a deviation already on the books. A
reciter list from the API is checkable metadata instead of a guess.

### Tafsir

```
GET /api/tafsir                            → available sources: key, name, language, author
GET /api/tafsir/{tafsir}/surah/2/ayah/255  → one ayah's commentary
GET /api/tafsir/{tafsir}/surah/1           → a whole surah in one call
```

`{tafsir}` is **not** guessable — it is whatever `/api/tafsir` returns as the
source key, which is why the probe reads the list first and substitutes the real
value rather than hardcoding `ibn-kathir`.

### Mutashabihat

```
GET /api/quran/mutashabihat                → index across 81 surahs
GET /api/quran/mutashabihat/2              → all similar-verse pairs in al-Baqarah
GET /api/quran/mutashabihat/2/255          → pairs for 2:255 specifically
```

### Hadith

```
GET /api/hadith/collections                → 10 collections with slugs + counts
GET /api/hadith/bukhari/3207               → one hadith by collection + number
GET /api/hadith/bukhari                    → collection listing (pagination unknown)
GET /api/hadith/search?q=patience          → topic discovery
GET /api/hadith/search?q=Abu%20Hurairah    → narrator discovery
```

`bukhari/3207` is deliberately not an arbitrary example: it is one of the five
citations the shipped corpus actually carries, so the probe tests a reference the
app will really request on day one.

### Word-by-word

```
GET /api/quran/words/2/255                 → per-word Arabic, transliteration, meaning
GET /api/quran/words/1                     → a whole surah
```

Not named in the brief, but worth flagging: word-level curation exists today for
al-Fatihah only, so layer 0 renders "no curated content" for 6,229 of 6,236 ayat.
This endpoint is the single largest content gain available.

### Collection slug mapping

The app's `HadithCollections` slugs were chosen before this API was in play, and
five of them may not line up with what `/api/hadith/collections` calls the same
book. Those the app defines: `bukhari`, `muslim`, `abudawud`, `tirmidhi`, `nasai`,
`ibnmajah`, `malik`, `ahmad`, `darimi`, `nawawi`, `bulugh`. UmmahAPI documents ten
collections including "Nawawi's 40" and "40 Hadith Qudsi" — note that the app's
`nawawi` slug is titled *Riyad as-Salihin*, which is a **different book** from
Nawawi's Forty. `/api/hadith/collections` settles it, and until it does, no
mapping table gets written.

### Proposed request construction (illustrative — not yet implemented)

```dart
// Awaiting approval. Shown so the auth path can be reviewed before it exists.
static const _base = 'https://ummahapi.com';

Map<String, String> _headers() {
  final key = dotenv.maybeGet('UMMAH_API_KEY')?.trim();
  return {
    'Accept': 'application/json',
    if (key != null && key.isNotEmpty) 'X-API-Key': key,
  };
}
```

Three properties of that shape are deliberate. The key is read at call time from
`dotenv`, not captured into a `const` or a field, so it exists in one place. A
missing key degrades to an anonymous request rather than throwing — the app stays
usable on a build where `.env` was not filled in. And the key never touches the
`Uri`, so no cache key, log line or error message can carry it.

## 5. Run this, and the remaining unknowns close

```bash
cd ~/develop/ummahapp && bash tools/ummah_probe.sh
```

Twenty requests, well inside even the anonymous 5,000 / 15 min budget. It prints
the authentication verdict and a compact schema outline for every endpoint, and
writes bodies plus response headers to `tools/.ummah_samples/` — which is inside
the folder I can read, so nothing needs pasting back. The key is read from `.env`,
sent only as a header, and never echoed: the script prints its length and the
`umh_` prefix and nothing else.

What that unblocks: the real field names for hadith text, grade and narrator; the
tafsir source keys and whether a surah-level call is small enough to cache whole;
the mutashabihat pair shape and whether it is directional; the reciter ids and
audio URL format; and whether `search` supports a narrator query well enough to
link a hadith to an existing Sahaba profile. Every one of those is currently a
guess, and a parser written against a guessed schema fails in the worst way
available — it compiles, it runs, and it shows an empty screen.
