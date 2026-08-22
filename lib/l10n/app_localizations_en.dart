// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageCurrent => 'Current';

  @override
  String get languageEnglishOnly => 'The app is English-only for now';

  @override
  String get languageNotTranslated => 'Not yet translated';
}
