# Mizan — Knowledge Platform Architecture

The plan for turning Mizan from eight good screens into a connected Islamic
knowledge platform. Written before the code so the shape is arguable; kept next
to the code so it stays honest.

Nothing here redesigns a screen. Every phase either adds a new screen built from
existing Mizan primitives, or appends a section to a screen that already exists.

---

## 0. What the app already has

The survey that this plan is built on, so you can check it rather than trust it.

**Verified corpus, in `assets/data/`:**

| Folder | Files | Shape |
|---|---|---|
| `discover/prophets` | 12 | `ProphetEntry` — 5 layers, quiz, `quranic_mention`, era |
| `discover/sahabah` | 44 | `SahabiEntry` — 5 layers, kunyah, tribe, era |
| `discover/seerah` | 33 | `SeerahEntry` — 5 layers, year, era, group |
| `discover/names` | 101 | `DivineName` — 5 layers |
| `ibn_kathir` | 114 | raw tafsir per surah |
| `ibn_kathir_processed` | 114 | list of `{surah, ayah, full_commentary}` |

Each layer is a `DiscoverLayer{layerNumber, title, subtitle, content, source,
quranRef?, hadithRef?}`. Across the corpus there are **583 non-null
`quran_ref`** and **408 non-null `hadith_ref`** values. That is the raw material
for the graph — roughly a thousand citations already written by hand and already
sourced.

**Two findings that change what is buildable.** Both are load-bearing; read them
before filing a bug about missing hadith text.

1. **`hadith_ref` is prose, not structured.** The brief specifies
   `{"collection": "bukhari", "number": "3326"}`. The corpus actually holds
   strings like:

   - `At-Tirmidhi no. 3620 — narration of Bahirah the monk`
   - `'The Throne of the Most Merciful shook at the death of Sa'd ibn Mu'adh' — narrated by Jabir, Sahih al-Bukhari and Sahih Muslim`
   - `Ibn Sa'd, Tabaqat, Vol. III`

   The first parses into a collection and a number. The second names two
   collections and no number. The third is a book, not a hadith. So the parser
   extracts a structured `HadithRef` **where a collection and a number are both
   present**, and everything else stays a named citation that is displayed and
   attributed but not fetched. It is never guessed at, never renumbered, never
   dropped.

2. **"UmmahAPI" does not exist in this repo.** `lib/services/hadith/hadith_api_service.dart`
   is a five-line stub. `api_constants.dart` points `hadithBaseUrl` at
   `api.sunnah.com/v1`, which requires a key that is not in `.env`. So the hadith
   system is built **offline-first behind a `HadithSource` interface**: memory →
   sqflite → bundled asset → remote adapter. Everything (detail screen, related
   sections, prefetch, offline badge) works with the remote adapter absent, and
   pointing it at a real endpoint later is one class.

---

## 1. Phase 1 — the graph

`lib/core/knowledge/`. Pure Dart, no Flutter import, no I/O. This is the layer
everything else is built on, so it stays testable and boring.

### `EntityRef` — one canonical string per thing

```
prophet:adam        sahabi:abu-bakr      seerah:hijrah
verse:2:30          hadith:bukhari:3326  theme:tawbah
name:ar-rahman      scholar:ibn-kathir   place:makkah
```

`EntityType` is the enum; `EntityRef` is `{type, id}` with `toString()`/`parse()`
round-tripping the canonical form. Every relationship, every route parameter,
every future embedding row is keyed by this string. Two entities are the same
entity iff their refs are equal — no name matching at runtime.

### `Evidence` — why an edge or a claim exists

A sealed hierarchy, so the UI switches exhaustively and a new kind cannot be
forgotten:

- `QuranEvidence{surah, ayah, quotedText?}` — tappable, opens the reader.
- `HadithEvidence{ref: HadithRef, quotedText?, narrator?}` — tappable, opens the
  hadith screen; text may be absent until fetched.
