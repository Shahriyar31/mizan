/// Create / Join bottom sheets for Halaqa.
///
/// Two small modal flows that return the resulting [Halaqa] (or null if the user
/// backed out), so the caller can navigate straight into the circle. All the
/// write logic lives in [MyHalaqasNotifier]; these sheets collect input, say
/// precisely what went wrong, and pop with the result.
///
/// ── Why this file was rewritten ────────────────────────────────────────
/// It was the last of the Halaqa screens still built on `AppColors` and
/// `AppTypography`, which are the old dark-only palette: on the light theme both
/// sheets slid up as dark navy panels with gold buttons under a cream app. They
/// are on Mizan tokens now, and the fields lean on the global
/// `inputDecorationTheme` (mizan_theme.dart) rather than restyling themselves,
/// so they follow the theme without a second copy of the rules.
///
/// Three behaviours also changed, each for a reason:
///
/// • **The invite field accepts a pasted code, or a whole pasted invite.** Codes
///   arrive with a trailing newline, broken up as `K7P2-QM` by whoever sent them,
///   or — most often now — wrapped in the entire message the copy button
///   produces. [HalaqaInviteCode.fromPasted] is applied as the user types, so all
///   of those land on the same six characters instead of missing a circle that
///   exists.
///
/// • **Its length cap was wrong.** It was 8, but the invite generator falls back
///   to a 10-character code on repeated collisions, so the one code that most
///   needed typing correctly was being silently truncated. It is 10 now — the
///   longest code that can exist.
///
/// • **"Already in this circle" opens the circle.** It is not a failure: the
///   person typed a code for a circle they belong to, and being inside it is
///   what they were asking for. Showing them an error and making them close the
///   sheet and find it in the list is the app being pedantic at their expense.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/readable_error.dart';
import '../../../../core/theme/mizan_tokens.dart';
import '../../../../core/theme/mizan_typography.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/mizan/mizan_components.dart';
import '../../../identity/domain/identity_providers.dart';
import '../../data/halaqa_repository.dart';
import '../../domain/halaqa_providers.dart';
import '../../models/halaqa_models.dart';

const String _tag = 'HalaqaSheets';

/// The shortest and longest invite code [IdGenerator.inviteCode] can produce
/// (6 normally, 8 after four collisions, 10 as the final fallback).
const int _codeMinLength = 6;
const int _codeMaxLength = 10;

Future<Halaqa?> showCreateHalaqaSheet(BuildContext context) {
  return showModalBottomSheet<Halaqa>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SheetShell(child: _CreateHalaqaForm()),
  );
}

Future<Halaqa?> showJoinHalaqaSheet(BuildContext context) {
  return showModalBottomSheet<Halaqa>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SheetShell(child: _JoinHalaqaForm()),
  );
}

