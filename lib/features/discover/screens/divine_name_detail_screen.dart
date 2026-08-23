// divine_name_detail_screen.dart — same pattern as prophet/sahabi/seerah
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

class DivineNameDetailScreen extends ConsumerStatefulWidget {
  final String nameId;
  const DivineNameDetailScreen({super.key, required this.nameId});

  @override
  ConsumerState<DivineNameDetailScreen> createState() =>
      _DivineNameDetailScreenState();
}

class _DivineNameDetailScreenState
    extends ConsumerState<DivineNameDetailScreen> {
  DivineName? _entry;
  bool _loading = true;

  static const _layerTitles = [
    'The Root',
    'The Meaning',
    'In the Quran',
    'The Scholar',
    'Your Reflection'
  ];

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  Future<void> _loadEntry() async {
    final entries = await ref.read(namesProvider.future);
    try {
      final entry = entries.firstWhere((n) => n.id == widget.nameId);
      if (mounted) {
        setState(() {
          _entry = entry;
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
      return  Scaffold(
        backgroundColor: AppColors.night,
        body: Center(
            child: CircularProgressIndicator(
                color: AppColors.gold, strokeWidth: 2)),
      );
    }
    if (_entry == null) {
      return Scaffold(
        backgroundColor: AppColors.night,
        body: Center(
            child: Text('Name not found',
                style: AppTypography.bodyMedium(color: AppColors.muted))),
      );
    }

    final entry = _entry!;

    return LayerStoryScaffold(
      // Appends the connected sections to the final layer. Nothing above it
      // moves.
      entityRef: EntityRef(EntityType.divineName, widget.nameId),
      layers: entry.layers,
      navLabels: _layerTitles,
      headerTitle: entry.arabic,
      headerSubtitle: '${entry.translit} — ${entry.meaningBrief}',
      headerTrailing: '#${entry.number}',
      onShare: () => showShareTargetSheet(context, entry.toSharedContent()),
      onBeginQuiz: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => QuizScreen(
                    entryId: entry.id,
                    entryType: EntryType.divineName,
                    entryName: entry.translit,
                    questions: entry.quiz,
                  ))),
    );
  }
}