- `TafsirEvidence{scholar, surah, ayah}` — tappable, loads local Ibn Kathir JSON.
- `ScholarEvidence{scholarId, scholarName, remark?}` — opens the scholar page.
- `CitationEvidence{text}` — the honest fallback. A named source, rendered as
  written, not tappable. This is where the unparseable prose refs land.

### `Relation` — a typed, sourced edge

`Relation{from, to, kind, note?, evidence: List<Evidence>, derived: bool}`.

`RelationKind` covers `mentions, mentionedIn, relatedTo, parentOf, childOf,
spouseOf, opposedBy, successorOf, predecessorOf, narratedBy, narrates,
occurredAt, aboutTheme, commentedOnBy, commentsOn, partOfJourney`.

**`derived` is the whole integrity story.** A derived edge was computed from a
citation that already exists in the corpus, and carries the layer and `source`
string it came from, so any edge can be traced back to a file on disk. A curated
edge (`derived: false`) came from `assets/data/knowledge/edges.json`, which only
ever contains relationships that are stated in the corpus text or in a cited
source. Nothing in this system invents a relationship between two people because
they seem related.

### `KnowledgeEntity` and `KnowledgeGraph`

`KnowledgeEntity{ref, title, titleArabic?, transliteration?, subtitle?, teaser?,
sections: List<KnowledgeSection>, evidence, tags, metadata}` — a normalised view
over the four existing corpus types plus the new ones, so one screen can render
any of them.

`KnowledgeGraph` holds `byId`, `byType`, and an adjacency map built **with
reverse edges inserted automatically** — declaring "Bukhari 3326 mentions Adam"
gives you Adam → that hadith for free, which is what makes navigation endless
without anybody hand-writing the mirror of 1,000 edges. Its API is
`neighbors(ref, {kind, type})`, `relationsFor(ref)`, `search(query)` and
`exportChunks()`.

The graph is built once at first read, cached in a Riverpod provider, and never
mutated.

---

## 2. Phase 1 (b) — the builder

`reference_parser.dart` turns corpus strings into `Evidence`:

- `Quran 8:30 — '…'` → `QuranEvidence(8, 30, quoted)`. 583 of these.
- `Sahih al-Bukhari no. 3326` / `Bukhari 3326` / `Muslim, no. 2652` →
  `HadithEvidence`. Collection aliases are matched against a table of the nine
  books plus their common English spellings.
- `Tafsir Ibn Kathir on 2:30` → `TafsirEvidence`.
- Anything else → `CitationEvidence`, verbatim.

`graph_builder.dart` walks the four corpus folders and emits:

- one entity per prophet, sahabi, seerah event, divine name;
- one `verse:S:A` entity per distinct cited ayah;
- one `hadith:collection:number` entity per parsed hadith ref;
- `mentions` / `mentionedIn` edges between an entity and everything its layers
  cite, each edge carrying the layer number and the layer's own `source` string;
- co-citation edges: two entities that cite the same ayah or the same hadith are
  linked `relatedTo` **with that shared citation as the evidence**. This is the
  cheap, honest version of "connected people" — the connection is not asserted,
  it is *displayed as* "both are discussed at Quran 2:30".

Result, without a word of new Islamic content: every prophet, sahabi and seerah
event arrives with connected verses, connected hadith and connected people, and
each connection shows the citation that produced it.

---

## 3. Phase 2 — connected sections

One widget, `ConnectedSection`, parameterised by `RelationKind` and
`EntityType`, built from `MizanSectionLabel` + `MizanRow` + `MizanSurface`. It
renders nothing when there are no neighbours, so no screen grows an empty
heading.

One screen, `KnowledgeEntityScreen`, renders any `KnowledgeEntity`: header,
sections, evidence, then the connected sections. Themes, scholars, places and
events all route through it — six page types, one page.

The existing prophet / sahabi / seerah / name detail screens keep their current
layout exactly and get the connected sections **appended below** what they
already show. That is the whole UI change to existing screens.

Navigation is endless because every row in a connected section pushes another
entity page, which itself has connected sections.

---

## 4. Phase 3 — evidence mode

Every section that makes a claim already carries `source` in the corpus. Evidence
mode surfaces it as a row of chips under the section body:

