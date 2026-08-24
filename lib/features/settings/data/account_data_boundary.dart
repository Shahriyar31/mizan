/// Keeps one person's work from turning up under another person's name.
///
/// ── The problem this exists to solve ───────────────────────────────────
/// Most of what this app records is device-local and has no owner column.
/// `reflections` is keyed `UNIQUE(surah_number, ayah_number)`; `vocab_words`
/// and `layer_unlocks` have no `user_id` at all; the streak, the Al-Mizan
/// record and the reading position are plain SharedPreferences values. That is
/// a deliberate design — the app works signed out, and reading is nobody's
/// business but the reader's — but it means the *device* owns the data, not the
/// account.
///
/// Signing out used to change nothing local. So if one friend handed the phone
/// to another and the second one signed in, the second one read the first one's
/// reflections. Worse, a login calls `_syncIdentityName`, which renames the
/// single `user_profile` row in place — so the first person's offline circles
/// and Minbar posts, still keyed to the shared local id, were displayed under
/// the second person's name. That is not a privacy smell, it is a wrong
/// attribution of somebody's words about the Qur'an.
///
/// ── Why this clears on *switch* and not on sign-out ────────────────────
/// The obvious fix — wipe local data in `logOut()` — is worse than the bug.
/// Signing out and back into your own account is completely normal (a token
/// expires, you reinstall, you check something), and it would silently destroy
/// every reflection the person had written. Data loss is a harsher failure than
/// a leak between two people who are handing each other a phone.
///
/// So the boundary is drawn at a change of owner, which is the thing that
/// actually matters:
///
///   * Nobody has ever signed in here  -> the first account to sign in *adopts*
///     the existing data. Somebody who used the app offline for a week and then
///     made an account keeps everything they wrote. This is the common case and
///     it must not lose anything.
///   * The same account signs in again -> nothing is touched.
///   * A different account signs in    -> the previous owner's personal data is
///     cleared before the new session is used, and the new person starts clean.
///
/// ── What counts as personal, and what counts as the phone's ────────────
/// Cleared: things that are a record of one person — reflections, saved words,
/// which layers they have opened, their streak, their Al-Mizan record, their
/// date of birth, where they had reached in the Qur'an, their Discover
/// progress, and the local Halaqa/Minbar mirror.
///
/// Kept: things that describe the phone or how its owner likes to read — theme,
/// app-icon variant, reciter, translation and tafsir choice, Arabic font and
/// text sizes, notification preferences and reminder time. Re-choosing those is
/// pure friction and none of them says anything about a person. `hadith_cache`
/// and `api_cache` are also kept: they are downloaded content, not a record of
/// anybody, and throwing them away just costs the next person bandwidth.
///
/// `onboarding_welcome_seen` is kept too — an account switch should not drop
/// somebody back into the welcome flow on a phone that has plainly been set up.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/logger.dart';
import '../../../features/discover/data/discover_database.dart';
import '../../../services/database/database_service.dart';

class AccountDataBoundary {
  AccountDataBoundary._();

  /// The account id that owns the personal data currently on this device.
  ///
  /// Absent means "nobody has claimed it yet", which is why a first sign-in
  /// adopts rather than clears.
  static const _kOwner = 'local_data_owner_account_id';

  /// Tables in the main database that hold a record of one person.
  ///
  /// Deliberately not `hadith_cache` or `api_cache` (downloaded content, not a
  /// record of anybody) and deliberately not the schema itself — rows are
  /// deleted, tables are left standing, so nothing has to re-run a migration.
  static const _personalTables = <String>[
    'reflections',
    'vocab_words',
    'layer_unlocks',
    'hadith_reflections',
    // The offline mirror of the social features. Keyed to the local
    // `user_profile` id, so it belongs to whoever that row described.
    'halaqa_reactions',
    'halaqa_shares',
    'halaqa_members',
    'halaqas',
    'minbar_reactions',
    'minbar_shares',
    // Last, because the rows above are attributed to it.
    'user_profile',
  ];

  /// SharedPreferences keys that record one person rather than one phone.
  static const _personalPrefs = <String>[
    // Al-Mizan record + date of birth
    'mizan_first_day',
    'mizan_days_recorded',
    'mizan_longest_run',
    'mizan_recent_days',
    'meezan_birth_date',
    // Today's Mizan + muhasabah
    'todays_mizan',
    'last_muhasabah_date',
    // Streak
    'streak_count',
    'streak_last_active_date',
    'last_opened_at',
    // Saved ayat + where they had reached
    'saved_ayat',
    'last_ayah',
    'last_ayah_arabic',
    'last_ayah_translation',
    'last_surah',
    'last_surah_name',
    // Whether *they* have seen the six-layer explainer. Unlike the welcome
    // flow, this one is genuinely per-person: it is the first time for them.
    'reader_layers_intro_seen',
  ];

