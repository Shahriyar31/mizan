/// Relative-time formatting for feeds ("2h ago", "3d ago").
///
/// Small and dependency-free on purpose — a feed only needs a coarse, friendly
/// label, not a full i18n date library. If the app later adds localisation,
/// this is the one place to swap in `timeago` or `intl`.
library;

class RelativeTime {
  RelativeTime._();

  /// A short label like "just now", "5m", "3h", "2d", "3w", or a date for
  /// anything older than ~4 weeks.
  static String short(DateTime time, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final d = ref.difference(time);

    if (d.inSeconds < 45) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    if (d.inDays < 28) return '${(d.inDays / 7).floor()}w';
    return '${time.day}/${time.month}/${time.year % 100}';
  }

  /// A longer, sentence-friendly form like "2 days ago" (used in the nudge).
  static String long(DateTime time, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final d = ref.difference(time);

    if (d.inMinutes < 60) {
      final m = d.inMinutes.clamp(1, 59);
      return '$m minute${m == 1 ? '' : 's'} ago';
    }
    if (d.inHours < 24) {
      return '${d.inHours} hour${d.inHours == 1 ? '' : 's'} ago';
    }
    final days = d.inDays;
    return '$days day${days == 1 ? '' : 's'} ago';
  }
}
