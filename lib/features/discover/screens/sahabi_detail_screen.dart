// sahabi_detail_screen.dart — Layer tabs at bottom
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taddabur/core/theme/app_colors.dart';
import 'package:taddabur/core/theme/app_typography.dart';
import 'package:taddabur/core/knowledge/entity_ref.dart';
import 'package:taddabur/shared/widgets/layer_story_scaffold.dart';
import 'package:taddabur/features/sharing/share_target_sheet.dart';
import 'package:taddabur/features/discover/data/discover_share_mapper.dart';
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

  Future<void> _loadEntry() async {
    final entries = await ref.read(sahabahProvider.future);
    try {
      final e = entries.firstWhere((s) => s.id == widget.sahabiId);
      if (mounted) {
        setState(() {
          _entry = e;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
