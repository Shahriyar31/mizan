#!/usr/bin/env python3
"""Validate every Discover content JSON against the Dart models.

Run:  python3 tools/validate_discover.py

Mirrors the `fromJson` factories in
lib/features/discover/models/discover_models.dart. A missing or wrongly-typed
field here becomes a runtime crash on device, so this is the cheap gate to run
before `flutter run`. Also enforces the Citation Lock: every layer needs a
`source`, and every quiz question needs a `citation`.
"""
import json
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
BASE = os.path.join(ROOT, "assets", "data", "discover")

LAYER_REQUIRED = ["layer_number", "title", "subtitle", "content", "source"]
QUIZ_REQUIRED = ["number", "type", "prompt", "options", "citation",
                 "scholar_reflection"]

# folder -> required top-level fields (from each Dart fromJson factory)
SPEC = {
    "prophets": ["id", "sequence_number", "name_arabic", "name_english",
                 "name_translit", "quranic_mention", "era", "teaser",
                 "layers", "quiz"],
    "sahabah": ["id", "sequence_number", "name_arabic", "name_english",
                "kunyah", "tribe", "era", "teaser", "layers", "quiz"],
    "names": ["id", "number", "arabic", "translit", "meaning_brief",
              "layers", "quiz"],
    "seerah": ["id", "sequence_number", "title", "title_arabic", "year",
               "era", "teaser", "layers", "quiz"],
}

errors = []
warnings = []


def err(where, msg):
    errors.append("%s: %s" % (where, msg))


def warn(where, msg):
    warnings.append("%s: %s" % (where, msg))


def check_entry(folder, fname, data):
    where = "%s/%s" % (folder, fname)

    for field in SPEC[folder]:
        if field not in data:
            err(where, "missing top-level field '%s'" % field)

    if not isinstance(data.get("id"), str) or not data.get("id"):
        err(where, "'id' must be a non-empty string")

    seq_field = "number" if folder == "names" else "sequence_number"
    if seq_field in data and not isinstance(data[seq_field], int):
        err(where, "'%s' must be an int, got %r"
            % (seq_field, type(data[seq_field]).__name__))

    # Optional browse-section heading (ProphetEntry.group / SeerahEntry.group).
    # Optional in the model, but if present it must be usable as a header.
    if "group" in data:
        if not isinstance(data["group"], str) or not data["group"].strip():
            err(where, "'group' must be a non-empty string when present")

    layers = data.get("layers")
    if not isinstance(layers, list):
        err(where, "'layers' must be a list")
    else:
        if len(layers) != 5:
            warn(where, "has %d layers (expected 5)" % len(layers))
        seen = set()
        for i, layer in enumerate(layers):
            lw = "%s layer[%d]" % (where, i)
            if not isinstance(layer, dict):
                err(lw, "not an object")
                continue
            for field in LAYER_REQUIRED:
                if field not in layer:
                    err(lw, "missing '%s'" % field)
                elif field == "layer_number":
                    if not isinstance(layer[field], int):
                        err(lw, "'layer_number' must be an int")
                elif not isinstance(layer[field], str) or not layer[field].strip():
                    err(lw, "'%s' must be a non-empty string" % field)
            num = layer.get("layer_number")
            if num in seen:
                err(lw, "duplicate layer_number %r" % num)
            seen.add(num)
            # Optional refs must be string-or-null, never another type.
            for field in ("quran_ref", "hadith_ref"):
                if field in layer and layer[field] is not None:
                    if not isinstance(layer[field], str):
                        err(lw, "'%s' must be a string or null" % field)

    quiz = data.get("quiz")
    if not isinstance(quiz, list):
        err(where, "'quiz' must be a list")
    else:
        if len(quiz) != 10:
            warn(where, "has %d quiz questions (expected 10)" % len(quiz))
        factual = 0
        for i, q in enumerate(quiz):
            qw = "%s quiz[%d]" % (where, i)
            if not isinstance(q, dict):
                err(qw, "not an object")
                continue
            for field in QUIZ_REQUIRED:
                if field not in q:
                    err(qw, "missing '%s'" % field)
            if not isinstance(q.get("number"), int):
                err(qw, "'number' must be an int")
            qtype = q.get("type")
            if qtype not in ("factual", "reflective"):
                err(qw, "'type' must be 'factual' or 'reflective', got %r" % qtype)
            options = q.get("options")
            if not isinstance(options, list) or not options:
                err(qw, "'options' must be a non-empty list")
            else:
                ids = []
                for o in options:
                    if not isinstance(o, dict):
                        err(qw, "option is not an object")
                        continue
                    if not isinstance(o.get("id"), str):
                        err(qw, "option 'id' must be a string")
                    if not isinstance(o.get("text"), str) or not o.get("text").strip():
                        err(qw, "option 'text' must be a non-empty string")
                    ids.append(o.get("id"))
                if len(set(ids)) != len(ids):
                    err(qw, "duplicate option ids %r" % ids)
                correct = q.get("correct_option_id")
                if qtype == "factual":
                    factual += 1
                    if correct not in ids:
                        err(qw, "factual 'correct_option_id' %r not among options %r"
                            % (correct, ids))
                elif correct is not None:
                    err(qw, "reflective question must have null correct_option_id")
            # Citation Lock
            cit = q.get("citation")
            if not isinstance(cit, str) or not cit.strip():
                err(qw, "Citation Lock: 'citation' must be a non-empty string")
        if quiz and factual == 0:
            warn(where, "no factual questions — quiz cannot be scored")


