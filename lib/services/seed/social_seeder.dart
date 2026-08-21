/// SocialSeeder — one-time demo data for Halaqa and Al-Minbar.
///
/// The social features look dead on a fresh install: an empty circle and an
/// empty feed teach the user nothing. This seeder plants a believable circle
/// (several members, a few shares, a spread of reactions, and one member who's
/// gone quiet so the nudge is visible) and a small public feed.
///
/// Two rules keep it honest:
///  1. Every shared card references REAL, shipped Discover content (loaded via
///     [DiscoverRepository]) — the seeder never invents an ayah, hadith, or
///     story. The only free text is members' short personal notes, which are
///     ordinary human reflections, not religious claims.
///  2. It runs only when [FeatureFlags.seedSocialDemo] is on AND the tables are
///     empty (a first-run heuristic), so it never duplicates or fights the
///     user's own data. Turn the flag off for production.
library;

import 'package:sqflite/sqflite.dart';

import '../../core/config/feature_flags.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/logger.dart';
import '../../features/discover/data/discover_repository.dart';
import '../../features/discover/data/discover_share_mapper.dart';
import '../../features/halaqa/data/local_halaqa_repository.dart';
import '../../features/halaqa/models/halaqa_models.dart';
import '../../features/identity/data/identity_repository.dart';
import '../../features/minbar/data/local_minbar_repository.dart';
import '../../features/minbar/models/minbar_models.dart';
import '../../shared/models/reaction_type.dart';
import '../../shared/models/shared_content.dart';
import '../../shared/models/user_profile.dart';
import '../database/database_service.dart';

class SocialSeeder {
  SocialSeeder._();

  static const String _tag = 'SocialSeeder';

  /// Seed demo data if the flag is on and the tables are empty. Never throws —
  /// a seed failure must not stop the app from launching.
  static Future<void> run() async {
    if (!FeatureFlags.seedSocialDemo) return;
    try {
      final me = await IdentityRepository().ensureProfile();
      final content = await _loadContent();
      if (content.isEmpty) {
        AppLogger.warning('No Discover content to seed from — skipping',
            tag: _tag);
        return;
      }
      await _seedHalaqa(me, content);
      await _seedMinbar(me, content);
    } catch (e) {
      AppLogger.error('Social seed skipped due to error: $e', tag: _tag);
    }
  }

  // ── Load real, shipped content as snapshots ──────────────────────
  static Future<Map<String, SharedContent>> _loadContent() async {
    final map = <String, SharedContent>{};

    Future<void> add(String key, Future<SharedContent?> Function() f) async {
      try {
        final c = await f();
        if (c != null) map[key] = c;
      } catch (_) {/* skip anything that fails to load */}
    }

    final prophets = await DiscoverRepository.getProphets();
    final sahabah = await DiscoverRepository.getSahabah();
    final names = await DiscoverRepository.getNames();
    final seerah = await DiscoverRepository.getSeerah();

    await add('adam', () async => _byId(prophets, 'adam')?.toSharedContent());
    await add(
        'ibrahim', () async => _byId(prophets, 'ibrahim')?.toSharedContent());
    await add(
        'abu_bakr', () async => _byId(sahabah, 'abu_bakr')?.toSharedContent());
    await add('bilal', () async => _byId(sahabah, 'bilal')?.toSharedContent());
    await add('an_noor', () async => _byId(names, 'an_noor')?.toSharedContent());
    await add(
        'ar_rahman', () async => _byId(names, 'ar_rahman')?.toSharedContent());
    await add('first_revelation',
        () async => _byId(seerah, 'first_revelation')?.toSharedContent());
    await add('hijra', () async => _byId(seerah, 'hijra')?.toSharedContent());

    return map;
  }

  static T? _byId<T>(List<T> list, String id) {
    for (final e in list) {
      final eid = (e as dynamic).id as String?;
      if (eid == id) return e;
    }
    return null;
  }