- **Quran chip** → sheet with the ayah, the chosen translation, and a link into
  the reader at that ayah (where the five layers already live).
- **Hadith chip** → the hadith screen: Arabic, translation, narrator, collection,
  number, grade — or "not downloaded yet" if no source has it.
- **Tafsir chip** → the Ibn Kathir passage for that ayah, from
  `ibn_kathir_processed`.
- **Scholar chip** → the scholar page, filtered to this topic.
- **Named citation** → rendered as text, because that is all we honestly have.

The chip row reuses the stacked full-width citation rows already shipped in
`layer_story_scaffold.dart` (they were changed from pills precisely because long
citations must not be clipped).

---

## 5. Phase 3A — hadith as a first-class entity

`HadithRef{collection, number}` with a canonical string. `HadithRepository`
resolves in order: in-memory map → sqflite table `hadith_cache` → bundled asset
`assets/data/knowledge/hadith/<collection>/<number>.json` → remote adapter.
A miss is a normal, displayable state, not an error.

`HadithSource` is the interface; `RemoteHadithSource` is a thin adapter with a
configurable base URL and header, disabled unless a key is present. Prefetch is a
small queue: opening an entity enqueues its hadith refs, so Adam's Bukhari 3326
and Muslim 2652 arrive without blocking the page.

Because a hadith is an entity, it has its own page with connected people,
connected verses, connected themes and connected events — derived from the same
co-citation logic as everything else.

---

## 6. Phases 4–6 — themes, journeys, scholars

`assets/data/knowledge/` holds `themes.json`, `scholars.json`, `places.json`,
`journeys.json`, `edges.json`. These are **structure**, not content:

- A **theme** is a name, an Arabic name, a short definition, and a list of entity
  refs that belong to it. Its page then aggregates their verses and hadith
  automatically through the graph. The definition text is the only prose, and it
  is the kind of one-line gloss that appears in every dictionary of Islamic
  terms; anything beyond that waits for a cited source.
- A **journey** is an ordered list of steps, each step an entity ref. Step notes
  reuse the entity's own `teaser` from the corpus — zero new prose.
- A **scholar** has a name, dates, school, and a list of works. `biography` and
  `methodology` are **left null** until verified text is supplied; the page shows
  the connected verses and topics derived from which layers cite that scholar,
  which is real information rather than a paraphrase.

Journey Mode is a linear walk over a journey's steps with the graph supplying
everything around each step. It is not a course, has no score, and unlocks
nothing — the prohibition list rules out gamification and this respects it.

---

## 7. Phase 7 — RAG preparation, not RAG

`RetrievalChunk{id, entityRef, sectionTitle, text, citations, tags, metadata}`
and `KnowledgeGraph.exportChunks()`. Every chunk is independently attributable:
it knows its entity, its section, and the citations inside it. Nothing embeds,
nothing calls a model, nothing ships an AI feature. The point is that when
retrieval is added, the answer can cite the same way a layer does — because the
chunk already carries the citation.

---

## 8. Order of work

1. `lib/core/knowledge/` core — refs, evidence, relations, entity, graph.
2. Parser + builder over the existing corpus.
3. `assets/data/knowledge/` structure files + `pubspec.yaml` registration.
4. `ConnectedSection` + `KnowledgeEntityScreen`.
5. Evidence chips + evidence sheet.
6. Hadith ref system, repository, prefetch, detail screen.
7. Retrieval export.
8. Routes under `/knowledge/...` inside the existing `ShellRoute`; connected
   sections appended to the existing detail screens; Themes and Journeys reachable
   from Discover.

## 9. Rules this plan is bound by

- Every claim cites a Quran ayah, a hadith with book and number, or a named
  tafsir — or it is not shipped.
- No Islamic content is invented, ever. Structure and navigation are ours; text
  is the corpus's.
- A derived edge says so, and can be traced to the file that produced it.
- No screen is redesigned. Additions use existing Mizan primitives only.
- One entry point per destination, and a control keeps its label everywhere.