def main():
    total = 0
    for folder in sorted(SPEC):
        path = os.path.join(BASE, folder)
        if not os.path.isdir(path):
            err(folder, "folder missing at %s" % path)
            continue

        disk = sorted(f for f in os.listdir(path)
                      if f.endswith(".json") and f != "index.json")

        index_path = os.path.join(path, "index.json")
        if not os.path.exists(index_path):
            err(folder, "index.json missing")
            index = []
        else:
            try:
                index = json.load(open(index_path, encoding="utf-8"))
            except ValueError as e:
                err("%s/index.json" % folder, "invalid JSON: %s" % e)
                index = []
            if not isinstance(index, list):
                err("%s/index.json" % folder, "must be a JSON list")
                index = []
            else:
                missing_file = [f for f in index if f not in disk]
                not_indexed = [f for f in disk if f not in index]
                if missing_file:
                    err(folder, "index lists files that do not exist: %s" % missing_file)
                if not_indexed:
                    err(folder, "files on disk not listed in index: %s" % not_indexed)

        ids, seqs = {}, {}
        for fname in disk:
            total += 1
            try:
                data = json.load(open(os.path.join(path, fname), encoding="utf-8"))
            except ValueError as e:
                err("%s/%s" % (folder, fname), "invalid JSON: %s" % e)
                continue
            check_entry(folder, fname, data)

            eid = data.get("id")
            if eid in ids:
                err(folder, "duplicate id %r in %s and %s" % (eid, ids[eid], fname))
            else:
                ids[eid] = fname

            seq_field = "number" if folder == "names" else "sequence_number"
            seq = data.get(seq_field)
            if seq in seqs:
                err(folder, "duplicate %s %r in %s and %s"
                    % (seq_field, seq, seqs[seq], fname))
            else:
                seqs[seq] = fname

        print("%-9s %3d entries" % (folder, len(disk)))

    print("\nchecked %d files" % total)
    if warnings:
        print("\n%d warning(s):" % len(warnings))
        for w in warnings:
            print("  ! %s" % w)
    if errors:
        print("\n%d ERROR(S):" % len(errors))
        for e in errors:
            print("  x %s" % e)
        return 1
    print("\nAll Discover content valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
