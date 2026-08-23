/// Al-Meezan (الْمِيزَان) — "The Scale".
///
/// A quiet measure of the time a person has been given: days lived, Jumu'ahs
/// witnessed, and Ramadans witnessed (by the Hijri calendar). The intent is
/// reflection on the finiteness of life, not gamification.
///
/// Everything is derived from a single birth date the user sets, stored only on
/// device (SharedPreferences key `meezan_birth_date`, ISO-8601). No scripture is
/// quoted here — the reflective copy is the app's own framing, so nothing needs
/// a citation.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/util/hijri_date.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class AlMeezanScreen extends StatefulWidget {
  const AlMeezanScreen({super.key});

  @override
  State<AlMeezanScreen> createState() => _AlMeezanScreenState();
}

class _AlMeezanScreenState extends State<AlMeezanScreen> {
  static const _prefsKey = 'meezan_birth_date';

  DateTime? _birthDate;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (!mounted) return;
    setState(() {
      _birthDate = stored == null ? null : DateTime.tryParse(stored);
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select your birth date',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:  ColorScheme.dark(
            primary: AppColors.gold,
            onPrimary: AppColors.ink,
            surface: AppColors.surfaceElevated,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, picked.toIso8601String());
    if (!mounted) return;
    setState(() => _birthDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: Column(
        children: [
          const _MeezanHeader(),
          Expanded(
            child: _loading
                ?  Center(
                    child: CircularProgressIndicator(
                      color: AppColors.gold,
                      strokeWidth: 2,
                    ),
                  )
                : _birthDate == null
                    ? _SetBirthDatePrompt(onSet: _pickDate)
                    : _MeezanBody(birthDate: _birthDate!, onEdit: _pickDate),
          ),
        ],
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────
class _MeezanHeader extends StatelessWidget {
  const _MeezanHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.night,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 12,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child:  Icon(
              Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الْمِيزَان',
                style: AppTypography.arabicBody()
                    .copyWith(fontSize: 20, color: AppColors.amber),
              ),
              Text(
                'The Scale — a measure of your days',
                style: AppTypography.caption(color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty state: ask for birth date ──────────────────────────────────
class _SetBirthDatePrompt extends StatelessWidget {
  const _SetBirthDatePrompt({required this.onSet});
  final VoidCallback onSet;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child:  Icon(Icons.balance_rounded,
                  color: AppColors.amber, size: 34),
            ),
            const SizedBox(height: 24),
            Text(
              'Weigh your days',
              style: AppTypography.displaySmall(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Set your birth date to see the measure of the time you have been '
              'given. It is stored only on your device.',
              style: AppTypography.bodyMedium(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onSet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 15),
                decoration: BoxDecoration(
                  color: AppColors.amber,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'Set birth date',
                  style: AppTypography.labelLarge(color: AppColors.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Populated body ───────────────────────────────────────────────────
class _MeezanBody extends StatelessWidget {
  const _MeezanBody({required this.birthDate, required this.onEdit});
  final DateTime birthDate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysLived = now.difference(birthDate).inDays;
    final jumuahs = _fridaysBetween(birthDate, now);
    final ramadans = _hijriYearsBetween(birthDate, now);
    final weeks = daysLived ~/ 7;
    final months = (daysLived / 30.44).floor();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          'A quiet measure of the time you have been given.',
          style: AppTypography.bodyMedium(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        // Hero — days lived
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.amber.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _grouped(daysLived),
                style: AppTypography.displayLarge(color: AppColors.amber)
                    .copyWith(fontSize: 46, height: 1.0),
              ),
              const SizedBox(height: 6),
              Text(
                'days lived — each one a trust',
                style: AppTypography.bodySmall(color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              Text(
                '≈ ${_grouped(weeks)} weeks  ·  ${_grouped(months)} months',
                style: AppTypography.caption(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Two exact/Hijri measures
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.brightness_5_rounded,
                color: AppColors.gold,
                value: _grouped(jumuahs),
                label: 'Jumuʿahs witnessed',
                sub: 'every Friday of your life',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.nightlight_round,
                color: AppColors.violet,
                value: '$ramadans',
                label: 'Ramadans witnessed',
                sub: 'by the Hijri calendar',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'Every number here is a mercy — a reminder that time is the one '
            'thing you are given and can never earn back. Spend the next day '
            'as one you would be content to have weighed.',
            style: AppTypography.bodyMedium(color: AppColors.textSecondary)
                .copyWith(height: 1.6),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: onEdit,
            child: Text(
              'Born ${_formatDate(birthDate)}  ·  change',
              style: AppTypography.caption(color: AppColors.muted),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.sub,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTypography.displaySmall(color: AppColors.textPrimary)
                .copyWith(fontSize: 24),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.labelMedium(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: AppTypography.caption(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

// ── Pure calculations ─────────────────────────────────────────────────

/// Inclusive count of Fridays between two dates (date-only).
int _fridaysBetween(DateTime from, DateTime to) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  final totalDays = end.difference(start).inDays;
  if (totalDays < 0) return 0;
  // Days from start until the first Friday (DateTime.friday == 5).
  final offset = (DateTime.friday - start.weekday + 7) % 7;
  if (offset > totalDays) return 0;
  return ((totalDays - offset) ~/ 7) + 1;
}

/// Full Hijri years elapsed between two Gregorian dates — i.e. the number of
/// Ramadans a person has lived through.
///
/// The conversion itself now lives in `core/util/hijri_date.dart` so that Home's
/// date line and this screen's Ramadan count can never disagree. See that file
/// for the accuracy caveat: it is the tabular calendar, not moon sighting.
int _hijriYearsBetween(DateTime from, DateTime to) =>
    HijriDate.yearsBetween(from, to);

/// 12345 → "12,345".
String _grouped(int n) => n
    .toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
