import os
path = os.path.expanduser('~/develop/ummahapp/lib/features/discover/providers/discover_providers.dart')
with open(path) as f:
    text = f.read()

old = '''  bool isEntryUnlocked(String entryId, int sequenceNumber,
      List<String> orderedIds) {
    if (sequenceNumber == 1) return true;
    final predecessorId = orderedIds[sequenceNumber - 2]; // 0-indexed
    final pred = state.valueOrNull?[predecessorId];
    return pred?.entryCompleted ?? false;
  }'''

new = '''  bool isEntryUnlocked(String entryId, int sequenceNumber,
      List<String> orderedIds) {
    if (sequenceNumber == 1) return true;
    // Find this entry's position in the ordered list, then get the one before it
    final myIndex = orderedIds.indexOf(entryId);
    if (myIndex <= 0) return true; // first in list or not found
    final predecessorId = orderedIds[myIndex - 1];
    final pred = state.valueOrNull?[predecessorId];
    return pred?.entryCompleted ?? false;
  }'''

if old in text:
    text = text.replace(old, new)
    with open(path, 'w') as f:
        f.write(text)
    print('✓ Fixed')
else:
    print('WARN: pattern not found')
