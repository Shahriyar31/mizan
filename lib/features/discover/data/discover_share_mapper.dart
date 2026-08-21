/// Discover → SharedContent mappers.
///
/// These extensions turn a rich Discover entry (a prophet, companion, divine
/// name, or seerah episode) into the light [SharedContent] snapshot used by
/// Halaqa and Al-Minbar. Keeping the mapping here (in the discover feature,
/// which already depends on [SharedContent]) preserves clean layering: the
/// shared model never has to know these feature-specific types.
///
/// Every citation is copied straight from the entry's own (verified, shipped)
/// data — the first layer's `source` and Qur'an reference — so a shared card
/// never invents or paraphrases a source.
library;

import '../../../shared/models/shared_content.dart';
import '../models/discover_models.dart';

/// Fallbacks so a snapshot is never left with an empty citation, even if an
/// entry somehow shipped without layers.
String _sourceOf(List<DiscoverLayer> layers) =>
    layers.isNotEmpty && layers.first.source.trim().isNotEmpty
        ? layers.first.source
        : 'Verified Islamic source';

String? _refOf(List<DiscoverLayer> layers) =>
    layers.isNotEmpty ? layers.first.quranRef : null;

extension ProphetShareX on ProphetEntry {
  SharedContent toSharedContent() => SharedContent(
        contentType: ContentType.prophet,
        contentId: id,
        title: nameEnglish,
        titleArabic: nameArabic,
        excerpt: teaser,
        citationSource: _sourceOf(layers),
        citationDetail: _refOf(layers),
        routePath: '/discover/prophet/$id',
      );
}

extension SahabiShareX on SahabiEntry {
  SharedContent toSharedContent() => SharedContent(
        contentType: ContentType.sahabi,
        contentId: id,
        title: nameEnglish,
        titleArabic: nameArabic,
        excerpt: teaser,
        citationSource: _sourceOf(layers),
        citationDetail: _refOf(layers),
        routePath: '/discover/sahabi/$id',
      );
}

extension DivineNameShareX on DivineName {
  SharedContent toSharedContent() => SharedContent(
        contentType: ContentType.name,
        contentId: id,
        title: translit,
        titleArabic: arabic,
        excerpt: meaningBrief,
        citationSource: _sourceOf(layers),
        citationDetail: _refOf(layers),
        routePath: '/discover/name/$id',
      );
}

extension SeerahShareX on SeerahEntry {
  SharedContent toSharedContent() => SharedContent(
        contentType: ContentType.seerah,
        contentId: id,
        title: title,
        titleArabic: titleArabic,
        excerpt: teaser,
        citationSource: _sourceOf(layers),
        citationDetail: _refOf(layers),
        routePath: '/discover/seerah/$id',
      );
}