  /// Records the already-signed-in account as the owner, without clearing
  /// anything.
  ///
  /// This is the upgrade path, and it has to exist. Every install that predates
  /// this file has local data and no recorded owner. If the first thing the
  /// owner key ever saw were the *next* login, that login would look like a
  /// switch on some devices and an adoption on others depending on nothing more
  /// than who happened to log in first — so the person already signed in on this
  /// phone is claimed here, at startup, before any of that can happen.
  ///
  /// Idempotent, and never clears: if an owner is already recorded this does
  /// nothing at all, including when the recorded owner is somebody else (that
  /// case is a switch, and it belongs to [onSignedIn], which is reached through
  /// an actual sign-in rather than through a restored session).
  static Future<void> claimExistingSession(String accountId) async {
    if (accountId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_kOwner) != null) return;
      await prefs.setString(_kOwner, accountId);
      AppLogger.info(
        'claimed local data for the already-signed-in account',
        tag: 'AccountDataBoundary',
      );
    } catch (e) {
      AppLogger.error('claim failed', error: e, tag: 'AccountDataBoundary');
    }
  }

  /// Called after a successful sign-in, before the session is used for
  /// anything.
  ///
  /// Returns true when the previous owner's data was cleared, so the caller can
  /// invalidate providers that are holding it in memory. Never throws: a
  /// failure here must not block somebody from signing in, and it is reported
  /// through the log rather than the UI because there is nothing the person
  /// could usefully do about it.
  ///
  /// ── The one case this deliberately does not catch ──────────────────
  /// A phone whose owner has *never* signed in, handed to a friend who signs in
  /// with their own account: no owner is recorded, so this adopts rather than
  /// clears, and the friend sees the first person's reflections.
  ///
  /// That is a knowing trade, not an oversight. The alternative — clear whenever
  /// no owner is recorded — destroys the work of every person who used the app
  /// offline before making an account, which is the ordinary way into this app
  /// and by a wide margin the more common event. Silently deleting somebody's
  /// written reflections is a worse outcome than briefly showing them to a
  /// friend standing next to them. Every switch after the first is caught.
  static Future<bool> onSignedIn(String accountId) async {
    if (accountId.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final owner = prefs.getString(_kOwner);

      if (owner == accountId) return false; // Same person. Leave it alone.

      if (owner == null) {
        // First account on this device adopts whatever is already here.
        await prefs.setString(_kOwner, accountId);
        AppLogger.info(
          'local data adopted by first account',
          tag: 'AccountDataBoundary',
        );
        return false;
      }

      // A different person. Clear before the new session touches anything.
      await _clear(prefs);
      await prefs.setString(_kOwner, accountId);
      AppLogger.info(
        'account changed — cleared the previous owner local data',
        tag: 'AccountDataBoundary',
      );
      return true;
    } catch (e) {
      AppLogger.error(
        'could not apply the account boundary',
        error: e,
        tag: 'AccountDataBoundary',
      );
      return false;
    }
  }

  /// Wipes this device's personal data and forgets who owned it.
  ///
  /// Not called on sign-out — see the header for why. This is here for the
  /// Settings "delete account" path, where the person is explicitly asking to
  /// be forgotten, and for tests.
  static Future<void> forgetEverything() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _clear(prefs);
      await prefs.remove(_kOwner);
    } catch (e) {
      AppLogger.error(
        'could not clear local data',
        error: e,
        tag: 'AccountDataBoundary',
      );
    }
  }

  static Future<void> _clear(SharedPreferences prefs) async {
    // Each store is cleared independently and a failure in one does not stop
    // the others: clearing three of four is strictly better than clearing none.
    try {
      final db = await DatabaseService.instance.database;
      await db.transaction((txn) async {
        for (final table in _personalTables) {
          // `IF EXISTS` is not available for DELETE, and a table missing from
          // an older schema version would otherwise abort the whole
          // transaction and leave the rest of the data in place.
          try {
            await txn.delete(table);
          } catch (e) {
            AppLogger.warning(
              'skipped $table: $e',
              tag: 'AccountDataBoundary',
            );
          }
        }
      });
    } catch (e) {
      AppLogger.error('main db not cleared', error: e, tag: 'AccountDataBoundary');
    }

    try {
      final discover = await DiscoverDatabase.database;
      await discover.transaction((txn) async {
        for (final table in const [
          'discover_quiz_answers',
          'discover_quiz_results',
          'discover_progress',
        ]) {
          try {
            await txn.delete(table);
          } catch (e) {
            AppLogger.warning('skipped $table: $e', tag: 'AccountDataBoundary');
          }
        }
      });
    } catch (e) {
      AppLogger.error(
        'discover db not cleared',
        error: e,
        tag: 'AccountDataBoundary',
      );
    }

    for (final key in _personalPrefs) {
      try {
        await prefs.remove(key);
      } catch (e) {
        AppLogger.warning('kept $key: $e', tag: 'AccountDataBoundary');
      }
    }
  }
}
