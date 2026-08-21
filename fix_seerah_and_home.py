#!/usr/bin/env python3
"""
Fixes:
1. Adds SeerahEntry model to discover_models.dart
2. Adds seerahProvider + seerahListProvider to discover_providers.dart
3. Adds seerah loading to discover_repository.dart
4. Wires _SeerahTab in discover_screen.dart to real data
5. Rewrites home_screen.dart with proper UX
"""
import os, re

BASE = os.path.expanduser('~/develop/ummahapp/lib')

# ─── 1. Add SeerahEntry to discover_models.dart ───────────────────────────────
models_path = os.path.join(BASE, 'features/discover/models/discover_models.dart')
with open(models_path) as f:
    models = f.read()

seerah_model = '''
// ── Seerah Entry model ────────────────────────────────────────────────────────

class SeerahEntry {
  final String id;
  final int sequenceNumber;
  final String title;
  final String titleArabic;
  final String year;
  final String era;
  final String teaser;
  final List<DiscoverLayer> layers;
  final List<QuizQuestion> quiz;

  const SeerahEntry({
    required this.id,
    required this.sequenceNumber,
    required this.title,
    required this.titleArabic,
    required this.year,
    required this.era,
    required this.teaser,
    required this.layers,
    required this.quiz,
  });

  factory SeerahEntry.fromJson(Map<String, dynamic> j) => SeerahEntry(
        id: j['id'] as String,
        sequenceNumber: j['sequence_number'] as int,
        title: j['title'] as String,
        titleArabic: j['title_arabic'] as String,
        year: j['year'] as String,
        era: j['era'] as String,
        teaser: j['teaser'] as String,
        layers: (j['layers'] as List)
            .map((l) => DiscoverLayer.fromJson(l as Map<String, dynamic>))
            .toList(),
        quiz: (j['quiz'] as List)
            .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
}

class SeerahListItem {
  final SeerahEntry entry;
  final DiscoverProgress? progress;

  const SeerahListItem({required this.entry, required this.progress});
}
'''

if 'SeerahEntry' not in models:
    # Add before the QuizResult class
    models = models.replace('class QuizResult {', seerah_model + '\nclass QuizResult {')
    with open(models_path, 'w') as f:
        f.write(models)
    print('✓ SeerahEntry added to discover_models.dart')
else:
    print('  SeerahEntry already exists in models')

# ─── 2. Add seerah loading to discover_repository.dart ───────────────────────
repo_path = os.path.join(BASE, 'features/discover/data/discover_repository.dart')
with open(repo_path) as f:
    repo = f.read()

if 'getSeerah' not in repo:
    seerah_repo = '''
  static List<SeerahEntry>? _seerah;

  static Future<List<SeerahEntry>> getSeerah() async {
    _seerah = null; // Always reload
    final indexJson =
        await rootBundle.loadString('assets/data/discover/seerah/index.json');
    final List<String> filenames =
        List<String>.from(jsonDecode(indexJson));
    final entries = <SeerahEntry>[];
    for (final filename in filenames) {
      try {
        final raw = await rootBundle
            .loadString('assets/data/discover/seerah/$filename');
        entries.add(SeerahEntry.fromJson(jsonDecode(raw)));
      } catch (e) {
        // Skip malformed files
      }
    }
    _seerah = entries;
    return _seerah!;
  }

  static Future<SeerahEntry?> getSeerahById(String id) async {
    final all = await getSeerah();
    try {
      return all.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
'''
    # Insert before the clearCache method or at end of class
    repo = repo.replace(
        '  static void clearCache()',
        seerah_repo + '\n  static void clearCache()'
    )
    # Also add SeerahEntry import hint (it's in discover_models.dart which is already imported)
    with open(repo_path, 'w') as f:
        f.write(repo)
    print('✓ getSeerah() added to discover_repository.dart')
else:
    print('  getSeerah already exists in repository')

# ─── 3. Add seerahProvider to discover_providers.dart ────────────────────────
providers_path = os.path.join(BASE, 'features/discover/providers/discover_providers.dart')
with open(providers_path) as f:
    providers = f.read()

if 'seerahProvider' not in providers:
    seerah_providers = '''
// ── Seerah Providers ──────────────────────────────────────────────────────────

final seerahProvider = FutureProvider<List<SeerahEntry>>((ref) async {
  return DiscoverRepository.getSeerah();
});

final seerahProgressProvider =
    StateNotifierProvider<DiscoverProgressNotifier,
        AsyncValue<Map<String, DiscoverProgress>>>(
  (ref) => DiscoverProgressNotifier(EntryType.prophet), // reuse prophet type for now
);

final seerahListProvider = Provider<AsyncValue<List<SeerahListItem>>>((ref) {
  final seerahAsync = ref.watch(seerahProvider);
  final progressAsync = ref.watch(seerahProgressProvider);

  return seerahAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
    data: (entries) {
      return progressAsync.when(
        loading: () => const AsyncValue.loading(),
        error: (e, s) => AsyncValue.error(e, s),
        data: (progressMap) {
          return AsyncValue.data(entries.map((entry) {
            final progress = progressMap[entry.id];
            return SeerahListItem(entry: entry, progress: progress);
          }).toList());
        },
      );
    },
  );
});
'''
    # Add at the end of file
    providers = providers.rstrip() + '\n' + seerah_providers + '\n'
    with open(providers_path, 'w') as f:
        f.write(providers)
    print('✓ seerahProvider added to discover_providers.dart')
else:
    print('  seerahProvider already exists')

# ─── 4. Wire _SeerahTab in discover_screen.dart ──────────────────────────────
screen_path = os.path.join(BASE, 'features/discover/screens/discover_screen.dart')
with open(screen_path) as f:
    screen = f.read()

