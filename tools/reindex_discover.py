#!/usr/bin/env python3
"""Rebuild every Discover index.json from the files actually on disk.

Run after adding or removing content:  python3 tools/reindex_discover.py

The app loads `index.json` and nothing else, so a file that exists but is not
indexed is invisible, and an indexed file that does not exist is a crash. This
script makes the index a derived artefact instead of something hand-edited.
Entries are ordered by sequence_number (or `number` for the 99 Names) so the
UI's first-seen group order is chronological.
"""
import json
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
BASE = os.path.join(ROOT, "assets", "data", "discover")
SORT_KEY = {"names": "number"}

def main():
    for folder in sorted(os.listdir(BASE)):
        path = os.path.join(BASE, folder)
        if not os.path.isdir(path):
            continue
        key = SORT_KEY.get(folder, "sequence_number")
        files = [f for f in os.listdir(path)
                 if f.endswith(".json") and f != "index.json"]
        def order(fname):
            with open(os.path.join(path, fname), encoding="utf-8") as fh:
                return json.load(fh).get(key, 1 << 30)
        files.sort(key=order)
        with open(os.path.join(path, "index.json"), "w", encoding="utf-8") as fh:
            json.dump(files, fh, indent=2)
            fh.write("\n")
        print("%-9s %3d entries indexed" % (folder, len(files)))
    return 0

if __name__ == "__main__":
    sys.exit(main())
