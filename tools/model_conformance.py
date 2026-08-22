#!/usr/bin/env python3
"""Strict Dart-model conformance check for Discover content.

validate_discover.py checks editorial rules (Citation Lock, quiz shape).
This script checks something different and equally fatal: whether each JSON
file can actually be parsed by the Dart `fromJson` factories in
lib/features/discover/models/discover_models.dart.

A missing required key throws in Dart. DiscoverRepository._loadFolder catches
that and SKIPS the file, so a bad file does not crash the app — it silently
disappears from the list. That failure mode is invisible in release builds,
which is why it is checked here.

Keep this file in sync with discover_models.dart. If you add a required field
to a model, add it here in the same commit.
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
BASE = ROOT / "assets" / "data" / "discover"

# key -> python type expected by the Dart cast
LAYER_REQ = {
    "layer_number": int,
    "title": str,
    "subtitle": str,
    "content": str,
    "source": str,
}
LAYER_OPT = {"quran_ref": str, "hadith_ref": str}

QUIZ_REQ = {
    "number": int,
    "type": str,
    "prompt": str,
    "citation": str,
    "scholar_reflection": str,
}
QUIZ_OPT = {"correct_option_id": str, "slider_label": str}

MODELS = {
    "prophets": {
        "id": str,
        "sequence_number": int,
        "name_arabic": str,
        "name_english": str,
        "name_translit": str,
        "quranic_mention": str,
        "era": str,
        "teaser": str,
    },
    "sahabah": {
        "id": str,
        "sequence_number": int,
        "name_arabic": str,
        "name_english": str,
        "kunyah": str,
        "tribe": str,
        "era": str,
        "teaser": str,
    },
    "names": {
        "id": str,
        "number": int,
        "arabic": str,
        "translit": str,
        "meaning_brief": str,
    },
    "seerah": {
        "id": str,
        "sequence_number": int,
        "title": str,
        "title_arabic": str,
        "year": str,
        "era": str,
        "teaser": str,
    },
}
OPTIONAL = {
    "prophets": {"group": str},
    "seerah": {"group": str},
    "sahabah": {},
    "names": {},
}

errors = []


def check(where, data, required, optional):
    for key, typ in required.items():
        if key not in data:
            errors.append(f"{where}: missing required key '{key}'")
        elif not isinstance(data[key], typ) or isinstance(data[key], bool):
            errors.append(
                f"{where}: '{key}' is {type(data[key]).__name__}, "
                f"Dart casts it to {typ.__name__}"
            )
    for key, typ in optional.items():
        if key in data and data[key] is not None and not isinstance(data[key], typ):
            errors.append(f"{where}: optional '{key}' has wrong type")


def main():
    total = 0
    for folder, required in MODELS.items():
        d = BASE / folder
        if not d.is_dir():
            errors.append(f"{folder}: folder missing")
            continue
        for path in sorted(d.glob("*.json")):
            if path.name == "index.json":
                continue
            total += 1
            where = f"{folder}/{path.name}"
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except Exception as exc:  # noqa: BLE001
                errors.append(f"{where}: not valid JSON — {exc}")
                continue
            if not isinstance(data, dict):
                errors.append(f"{where}: top level must be an object")
                continue
            check(where, data, required, OPTIONAL[folder])

            layers = data.get("layers")
            if not isinstance(layers, list) or not layers:
                errors.append(f"{where}: 'layers' must be a non-empty list")
            else:
                for i, layer in enumerate(layers):
                    if not isinstance(layer, dict):
                        errors.append(f"{where}: layers[{i}] is not an object")
                        continue
                    check(f"{where} layers[{i}]", layer, LAYER_REQ, LAYER_OPT)

            quiz = data.get("quiz")
            if not isinstance(quiz, list) or not quiz:
                errors.append(f"{where}: 'quiz' must be a non-empty list")
            else:
                for i, q in enumerate(quiz):
                    if not isinstance(q, dict):
                        errors.append(f"{where}: quiz[{i}] is not an object")
                        continue
                    check(f"{where} quiz[{i}]", q, QUIZ_REQ, QUIZ_OPT)
                    if q.get("type") not in ("factual", "reflective"):
                        errors.append(
                            f"{where} quiz[{i}]: 'type' must be "
                            f"'factual' or 'reflective', got {q.get('type')!r}"
                        )
                    opts = q.get("options")
                    if not isinstance(opts, list) or len(opts) < 2:
                        errors.append(f"{where} quiz[{i}]: needs >= 2 options")
                    else:
                        for j, o in enumerate(opts):
                            if not isinstance(o, dict):
                                errors.append(
                                    f"{where} quiz[{i}].options[{j}] not an object"
                                )
                                continue
                            for key in ("id", "text"):
                                if not isinstance(o.get(key), str):
                                    errors.append(
                                        f"{where} quiz[{i}].options[{j}]: "
                                        f"'{key}' must be a string"
                                    )

    print(f"model-conformance: checked {total} files")
    if errors:
        for e in errors:
            print("  " + e)
        print(f"\n{len(errors)} problem(s) — these files would be SILENTLY SKIPPED at runtime.")
        return 1
    print("All files parse under the Dart models.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
