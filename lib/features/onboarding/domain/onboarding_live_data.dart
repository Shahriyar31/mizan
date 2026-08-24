/// The one number in the welcome flow that is real.
///
/// Screen 3 shows a live chip under each of the three rooms, and the brief is
/// blunt about what those chips are for: "The live chip is the point of this
/// screen… Wire these to live data; if a room genuinely has nothing, say so
/// honestly as Growth does. Never fake a number."
///
/// ── Why only one of the three can be live ─────────────────────────────
/// Every screen in this flow runs *before* sign-in — Screen 6 is the sign-in
/// screen, and Screen 1's quiet link is the only other way out. So the flow
/// always executes with an anonymous session, and of the three rooms:
///
///  * **Minbar** is genuinely readable. Its RLS policy is
///    `minbar_shares_select_public … FOR SELECT TO anon, authenticated`, so the
///    anon key can count it. That count is what this file provides.
///  * **Halaqa** is not. `halaqas` and `halaqa_members` are `TO authenticated`
///    throughout, which is correct — a circle of eight people reading together
///    is not public — and it means there is no honest number to show before
///    sign-in. Its chip carries a product fact instead: two to eight people, by
///    invite code. That is true whether or not anyone has joined one.
///  * **Growth** has nothing to count by definition. It starts at the reader's
///    first ayah, which has not happened yet. The brief's own line — "Starts
///    counting from your first ayah" — is the honest one and is used verbatim.
///
/// Note also what is *not* here. The mockup's Minbar chip reads "6 talks · 4–9
/// min". There is no duration on a Minbar post — a post is a shared ayah or
/// hadith with an optional note under a hundred characters — so a minute range
/// would have to be invented, and it is left out rather than guessed.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/utils/logger.dart';

/// How many posts have been shared to Al-Minbar in the last seven days.
///
/// Null means "we do not know" — not zero. The distinction matters, because the
/// chip says something different in each case: an unconfigured or unreachable
/// backend must not render as "Nothing shared yet", which would be a claim about
/// the feed rather than about the network.
final minbarWeekCountProvider = FutureProvider<int?>((ref) async {
  if (!SupabaseConfig.current.isUsable) return null;

  final since = DateTime.now().toUtc().subtract(const Duration(days: 7));
  try {
    // A HEAD request. It returns the count in a header and no rows at all, so
    // the welcome flow never downloads a feed it is not going to show.
    return await Supabase.instance.client
        .from('minbar_shares')
        .count(CountOption.exact)
        .gte('shared_at', since.toIso8601String());
  } catch (e) {
    // Swallowed on purpose, and logged. A welcome screen that shows a network
    // error before the person has an account has failed at the only job it has.
    AppLogger.debug(
      'Minbar week count unavailable during onboarding: $e',
      tag: 'onboarding',
    );
    return null;
  }
});