/// Shared chrome: card-coloured panel, rounded top, grabber, keyboard-aware.
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Padding(
      // Lifts the whole sheet above the keyboard, which matters here because
      // both forms are a single field and a button.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: p.card,
          // 22 to match the circle screen's own sheet and the share sheet —
          // these panels are drawn by hand (the sheet background is
          // transparent), so they don't inherit `bottomSheetTheme`'s shape.
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(
            top: BorderSide(
              color: p.hairline,
              width: MizanGeometry.hairlineWidth,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          MizanGeometry.gutter,
          12,
          MizanGeometry.gutter,
          24,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: p.hairline,
                  borderRadius: BorderRadius.circular(MizanGeometry.pillRadius),
                ),
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  CREATE
// ══════════════════════════════════════════════════════════════════════

class _CreateHalaqaForm extends ConsumerStatefulWidget {
  const _CreateHalaqaForm();

  @override
  ConsumerState<_CreateHalaqaForm> createState() => _CreateHalaqaFormState();
}

class _CreateHalaqaFormState extends ConsumerState<_CreateHalaqaForm> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    // Clearing on edit: an error about the previous value reads as if it were
    // about the one being typed.
    setState(() {
      if (_error != null) _error = null;
    });
  }

  bool get _canSubmit => !_busy && _controller.text.trim().isNotEmpty;

  Future<void> _submit() async {
    // The keyboard's "done" key fires whether or not the button is enabled, so
    // the guard lives here rather than only in `onPressed`.
    if (!_canSubmit) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final halaqa =
          await ref.read(myHalaqasProvider.notifier).create(_controller.text);
      if (mounted) Navigator.of(context).pop(halaqa);
    } on HalaqaException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message ?? 'Could not create the circle.';
      });
    } catch (e) {
      // The real cause goes to the log — a Postgrest error carries the column
      // or constraint that refused, and swallowing it entirely is how a broken
      // create stayed invisible for as long as it did.
      //
      // The sentence shown is no longer hardcoded. It used to read "Check your
      // connection and try again", which was wrong for every server-side
      // refusal: a recursive RLS policy in the database produced exactly this
      // path, and the copy sent the person off to blame their wifi.
      // readableError() reads the Postgres code and says what is actually true.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = readableError(e, tag: _tag);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);
    final online = ref.watch(isOnlineIdentityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('New circle', style: _sheetTitle(p)),
        const SizedBox(height: 6),
        Text(
          'A Halaqa is small and private — up to '
          '${AppConstants.maxHalaqaMembers} people who share what they are '
          'reading and respond with a reaction, not a comment.',
          style: MizanType.body(color: p.muted),
        ),
        if (!online) ...[
          const SizedBox(height: 12),
          const _OfflineNote(
            'You are signed out, so this circle is stored on this phone only '
            'and its invite code will not work for anyone else. Sign in from '
            'Settings first if you mean to invite people.',
          ),
        ],
        const SizedBox(height: 18),
        TextField(
          controller: _controller,
          enabled: !_busy,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          style: MizanType.body(color: p.ink),
          decoration: const InputDecoration(
            hintText: 'e.g. Dawn Circle, Family',
            counterText: '',
          ),
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _SheetMessage(_error!),
        ],
        const SizedBox(height: 18),
        MizanButton(
          label: _busy ? 'Creating…' : 'Create circle',
          expand: true,
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  JOIN
// ══════════════════════════════════════════════════════════════════════

class _JoinHalaqaForm extends ConsumerStatefulWidget {
  const _JoinHalaqaForm();

  @override
  ConsumerState<_JoinHalaqaForm> createState() => _JoinHalaqaFormState();
}

class _JoinHalaqaFormState extends ConsumerState<_JoinHalaqaForm> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {
      if (_error != null) _error = null;
    });
  }

  String get _code => HalaqaInviteCode.canonical(_controller.text);

  bool get _canSubmit => !_busy && _code.length >= _codeMinLength;

  String _messageFor(HalaqaException e) => switch (e.kind) {
        // Signed out, "not found" almost always means the circle is real but
        // lives in somebody else's phone: an offline circle is a row in this
        // device's SQLite and nothing else. Saying only "check the code" would
        // send the user to re-read a code that is perfectly correct.
        HalaqaErrorKind.notFound => ref.read(isOnlineIdentityProvider)
            ? 'No circle has that code. Check it with whoever sent it.'
            : 'No circle on this phone has that code. Joining someone else\'s '
                'circle needs an account — you can sign in from Settings.',
        HalaqaErrorKind.full =>
          'That circle is full — ${AppConstants.maxHalaqaMembers} members is '
              'the limit.',
        // Handled before this is reached; kept so the switch stays exhaustive.
        HalaqaErrorKind.alreadyMember => "You're already in that circle.",
        HalaqaErrorKind.invalidName => 'That does not look like an invite code.',
      };

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final notifier = ref.read(myHalaqasProvider.notifier);

    try {
      final halaqa = await notifier.join(_code);
      if (mounted) Navigator.of(context).pop(halaqa);
    } on HalaqaException catch (e) {
      if (e.kind == HalaqaErrorKind.alreadyMember) {
        await _openExisting(notifier);
        return;
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _messageFor(e);
      });
    } catch (e) {
      // Same reasoning as the create path above: let readableError name the
      // real cause rather than blaming the network for a server refusal.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = readableError(e, tag: _tag);
      });
    }
  }

  /// Already a member: find the circle and go in, saying so quietly.
  ///
  /// The messenger is captured before the pop because after it this sheet's
  /// context is gone, and the snackbar has to appear over the circle the user
  /// just landed in.
  Future<void> _openExisting(MyHalaqasNotifier notifier) async {
    Halaqa? existing;
    try {
      existing = await notifier.lookUp(_code);
    } catch (e) {
      AppLogger.error('Look-up after alreadyMember failed: $e', tag: _tag);
    }
    if (!mounted) return;

    if (existing == null) {
      // Vanishingly unlikely — the join just told us we are in it — but the
      // sheet must not close on nothing.
      setState(() {
        _busy = false;
        _error = "You're already in that circle. Find it in your list.";
      });
      return;
    }

    final p = MizanPalette.of(context);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(existing);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: p.ink,
        content: Text(
          "You're already in ${existing.name} — opening it.",
          style: MizanType.body(color: p.page),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Join a circle', style: _sheetTitle(p)),
        const SizedBox(height: 6),
        Text(
          'Paste what was sent to you — the whole message is fine, and so are '
          'spaces, dashes and lower case.',
          style: MizanType.body(color: p.muted),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _controller,
          enabled: !_busy,
          autofocus: true,
          maxLength: _codeMaxLength,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [_InviteCodeFormatter()],
          textInputAction: TextInputAction.done,
          style: MizanType.bodyStrong(color: p.ink)
              .copyWith(letterSpacing: 3, fontSize: 17),
          decoration: const InputDecoration(
            hintText: 'INVITE CODE',
            counterText: '',
          ),
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _SheetMessage(_error!),
        ],
        const SizedBox(height: 18),
        MizanButton(
          label: _busy ? 'Joining…' : 'Join circle',
          expand: true,
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SHARED PIECES
// ══════════════════════════════════════════════════════════════════════

TextStyle _sheetTitle(MizanPalette p) =>
    MizanType.cardHeadline(color: p.ink).copyWith(fontSize: 21);

/// One line of trouble, in the same shape the account screen uses: sunk fill,
/// accent-weight edge. The Mizan palette defines no error colour, so a failure
/// borrows `accentText` (bronze on cream, gold on navy) rather than introducing
/// a red that belongs to neither theme.
class _SheetMessage extends StatelessWidget {
  const _SheetMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: p.sunk,
        borderRadius: MizanGeometry.cardBorderRadius,
        border: Border.all(color: p.accentText.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 19, color: p.accentText),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: MizanType.body(color: p.ink).copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet statement of fact, not a warning. Sage edge, because being signed out
/// is a perfectly valid way to use the app — it just cannot reach other phones.
class _OfflineNote extends StatelessWidget {
  const _OfflineNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = MizanPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.sunk,
        borderRadius: MizanGeometry.cardBorderRadius,
        border: Border.all(color: p.sage.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: p.sage),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: MizanType.body(color: p.muted).copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps the invite field to what an invite code can contain.
///
/// Uppercases, and drops everything outside `[A-Z0-9]` — so a code pasted as
/// `k7p2-qm ` becomes `K7P2QM` in the field itself, and what the user sees is
/// exactly what will be looked up. The whole value is re-canonicalised on every
/// edit rather than only the inserted text, because a paste can land in the
/// middle of what is already there.
///
/// It also accepts a whole pasted invite message and keeps only the code, via
/// [HalaqaInviteCode.fromPasted]. That is the likely paste, not the unlikely
/// one: the copy button in a circle puts the entire message on the clipboard, so
/// the friend receiving it in WhatsApp has a paragraph to hand, and selecting
/// just six characters out of it is the fiddlier option. Without this the field
/// would fill with `JOINMYCIRC` — the message glued together and cut off at
/// [_codeMaxLength] — and a valid code would be reported as not found.
class _InviteCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = HalaqaInviteCode.fromPasted(newValue.text);
    if (text == newValue.text) return newValue;
    // Characters may have been removed, so the caret is clamped to the new
    // length instead of being left past the end.
    final removed = newValue.text.length - text.length;
    final offset = newValue.selection.baseOffset - removed;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: offset.clamp(0, text.length),
      ),
    );
  }
}
