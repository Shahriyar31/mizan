/// YOUR DATA — copy out everything this device holds, and put it back.
///
/// ── Why the screen exists ──────────────────────────────────────────────
/// Reflections, the nightly muhasabah, saved words, unlocked layers, the streak
/// and the Al-Mizan record are on the phone and nowhere else. Signing in does not
/// back them up — the account carries Halaqa and Al-Minbar, not any of this. So a
/// new phone, a factory reset, or an uninstall takes the lot, and there is no
/// support ticket that can bring it back. This is the only door out.
///
/// ── Why copy and paste rather than a file ──────────────────────────────
/// Handing over a file needs `share_plus` or `file_picker`, neither of which is
/// in `pubspec.lock`. Writing into the app's own external directory would be
/// worse than nothing: Android 11+ hides `Android/data/` from the Files app and
/// deletes it on uninstall, which is the exact event a backup exists to survive.
/// The clipboard is already what this app means by "take this with you" — the
/// Halaqa invite and the developer link both copy and say so — so this is one
/// gesture the reader has already learned, and it needs no permission, no network
/// and no new plugin. See [BackupService] for the full reasoning.
///
/// ── Two buttons, and the second one asks first ─────────────────────────
/// Export is one tap: it cannot lose anything. Restore reads the clipboard, says
/// what it found and when it was made, and waits for a yes — because the text
/// came from outside the app and could be anything, and because a merge cannot be
/// undone from in here. It still cannot delete: [BackupService.restore] only ever
/// adds rows or advances values, which is what makes restoring an old backup onto
/// a phone you have kept using a safe thing to do.
///
/// ── Chrome ─────────────────────────────────────────────────────────────
/// This screen carries its own palette-driven header instead of the shared
/// `SettingsSubScaffold`, which hardcodes `AppColors.night` and so is dark in
/// both themes. Every other Settings sub-screen still uses it and is therefore
/// dark-only; this is the pattern they should move to.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/mizan_tokens.dart';
import '../../../core/theme/mizan_typography.dart';
import '../../../shared/state/local_data_refresh.dart';
import '../../../shared/widgets/mizan/mizan_components.dart';
import '../data/backup_service.dart';

