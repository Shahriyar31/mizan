/// Create / Join bottom sheets for Halaqa.
///
/// Two small modal flows that return the resulting [Halaqa] (or null if the
/// user backed out), so the caller can navigate straight into the new circle.
/// All the write logic lives in [MyHalaqasNotifier]; these sheets just collect
/// input, show a precise error when a join fails, and pop with the result.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/halaqa_repository.dart';
import '../../domain/halaqa_providers.dart';
import '../../models/halaqa_models.dart';

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

/// Shared chrome: rounded top, grabber, keyboard-aware padding.
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration:  BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Create ──────────────────────────────────────────────────────────
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please give your circle a name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final halaqa = await ref.read(myHalaqasProvider.notifier).create(name);
      if (mounted) Navigator.of(context).pop(halaqa);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not create the circle. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('New circle',
            style: AppTypography.displaySmall(color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(
          'A Halaqa is a small, private circle — up to '
          '${AppConstants.maxHalaqaMembers} people who share and reflect together.',
          style: AppTypography.bodySmall(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        _SheetTextField(
          controller: _controller,
          hint: 'e.g. Dawn Circle, Family, Halaqa 1',
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: AppTypography.bodySmall(color: AppColors.error)),
        ],
        const SizedBox(height: 18),
        _PrimaryButton(
          label: 'Create circle',
          busy: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}

// ── Join ────────────────────────────────────────────────────────────
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _messageFor(HalaqaException e) => switch (e.kind) {
        HalaqaErrorKind.notFound =>
          'No circle found with that code. Double-check it and try again.',
        HalaqaErrorKind.full =>
          'That circle is full (max ${AppConstants.maxHalaqaMembers} members).',
        HalaqaErrorKind.alreadyMember => 'You\'re already in that circle.',
        HalaqaErrorKind.invalidName => 'Please enter a valid invite code.',
      };

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the invite code a friend shared.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final halaqa = await ref.read(myHalaqasProvider.notifier).join(code);
      if (mounted) Navigator.of(context).pop(halaqa);
    } on HalaqaException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _messageFor(e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not join the circle. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Join a circle',
            style: AppTypography.displaySmall(color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(
          'Enter the invite code a friend shared with you.',
          style: AppTypography.bodySmall(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        _SheetTextField(
          controller: _controller,
          hint: 'INVITE CODE',
          autofocus: true,
          maxLength: 8,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [_UpperCaseFormatter()],
          letterSpacing: 3,
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: AppTypography.bodySmall(color: AppColors.error)),
        ],
        const SizedBox(height: 18),
        _PrimaryButton(
          label: 'Join circle',
          busy: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}

// ── Small shared building blocks ──────────────────────────────────────
class _SheetTextField extends StatelessWidget {
  const _SheetTextField({
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.letterSpacing,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final double? letterSpacing;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.done,
      style: AppTypography.bodyLarge(color: AppColors.textPrimary)
          .copyWith(letterSpacing: letterSpacing),
      cursorColor: AppColors.gold,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodyLarge(color: AppColors.muted)
            .copyWith(letterSpacing: letterSpacing),
        counterText: '',
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:  BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:  BorderSide(color: AppColors.gold, width: 1.5),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: busy
            ?  SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.night,
                ),
              )
            : Text(label, style: AppTypography.buttonPrimary()),
      ),
    );
  }
}

/// Forces invite-code input to uppercase as the user types.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
