/// SharedContent — a denormalised snapshot of a piece of app content
/// that a user shares to their Halaqa (circle) or to Al-Minbar (public feed).
///
/// Why a *snapshot* and not just a reference (content_id + content_type)?
///   A social feed must render instantly and stay readable forever. If we
///   only stored an id and re-fetched the ayah/hadith/story every time the
///   card scrolls into view, the feed would be slow and could break if the
///   source content ever changed. So when a user shares something, we copy
///   the few display fields we need (title, a short excerpt, the citation)
///   into the share itself. This is a normal, deliberate pattern for feeds.
///
/// The original is still identifiable via [contentType] + [contentId], and
/// [routePath] lets a card tap through to the full content screen.
library;

import 'dart:convert';

/// The five (plus Seerah) content kinds that can be shared. The wire names
/// match the CHECK constraint in supabase/migrations/001_initial_schema.sql
/// so a future Supabase repository can store the exact same strings.
enum ContentType { quran, hadith, sahabi, name, prophet, seerah }

extension ContentTypeX on ContentType {
  /// Stable string stored in the database — never change these.
  String get wireName => switch (this) {
        ContentType.quran => 'quran',
        ContentType.hadith => 'hadith',
        ContentType.sahabi => 'sahabi',
        ContentType.name => 'name',
        ContentType.prophet => 'prophet',
        ContentType.seerah => 'seerah',
      };

  /// Human-readable label for badges, e.g. shown on a Minbar card.
  String get label => switch (this) {
        ContentType.quran => 'Quran',
        ContentType.hadith => 'Hadith',
        ContentType.sahabi => 'Companion',
        ContentType.name => 'Divine Name',
        ContentType.prophet => 'Prophet',
        ContentType.seerah => 'Seerah',
      };

  static ContentType fromWire(String? s) => switch (s) {
        'quran' => ContentType.quran,
        'hadith' => ContentType.hadith,
        'sahabi' => ContentType.sahabi,
        'name' => ContentType.name,
        'prophet' => ContentType.prophet,
        'seerah' => ContentType.seerah,
        _ => ContentType.quran,
      };
}

class SharedContent {
  const SharedContent({
    required this.contentType,
    required this.contentId,
    required this.title,
    required this.excerpt,
    required this.citationSource,
    this.titleArabic,
    this.citationDetail,
    this.routePath,
  });

  /// What kind of content this is (drives the card's visual material).
  final ContentType contentType;

  /// Identifier of the source content. "2:255" for Quran (surah:ayah),
  /// "adam"/"abu_bakr"/"ar_rahman" for Discover entries, a hadith ref, etc.
  final String contentId;

  /// English display title, e.g. "Ayat al-Kursi", "Adam", "Ar-Rahmān".
  final String title;

  /// Arabic title/name if there is one (rendered in Amiri). Optional.
  final String? titleArabic;

  /// A short passage shown on the card — a translation line or a teaser.
  final String excerpt;

  /// Primary citation, e.g. "Quran 2:255" or "Ibn Kathir, Stories of the Prophets".
  final String citationSource;

  /// Secondary citation detail, e.g. "Narrated by Abu Hurayrah · Grade: Sahih".
  final String? citationDetail;

  /// GoRouter path to open the full content, e.g. "/quran/2" or
  /// "/discover/prophet/adam". Nullable so old/unknown content stays safe.
  final String? routePath;

  // ── JSON (stored as a single TEXT column: content_json) ──────────
  Map<String, dynamic> toJson() => {
        'content_type': contentType.wireName,
        'content_id': contentId,
        'title': title,
        if (titleArabic != null) 'title_arabic': titleArabic,
        'excerpt': excerpt,
        'citation_source': citationSource,
        if (citationDetail != null) 'citation_detail': citationDetail,
        if (routePath != null) 'route_path': routePath,
      };

  factory SharedContent.fromJson(Map<String, dynamic> j) => SharedContent(
        contentType: ContentTypeX.fromWire(j['content_type'] as String?),
        contentId: j['content_id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        titleArabic: j['title_arabic'] as String?,
        excerpt: j['excerpt'] as String? ?? '',
        citationSource: j['citation_source'] as String? ?? '',
        citationDetail: j['citation_detail'] as String?,
        routePath: j['route_path'] as String?,
      );

  /// Convenience for the DB layer — encode/decode the whole object as a string.
  String encode() => jsonEncode(toJson());

  factory SharedContent.decode(String source) =>
      SharedContent.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
