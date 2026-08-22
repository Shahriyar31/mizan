/// Reciter + Moshaf — MP3Quran API v3 shapes (mp3quran.net/api).
///
/// A reciter can have multiple "moshaf" (riwayah/recitation set) entries.
/// Each moshaf has its own audio server and its own subset of surahs
/// ([surahList]) — never assume a moshaf has all 114.
library;

class Moshaf {
  const Moshaf({
    required this.id,
    required this.name,
    required this.server,
    required this.surahTotal,
    required this.moshafType,
    required this.surahList,
  });

  final int id;
  final String name; // e.g. "Rewayat Hafs A'n Assem - Murattal"
  final String server; // base URL, e.g. https://server6.mp3quran.net/akdr/
  final int surahTotal;
  final int moshafType;
  final Set<int> surahList; // surah numbers this moshaf actually has

  bool hasSurah(int surahNumber) => surahList.contains(surahNumber);

  /// Full MP3 URL for a surah, e.g. "{server}001.mp3". Confirmed against
  /// the live API — surah number zero-padded to 3 digits, ".mp3".
  String audioUrlFor(int surahNumber) {
    final padded = surahNumber.toString().padLeft(3, '0');
    final base = server.endsWith('/') ? server : '$server/';
    return '$base$padded.mp3';
  }

  factory Moshaf.fromJson(Map<String, dynamic> j) => Moshaf(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        server: j['server'] as String? ?? '',
        surahTotal: j['surah_total'] as int? ?? 0,
        moshafType: j['moshaf_type'] as int? ?? 0,
        surahList: (j['surah_list'] as String? ?? '')
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>()
            .toSet(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'server': server,
        'surah_total': surahTotal,
        'moshaf_type': moshafType,
        'surah_list': surahList.join(','),
      };
}

class Reciter {
  const Reciter({required this.id, required this.name, required this.moshaf});

  final int id;
  final String name;
  final List<Moshaf> moshaf;

  factory Reciter.fromJson(Map<String, dynamic> j) => Reciter(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        moshaf: (j['moshaf'] as List? ?? [])
            .map((m) => Moshaf.fromJson(m as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'moshaf': moshaf.map((m) => m.toJson()).toList(),
      };
}
