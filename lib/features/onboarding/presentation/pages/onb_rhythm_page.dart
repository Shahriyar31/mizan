/// Screen 4 of 6 — A little, kept up.
///
/// Two settings and one promise. The settings are how long a day's reading
/// should be and when to be reminded; the promise is what the reminder will and
/// will not do, and it is binding.
///
/// ── The permission prompt fires here and nowhere earlier ──────────────
/// The system dialog is requested by the primary button on this screen, after
/// the person has read what the notification will contain. An app that asks on
/// first launch is asking before it has said anything, and the honest answer to
/// a question you do not understand is no — which is why apps that ask early get
/// denied and then have to nag. There is exactly one call site for the request
/// in the whole app ([NotificationPreferencesController.setMaster]) and this
/// screen goes through it.
///
/// ── The promise is enforced in code, not just in copy ─────────────────
/// The screen says "One notification a day … Nothing else". The app's own
/// defaults are three categories — daily ayah, daily du'a, today's encounter —
/// all scheduled at the same minute, so accepting the defaults here would break
/// the promise three times over on the first morning. So this screen switches
/// the other categories off before it turns the master switch on. Somebody who
/// wants more can add them in Settings; nobody gets them because they tapped a
/// button that promised one.
///
/// ── The prayer-time deviation, stated plainly ─────────────────────────
/// The brief specifies "After Fajr · 5:12 am · follows your prayer times" and
/// says the reminder must anchor to a prayer time rather than a clock time.
/// Mizan has no prayer-time engine — there is no location permission, no
/// calculation method, no Adhan library, and nothing anywhere in the codebase
/// that computes Fajr. The nearest thing is `prayerTimesPassedSince`, which
/// multiplies elapsed days by five for the Al-Mizan figures and is not a
/// timetable.
///
/// So the row here shows the real clock time the reminder is actually set to,
/// and says so. The alternative — print "After Fajr · 5:12 am" over a
/// notification that in fact fires at a fixed hour — would put a number on
/// screen that nothing computed, which is the one thing the Al-Mizan rules
/// forbid outright. When a prayer-time engine exists, this row is the only place
/// that has to change.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/domain/notification_preferences_provider.dart';
import '../../domain/onboarding_answers.dart';
import '../widgets/onboarding_kit.dart';

class OnbRhythmPage extends ConsumerStatefulWidget {
  const OnbRhythmPage({
    super.key,
    required this.onDone,
    required this.onSkip,
  });

  /// Called after the permission decision, whichever way it went. The flow moves
  /// on either way: a declined notification is a valid answer, not a dead end.
  final VoidCallback onDone;
  final VoidCallback onSkip;

  @override
  ConsumerState<OnbRhythmPage> createState() => _OnbRhythmPageState();
}

class _OnbRhythmPageState extends ConsumerState<OnbRhythmPage> {
  bool _asking = false;

