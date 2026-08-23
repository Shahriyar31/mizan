// sahabi_detail_screen.dart — Layer tabs at bottom
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mizan/core/theme/app_colors.dart';
import 'package:mizan/core/theme/app_typography.dart';
import 'package:mizan/core/knowledge/entity_ref.dart';
import 'package:mizan/shared/widgets/layer_story_scaffold.dart';
import 'package:mizan/features/sharing/share_target_sheet.dart';
import 'package:mizan/features/discover/data/discover_share_mapper.dart';
import '../models/discover_models.dart';
import '../providers/discover_providers.dart';
import 'quiz_screen.dart';

class SahabiDetailScreen extends ConsumerStatefulWidget {
  final String sahabiId;
  const SahabiDetailScreen({super.key, required this.sahabiId});

  @override
  ConsumerState<SahabiDetailScreen> createState() => _SahabiDetailScreenState();
}

class _SahabiDetailScreenState extends ConsumerState<SahabiDetailScreen> {
  SahabiEntry? _entry;
  DiscoverProgress? _progress;
  bool _loading = true;

  static const _layerTitles = [
    'Who',
    'The Conversion',
    'With the Prophet ﷺ',
    'Their Legacy',
    'Reflection',
  ];

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  /// Entry and saved progress both resolved before the reader is built — see
  /// [LayerStoryScaffold.progress] for why the row cannot arrive late.
  Future<void> _loadEntry() async {
    final entries = await ref.read(sahabahProvider.future);

    SahabiEntry? found;
    for (final s in entries) {
      if (s.id == widget.sahabiId) {
        found = s;
        break;
      }
    }

    final progress = found == null ? null : await _startProgress();
    if (!mounted) return;
    setState(() {
      _entry = found;
      _progress = progress;
      _loading = false;
    });
  }

  /// A story is never held shut by its own bookkeeping: if progress cannot be
  /// read or written, it opens ungated.
  Future<DiscoverProgress?> _startProgress() async {
    try {
      return await ref
          .read(sahabiProgressProvider.notifier)
          .start(widget.sahabiId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
          backgroundColor: AppColors.night,
          body: Center(
              child: CircularProgressIndicator(
                  color: AppColors.gold, strokeWidth: 2)));
    }
    if (_entry == null) {
      return Scaffold(
          backgroundColor: AppColors.night,
          body: Center(
              child: Text('Not found',
                  style: AppTypography.bodyMedium(color: AppColors.muted))));
    }

    final entry = _entry!;

    return LayerStoryScaffold(
      // Appends the connected sections to the final layer. Nothing above it
      // moves.
      entityRef: EntityRef(EntityType.sahabi, widget.sahabiId),
      layers: entry.layers,
      navLabels: _layerTitles,
      // Turns the completion gate on: one layer at a time, resuming where this
      // reader left off.
      progress: _progress,
      headerTitle: entry.nameArabic,
      headerSubtitle: '${entry.nameEnglish} — ${entry.era}',
      onShare: () => showShareTargetSheet(context, entry.toSharedContent()),
      onBeginQuiz: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => QuizScreen(
                    entryId: entry.id,
                    entryType: EntryType.sahabi,
                    entryName: entry.nameEnglish,
                    questions: entry.quiz,
                  ))),
    );
  }
}