class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  static const _service = BackupService();

  /// Built once when the screen opens, and again after a restore.
  ///
  /// The counts shown and the text copied come from the same object on purpose.
  /// Reading counts separately would mean two code paths that can disagree, and
  /// the disagreement would surface as a backup that says 40 words and contains
  /// 39 — the kind of doubt that makes a backup useless even when it is correct.
  Future<BackupSummary>? _summary;

  bool _busy = false;
  RestoreReport? _lastRestore;

  @override
  void initState() {
    super.initState();
    _summary = _service.export();
  }

  // ── EXPORT ──────────────────────────────────────────────────────────

  Future<void> _copy(BackupSummary summary) async {
    await Clipboard.setData(ClipboardData(text: summary.json));
    if (!mounted) return;
    _say('Copied — ${summary.totalRecords} records, ${_size(summary.bytes)}. '
        'Paste it somewhere you keep things.');
  }

  // ── RESTORE ─────────────────────────────────────────────────────────

  Future<void> _restoreFromClipboard() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = clip?.text ?? '';

      final preview = _service.inspect(raw);
      if (!preview.ok) {
        if (!mounted) return;
        _say(preview.error!);
        return;
      }

      if (!mounted) return;
      final confirmed = await _confirmRestore(preview);
      if (confirmed != true) return;

      final report = await _service.restore(raw);
      if (!mounted) return;

      if (report.changedAnything) refreshLocalDataProviders(ref);

      setState(() {
        _lastRestore = report;
        // The counts on this screen are now wrong, so they are rebuilt rather
        // than left showing the pre-restore figures next to a report saying 200
        // records came back.
        _summary = _service.export();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmRestore(BackupPreview preview) {
    final p = MizanPalette.of(context);
    final made = preview.createdAt;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: MizanGeometry.cardBorderRadius,
          side:
              BorderSide(color: p.hairline, width: MizanGeometry.hairlineWidth),
        ),
        title: Text('Restore this backup?',
            style: MizanType.cardHeadline(color: p.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              made == null
                  ? '${preview.records} records found on your clipboard.'
                  : '${preview.records} records, saved ${_when(made)}.',
              style: MizanType.body(color: p.ink),
            ),
            const SizedBox(height: 10),
            Text(
              'This adds to what is already on this phone. Nothing is deleted, '
              'and anything newer here is kept.',
              style: MizanType.body(color: p.muted),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          MizanButton(
            label: 'Cancel',
            kind: MizanButtonKind.quiet,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          MizanButton(
            label: 'Restore',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
  }

  // ── CHROME ──────────────────────────────────────────────────────────

  void _say(String message) {
    final p = MizanPalette.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: p.ink,
        duration: const Duration(seconds: 5),
        content: Text(message, style: MizanType.body(color: p.page)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Header(title: 'Your data'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  MizanGeometry.gutter,
                  4,
                  MizanGeometry.gutter,
                  MizanGeometry.scrollBottomPadding,
                ),
                children: [
                  const _Explainer(),
                  const SizedBox(height: 22),
                  const MizanSectionLabel('On this device'),
                  const SizedBox(height: 10),
                  FutureBuilder<BackupSummary>(
                    future: _summary,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return const _Note(
                          'Your data could not be read just now. Close this '
                          'screen and open it again.',
                          tone: _NoteTone.warning,
                        );
                      }
                      if (!snap.hasData) return const _CountsPlaceholder();
                      return _ExportCard(
                        summary: snap.data!,
                        onCopy: () => _copy(snap.data!),
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  const MizanSectionLabel('Bring it back'),
                  const SizedBox(height: 10),
                  _RestoreCard(
                    busy: _busy,
                    report: _lastRestore,
                    onRestore: _restoreFromClipboard,
                  ),
                  const SizedBox(height: 22),
                  const _Coverage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  HEADER
// ══════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(MizanGeometry.gutter, 6, 12, 10),
      child: Row(
        children: [
          MizanIconTile(
            icon: Icons.arrow_back_ios_new_rounded,
            iconSize: 17,
            semanticLabel: 'Back',
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: MizanType.screenTitle(color: p.ink).copyWith(fontSize: 21),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  WHY
// ══════════════════════════════════════════════════════════════════════

class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanSurface(
      tone: MizanTone.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Everything you write stays on this phone',
              style: MizanType.cardHeadline(color: p.ink)),
          const SizedBox(height: 8),
          Text(
            'Your reflections, your muhasabah and your saved words are never '
            'uploaded. That is the point — and it means an account does not '
            'back them up either. If this phone is lost or reset, they go with '
            'it unless you keep a copy.',
            style: MizanType.body(color: p.muted),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  EXPORT
// ══════════════════════════════════════════════════════════════════════

class _ExportCard extends StatelessWidget {
  const _ExportCard({required this.summary, required this.onCopy});

  final BackupSummary summary;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final rows = summary.counts.entries.where((e) => e.value > 0).toList();

    return MizanSurface(
      tone: MizanTone.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rows.isEmpty)
            Text(
              'Nothing to copy yet. Once you save a word or write a reflection, '
              'it will show up here.',
              style: MizanType.body(color: p.muted),
            )
          else ...[
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(rows[i].key,
                        style: MizanType.body(color: p.muted)),
                  ),
                  Text('${rows[i].value}',
                      style: MizanType.bodyStrong(color: p.ink)),
                ],
              ),
            ],
            const SizedBox(height: 14),
            MizanRule(color: p.hairline),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text('Backup size',
                      style: MizanType.body(color: p.muted)),
                ),
                Text(_size(summary.bytes),
                    style: MizanType.bodyStrong(color: p.ink)),
              ],
            ),
            const SizedBox(height: 16),
            MizanButton(
              label: 'Copy my backup',
              icon: Icons.content_copy_rounded,
              expand: true,
              onPressed: onCopy,
            ),
            const SizedBox(height: 10),
            // Said plainly rather than buried. The backup is readable text, so
            // wherever it is pasted can read the muhasabah in it — and a reader
            // who does not know that cannot make the choice properly.
            Text(
              'The copy is plain readable text, so keep it somewhere private. '
              'A note to yourself, or an email to your own address.',
              style: MizanType.body(color: p.muted).copyWith(fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountsPlaceholder extends StatelessWidget {
  const _CountsPlaceholder();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    return MizanSurface(
      tone: MizanTone.card,
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: p.accentText),
          ),
          const SizedBox(width: 12),
          Text('Counting what you have saved…',
              style: MizanType.body(color: p.muted)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  RESTORE
// ══════════════════════════════════════════════════════════════════════

class _RestoreCard extends StatelessWidget {
  const _RestoreCard({
    required this.busy,
    required this.report,
    required this.onRestore,
  });

  final bool busy;
  final RestoreReport? report;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanSurface(
      tone: MizanTone.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Copy a backup to your clipboard, then press this. Mizan will read '
            'it, tell you what is in it, and ask before it writes anything.',
            style: MizanType.body(color: p.muted),
          ),
          const SizedBox(height: 14),
          MizanButton(
            label: busy ? 'Restoring…' : 'Restore from clipboard',
            icon: Icons.content_paste_rounded,
            kind: MizanButtonKind.secondary,
            expand: true,
            onPressed: busy ? null : onRestore,
          ),
          if (report != null) ...[
            const SizedBox(height: 14),
            _ReportBody(report: report!),
          ],
        ],
      ),
    );
  }
}

/// The outcome, in the reader's terms. Every number here answers a question they
/// would otherwise have to answer by going and looking.
class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final RestoreReport report;

  @override
  Widget build(BuildContext context) {
    if (report.failed) {
      return _Note(report.error!, tone: _NoteTone.warning);
    }

    if (!report.changedAnything) {
      return const _Note(
        'Everything in that backup was already on this phone. Nothing changed.',
      );
    }

    final parts = <String>[
      if (report.added > 0) '${report.added} brought back',
      if (report.updated > 0) '${report.updated} updated',
      if (report.unchanged > 0) '${report.unchanged} already here',
      if (report.prefsWritten > 0) '${report.prefsWritten} settings restored',
    ];

    return _Note('Done — ${parts.join(', ')}.', tone: _NoteTone.good);
  }
}

// ══════════════════════════════════════════════════════════════════════
//  WHAT TRAVELS
// ══════════════════════════════════════════════════════════════════════

class _Coverage extends StatelessWidget {
  const _Coverage();

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return MizanSurface(
      tone: MizanTone.sunk,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What a backup leaves out',
              style: MizanType.bodyStrong(color: p.ink)),
          const SizedBox(height: 8),
          Text(
            'Downloaded tafsir, hadith and audio are not in it — they come back '
            'on their own. Your Halaqa circles and anything you shared to '
            'Al-Minbar live with your account, so signing in brings those back. '
            'Theme, reciter and translation are settings for this phone, not a '
            'record of you, so they stay behind.',
            style: MizanType.body(color: p.muted),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SMALL PIECES
// ══════════════════════════════════════════════════════════════════════

enum _NoteTone { plain, good, warning }

class _Note extends StatelessWidget {
  const _Note(this.text, {this.tone = _NoteTone.plain});

  final String text;
  final _NoteTone tone;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    // Gold is trim, never ink, so the state is carried by a leading rule and the
    // glyph rather than by coloured body text.
    final (IconData icon, Color colour) = switch (tone) {
      _NoteTone.good => (Icons.check_rounded, p.sage),
      _NoteTone.warning => (Icons.error_outline_rounded, p.accentText),
      _NoteTone.plain => (Icons.info_outline_rounded, p.muted),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 17, color: colour),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: MizanType.body(color: p.ink)),
        ),
      ],
    );
  }
}

/// Bytes, at the precision a person cares about. Below a kilobyte it says so in
/// bytes rather than rounding to "0 KB", which would read as an empty backup.
String _size(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "24 Aug 2026 at 21:40" — a whole date, because the reader may be choosing
/// between two backups and "yesterday" would not distinguish them.
String _when(DateTime d) {
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]} ${d.year} at $hh:$mm';
}