  Future<void> _allowAndContinue() async {
    if (_asking) return;
    setState(() => _asking = true);

    final notifications = ref.read(notificationPreferencesProvider.notifier);

    // Order matters. setCategory only reschedules when the master switch is
    // already on, so narrowing to one category first costs nothing; doing it
    // after setMaster would schedule three notifications and then cancel two.
    await notifications.setCategory(
      dailyAyah: true,
      dailyDua: false,
      todaysEncounter: false,
      learningReminder: false,
    );
    // This is the call that shows the system dialog. It rolls the flag back by
    // itself if the person says no, so there is nothing to undo here.
    await notifications.setMaster(true);

    if (!mounted) return;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final answers = ref.watch(onboardingAnswersProvider);
    final prefs = ref.watch(notificationPreferencesProvider);

    return OnbScaffold(
      step: 3,
      onSkip: widget.onSkip,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OnbPrimaryButton(
            label: 'Allow reminders & begin',
            onTap: _allowAndContinue,
          ),
          const SizedBox(height: 14),
          OnbQuietButton(
            label: 'Begin without reminders',
            onTap: widget.onDone,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnbEyebrow('Your rhythm'),
          const SizedBox(height: 12),
          Text('A little, kept up', style: OnbType.heading()),
          const SizedBox(height: 12),
          Text(
            'The Prophet ﷺ said the deeds most beloved to Allah are the '
            'constant ones, however small. Pick something you can keep.',
            style: OnbType.sans(fontSize: 13.5),
          ),

          const SizedBox(height: 26),
          Text('MINUTES A DAY', style: OnbType.eyebrow()),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final option in DailyMinutes.values) ...[
                if (option != DailyMinutes.values.first)
                  const SizedBox(width: 10),
                Expanded(
                  child: _MinutesCard(
                    option: option,
                    selected: answers.minutes == option,
                    onTap: () => ref
                        .read(onboardingAnswersProvider.notifier)
                        .setMinutes(option),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 22),
          Text('REMIND ME', style: OnbType.eyebrow()),
          const SizedBox(height: 10),
          _ReminderRow(
            hour: prefs.hour,
            minute: prefs.minute,
            onPick: (picked) => ref
                .read(notificationPreferencesProvider.notifier)
                .setTime(picked),
          ),

          const SizedBox(height: 14),
          const _PromiseNote(),
        ],
      ),
    );
  }
}

// ── Minutes a day ───────────────────────────────────────────────────────

class _MinutesCard extends StatelessWidget {
  const _MinutesCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final DailyMinutes option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${option.minutes} minutes a day — ${option.label}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 66,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? OnbTok.gold13 : OnbTok.paper045,
            border: Border.all(
              color: selected ? OnbTok.gold : OnbTok.gold24,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${option.minutes}',
                style: OnbType.numeral(
                  color: selected ? OnbTok.gold : OnbTok.paper,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                option.label,
                style: OnbType.sans(
                  fontSize: 11,
                  color: OnbTok.mistDim,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Remind me ───────────────────────────────────────────────────────────

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.hour,
    required this.minute,
    required this.onPick,
  });

  final int hour;
  final int minute;
  final ValueChanged<TimeOfDay> onPick;

  Future<void> _open(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
      helpText: 'ONE REMINDER A DAY',
      // The picker is a Material surface, so it needs the dark theme handed to
      // it explicitly — this flow forces dark regardless of the system setting,
      // and a dialog inherits from the app theme, not from the screen behind it.
      builder: (context, child) => Theme(
        data: ThemeData.dark(useMaterial3: true).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: OnbTok.gold,
            onPrimary: OnbTok.ink,
            surface: Color(0xFF0F3B4C),
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeOfDay(hour: hour, minute: minute);
    final label = t.format(context);

    return Semantics(
      button: true,
      label: 'Reminder at $label. Change the time.',
      child: GestureDetector(
        onTap: () => _open(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: OnbTok.paper045,
            border: Border.all(color: OnbTok.gold24),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule, size: 20, color: OnbTok.gold),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: OnbType.sans(
                        fontSize: 14.5,
                        weight: FontWeight.w600,
                        color: OnbTok.paper,
                        height: 1.3,
                      ),
                    ),
                    Text(
                      // What the app actually does, described exactly. See the
                      // library comment for why this is not "follows your
                      // prayer times".
                      'Every day, at the time you pick',
                      style: OnbType.sans(
                        fontSize: 12.5,
                        color: OnbTok.mistDim,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.expand_more, size: 20, color: OnbTok.mistDim),
            ],
          ),
        ),
      ),
    );
  }
}

// ── The promise ─────────────────────────────────────────────────────────

class _PromiseNote extends StatelessWidget {
  const _PromiseNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: OnbTok.blue10,
        border: Border.all(color: OnbTok.blue30),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.notifications_active,
            size: 19,
            color: OnbTok.mist,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'One notification a day, at the time you chose. Nothing else — '
              "no streak guilt, no “we miss you”.",
              style: OnbType.sans(fontSize: 12.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
