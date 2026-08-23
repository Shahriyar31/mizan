// prophet_detail_screen.dart — Layer tabs at bottom, content centred
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

class ProphetDetailScreen extends ConsumerStatefulWidget {
  final String prophetId;
  const ProphetDetailScreen({super.key, required this.prophetId});

  @override
  ConsumerState<ProphetDetailScreen> createState() =>
      _ProphetDetailScreenState();
}

class _ProphetDetailScreenState extends ConsumerState<ProphetDetailScreen> {
  ProphetEntry? _entry;
  DiscoverProgress? _progress;
  bool _loading = true;

  static const _layerTitles = [
    'Who',
    'The Call',
    'The Trial',
    'The Miracle',
    'Reflection'
  ];

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  /// Loads the entry and its saved progress before the reader is built.
  ///
  /// Both are resolved here rather than watched inside [LayerStoryScaffold],
  /// because the layer it opens on is fixed when its state is created: a progress
  /// row arriving a frame later would put a reader who reached layer 4 back on
  /// layer 1 with no indication why.
  Future<void> _loadEntry() async {
    final entries = await ref.read(prophetsProvider.future);

    ProphetEntry? found;
    for (final p in entries) {
      if (p.id == widget.prophetId) {
        found = p;
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

  /// Progress is bookkeeping, not content: if the row cannot be read or written
  /// the story still opens — ungated — rather than being held shut by its own
  /// records.
  Future<DiscoverProgress?> _startProgress() async {
    try {
      return await ref
          .read(prophetProgressProvider.notifier)
          .start(widget.prophetId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return  Scaffold(
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
      entityRef: EntityRef(EntityType.prophet, widget.prophetId),
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
                    entryType: EntryType.prophet,
                    entryName: entry.nameEnglish,
                    questions: entry.quiz,
                  ))),
    );
  }
}