  // ── Halaqa: a believable "Dawn Circle" ───────────────────────────
  static Future<void> _seedHalaqa(
    UserProfile me,
    Map<String, SharedContent> content,
  ) async {
    final repo = LocalHalaqaRepository();
    final existing = await repo.getHalaqasForUser(me.id);
    if (existing.isNotEmpty) return; // already has a circle — leave it alone

    final db = await DatabaseService.instance.database;
    final now = DateTime.now();

    final halaqa = Halaqa(
      id: IdGenerator.uuid(),
      name: 'Dawn Circle',
      createdBy: me.id,
      inviteCode: IdGenerator.inviteCode(),
      createdAt: now.subtract(const Duration(days: 6)),
    );

    // Demo members. "me" is the creator; Zayd is deliberately quiet (last
    // active 5 days ago) so the nudge card has someone to point at.
    final yusuf = _member(halaqa.id, 'Yusuf', now.subtract(const Duration(hours: 4)));
    final layla = _member(halaqa.id, 'Layla', now.subtract(const Duration(hours: 30)));
    final omar = _member(halaqa.id, 'Omar', now.subtract(const Duration(hours: 6)));
    final zayd = _member(halaqa.id, 'Zayd', now.subtract(const Duration(days: 5)));

    // The creator as a member row — one canonical HalaqaMember we reuse for the
    // creator's insert, their own seed share, and the reaction pool. Keeping it
    // a HalaqaMember (not the raw UserProfile) is what makes the types line up.
    final meMember = HalaqaMember(
      id: IdGenerator.uuid(),
      halaqaId: halaqa.id,
      userId: me.id,
      displayName: me.displayName,
      joinedAt: halaqa.createdAt,
      lastActiveAt: now,
    );

    final shares = <_SeedShare>[
      if (content['adam'] != null)
        _SeedShare(yusuf, content['adam']!, 'Needed this reminder today.',
            now.subtract(const Duration(days: 2))),
      if (content['an_noor'] != null)
        _SeedShare(layla, content['an_noor']!, 'SubhanAllah — read it twice.',
            now.subtract(const Duration(hours: 30))),
      if (content['abu_bakr'] != null)
        _SeedShare(omar, content['abu_bakr']!, 'For our morning reflection.',
            now.subtract(const Duration(hours: 6))),
      if (content['first_revelation'] != null)
        _SeedShare(meMember, content['first_revelation']!, null,
            now.subtract(const Duration(hours: 3))),
    ];

    await db.transaction((txn) async {
      await txn.insert('halaqas', halaqa.toMap());
      // Creator first, then the others.
      await txn.insert('halaqa_members', meMember.toMap());
      for (final m in [yusuf, layla, omar, zayd]) {
        await txn.insert('halaqa_members', m.toMap());
      }

      // Shares + a spread of reactions. Reactors are a mix of members; the
      // author never reacts to their own share.
      final reactors = [meMember, yusuf, layla, omar, zayd];
      for (var i = 0; i < shares.length; i++) {
        final s = shares[i];
        final shareId = IdGenerator.uuid();
        await txn.insert(
          'halaqa_shares',
          HalaqaShare(
            id: shareId,
            halaqaId: halaqa.id,
            sharedBy: s.author.userId,
            sharedByName: s.author.displayName,
            content: s.content,
            personalNote: s.note,
            sharedAt: s.at,
          ).toMap(),
        );
        // Deterministic but varied reactions per share.
        final picks = _reactionPicks(i, reactors, s.author.userId);
        for (final p in picks) {
          await txn.insert(
            'halaqa_reactions',
            HalaqaReaction(
              id: IdGenerator.uuid(),
              shareId: shareId,
              userId: p.$1,
              reaction: p.$2,
              createdAt: s.at.add(const Duration(minutes: 20)),
            ).toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    });

    AppLogger.info('Seeded "Dawn Circle" with ${shares.length} shares',
        tag: _tag);
  }

  // ── Al-Minbar: a small public feed ───────────────────────────────
  static Future<void> _seedMinbar(
    UserProfile me,
    Map<String, SharedContent> content,
  ) async {
    final repo = LocalMinbarRepository();
    if (await repo.feedCount() > 0) return; // feed already has posts

    final db = await DatabaseService.instance.database;
    final now = DateTime.now();

    // Public posts can come from anyone; these are demo authors + you.
    final posts = <_SeedPost>[
      if (content['ibrahim'] != null)
        _SeedPost('u_maryam', 'Maryam', content['ibrahim']!,
            now.subtract(const Duration(days: 3))),
      if (content['ar_rahman'] != null)
        _SeedPost('u_idris', 'Idris', content['ar_rahman']!,
            now.subtract(const Duration(days: 2))),
      if (content['hijra'] != null)
        _SeedPost('u_khalid', 'Khalid', content['hijra']!,
            now.subtract(const Duration(days: 1))),
      if (content['bilal'] != null)
        _SeedPost(me.id, me.displayName, content['bilal']!,
            now.subtract(const Duration(hours: 8))),
      if (content['adam'] != null)
        _SeedPost('u_sara', 'Sara', content['adam']!,
            now.subtract(const Duration(hours: 2))),
    ];

    final reactorIds = [
      me.id,
      'u_maryam',
      'u_idris',
      'u_khalid',
      'u_sara',
      'u_hana',
    ];

    await db.transaction((txn) async {
      for (var i = 0; i < posts.length; i++) {
        final p = posts[i];
        final shareId = IdGenerator.uuid();
        await txn.insert(
          'minbar_shares',
          MinbarShare(
            id: shareId,
            sharedBy: p.userId,
            sharedByName: p.name,
            content: p.content,
            sharedAt: p.at,
          ).toMap(),
        );
        final picks = _reactionPicks(i, reactorIds, p.userId);
        for (final pick in picks) {
          await txn.insert(
            'minbar_reactions',
            MinbarReaction(
              id: IdGenerator.uuid(),
              shareId: shareId,
              userId: pick.$1,
              reaction: pick.$2,
              createdAt: p.at.add(const Duration(minutes: 15)),
            ).toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    });

    AppLogger.info('Seeded Al-Minbar with ${posts.length} posts', tag: _tag);
  }

  // ── helpers ──────────────────────────────────────────────────────
  static HalaqaMember _member(String halaqaId, String name, DateTime active) {
    return HalaqaMember(
      id: IdGenerator.uuid(),
      halaqaId: halaqaId,
      userId: 'u_${name.toLowerCase()}',
      displayName: name,
      joinedAt: active.subtract(const Duration(days: 1)),
      lastActiveAt: active,
    );
  }

  /// Build a varied, deterministic set of (userId, reaction) picks for share
  /// index [i], drawing from [reactorIds] but skipping the [authorId] (you
  /// don't react to your own share).
  static List<(String, ReactionType)> _reactionPicks(
    int i,
    List<dynamic> reactors,
    String authorId,
  ) {
    final ids = reactors
        .map((r) => r is HalaqaMember ? r.userId : r as String)
        .where((id) => id != authorId)
        .toList();
    if (ids.isEmpty) return const [];

    final types = ReactionTypeX.ordered;
    final picks = <(String, ReactionType)>[];
    // 2–3 reactors per share, rotating which reaction each leaves.
    final count = 2 + (i % 2); // 2 or 3
    for (var k = 0; k < count && k < ids.length; k++) {
      final id = ids[(i + k) % ids.length];
      final type = types[(i + k) % types.length];
      picks.add((id, type));
    }
    return picks;
  }
}

class _SeedShare {
  _SeedShare(this.author, this.content, this.note, this.at);
  final HalaqaMember author;
  final SharedContent content;
  final String? note;
  final DateTime at;
}

class _SeedPost {
  _SeedPost(this.userId, this.name, this.content, this.at);
  final String userId;
  final String name;
  final SharedContent content;
  final DateTime at;
}