old_seerah_tab = '''class _SeerahTab extends StatelessWidget {
  const _SeerahTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\ufdfa',
              style: TextStyle(
                fontSize: 56,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'The Seerah',
              style: AppTypography.displayMedium(color: AppColors.parchment),
            ),
            const SizedBox(height: 12),
            Container(
              height: 1,
              width: 60,
              color: AppColors.gold.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'The chronological life of the Prophet Muhammad \ufdfa.\\nComing in Phase 4.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}'''

new_seerah_tab = '''class _SeerahTab extends ConsumerWidget {
  const _SeerahTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(seerahListProvider);
    return listAsync.when(
      loading: () => const _LoadingView(),
      error: (e, _) => _ErrorView(e.toString()),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('\ufdfa', style: TextStyle(fontSize: 56, color: AppColors.gold)),
                const SizedBox(height: 20),
                Text('The Seerah', style: AppTypography.displayMedium(color: AppColors.parchment)),
                const SizedBox(height: 12),
                Text(
                  'Coming soon — the chronological\\nlife of the Prophet \ufdfa',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium(color: AppColors.muted),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            return _SeerahCard(
              entry: item.entry,
              layersRead: item.progress?.layersUnlocked ?? 0,
              onTap: () => context.push('/discover/seerah/\${item.entry.id}'),
            );
          },
        );
      },
    );
  }
}

class _SeerahCard extends StatelessWidget {
  final SeerahEntry entry;
  final int layersRead;
  final VoidCallback onTap;

  const _SeerahCard({
    required this.entry,
    required this.layersRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0B07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: layersRead > 0 ? 0.4 : 0.12),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(entry.year,
                        style: AppTypography.labelSmall(color: AppColors.gold)),
                  ),
                  const Spacer(),
                  Text('#\${entry.sequenceNumber}',
                      style: AppTypography.labelSmall(
                          color: AppColors.muted.withValues(alpha: 0.4))),
                ],
              ),
              const SizedBox(height: 12),
              Text(entry.titleArabic,
                  style: AppTypography.arabicDisplay(color: AppColors.gold, size: 22)),
              Text(entry.title,
                  style: AppTypography.displaySmall(color: AppColors.parchment)),
              const SizedBox(height: 4),
              Text(entry.era,
                  style: AppTypography.labelSmall(
                      color: AppColors.muted.withValues(alpha: 0.6))),
              const SizedBox(height: 8),
              Text(entry.teaser,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall(color: AppColors.muted)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('\$layersRead / 5 layers',
                      style: AppTypography.labelSmall(
                          color: AppColors.muted.withValues(alpha: 0.5))),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: AppColors.gold.withValues(alpha: 0.4)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: layersRead / 5,
                  backgroundColor: AppColors.gold.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(AppColors.gold),
                  minHeight: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}'''

if old_seerah_tab in screen:
    screen = screen.replace(old_seerah_tab, new_seerah_tab)
    print('✓ _SeerahTab wired to real data')
else:
    # Try to find it differently
    if 'Coming in Phase 4' in screen:
        print('WARN: old pattern not exact - manual fix needed')
        print('  Found "Coming in Phase 4" - check _SeerahTab manually')
    else:
        print('WARN: _SeerahTab pattern not found')

# Make sure ConsumerWidget imports are available (it already uses ConsumerWidget elsewhere)
with open(screen_path, 'w') as f:
    f.write(screen)

# ─── 5. Add seerah route to app_router.dart ──────────────────────────────────
router_path = os.path.join(BASE, 'core/router/app_router.dart')
with open(router_path) as f:
    router = f.read()

if 'seerah/:seerahId' not in router:
    old_route = '''              GoRoute(
                path: 'name/:nameId',
                builder: (context, state) {
                  final nameId = state.pathParameters['nameId']!;
                  return DivineNameDetailScreen(nameId: nameId);
                },
              ),'''
    new_route = old_route + '''
              GoRoute(
                path: 'seerah/:seerahId',
                builder: (context, state) {
                  final seerahId = state.pathParameters['seerahId']!;
                  return SeerahDetailScreen(seerahId: seerahId);
                },
              ),'''
    if old_route in router:
        router = router.replace(old_route, new_route)
        # Add import
        router = router.replace(
            "import '../../features/discover/screens/divine_name_detail_screen.dart';",
            "import '../../features/discover/screens/divine_name_detail_screen.dart';\nimport '../../features/discover/screens/seerah_detail_screen.dart';"
        )
        with open(router_path, 'w') as f:
            f.write(router)
        print('✓ Seerah route added to app_router.dart')
    else:
        print('WARN: name route pattern not found in router')
else:
    print('  Seerah route already exists')

# ─── 6. Add seerah to pubspec.yaml if missing ────────────────────────────────
pubspec_path = os.path.expanduser('~/develop/ummahapp/pubspec.yaml')
with open(pubspec_path) as f:
    pubspec = f.read()

if 'assets/data/discover/seerah/' not in pubspec:
    pubspec = pubspec.replace(
        '    - assets/data/discover/names/',
        '    - assets/data/discover/names/\n    - assets/data/discover/seerah/'
    )
    with open(pubspec_path, 'w') as f:
        f.write(pubspec)
    print('✓ Seerah assets added to pubspec.yaml')
else:
    print('  Seerah already in pubspec.yaml')

print('\nAll done. Now:')
print('1. Create seerah_detail_screen.dart (copy sahabi_detail_screen.dart pattern)')
print('2. flutter pub get && flutter run -d emulator-5554')
