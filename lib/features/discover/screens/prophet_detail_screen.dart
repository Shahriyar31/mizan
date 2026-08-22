// prophet_detail_screen.dart — Layer tabs at bottom, content centred
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taddabur/core/theme/app_colors.dart';
import 'package:taddabur/core/theme/app_typography.dart';
import 'package:taddabur/shared/widgets/layer_story_scaffold.dart';
import 'package:taddabur/features/sharing/share_target_sheet.dart';
import 'package:taddabur/features/discover/data/discover_share_mapper.dart';
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

  Future<void> _loadEntry() async {
    final entries = await ref.read(prophetsProvider.future);
    try {
      final e = entries.firstWhere((p) => p.id == widget.prophetId);
      if (mounted)
        setState(() {
          _entry = e;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return  Scaffold(
          backgroundColor: AppColors.night,
          body: Center(
              child: CircularProgressIndicator(
                  color: AppColors.gold, strokeWidth: 2)));
    if (_entry == null)
      return Scaffold(
          backgroundColor: AppColors.night,
          body: Center(
              child: Text('Not found',
                  style: AppTypography.bodyMedium(color: AppColors.muted))));

    final entry = _entry!;

    return LayerStoryScaffold(
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
                    entryType: EntryType.prophet,
                    entryName: entry.nameEnglish,
                    questions: entry.quiz,
                  ))),
    );
  }
}
