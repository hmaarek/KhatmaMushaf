import 'package:flutter/widgets.dart';

import '../models/mushaf_models.dart';
import '../utils/arabic_utils.dart';

enum AppLanguage { arabic, english, urdu }

/// Lightweight in-app localization supporting Arabic, English, and Urdu.
///
/// Usage everywhere in the UI:
///   tr('نص عربي', 'English text', 'اردو متن')
///   (If Urdu is omitted, falls back to Arabic for Islamic/shared terms.)
class L10n {
  L10n._();

  static AppLanguage language = AppLanguage.arabic;

  static bool get isEn => language == AppLanguage.english;
  static bool get isAr => language == AppLanguage.arabic;
  static bool get isUr => language == AppLanguage.urdu;

  /// UI text direction (Arabic & Urdu are RTL; English is LTR).
  static TextDirection get dir => isEn ? TextDirection.ltr : TextDirection.rtl;

  static CrossAxisAlignment get crossStart => CrossAxisAlignment.start;

  static Locale get locale => Locale(switch (language) {
        AppLanguage.arabic => 'ar',
        AppLanguage.english => 'en',
        AppLanguage.urdu => 'ur',
      });

  static String tr(String ar, String en, [String? ur]) => switch (language) {
        AppLanguage.arabic => ar,
        AppLanguage.english => en,
        AppLanguage.urdu => ur ?? ar,
      };

  /// Number formatted for the active language.
  static String n(Object value) => ArabicUtils.toArabicDigits(value);

  static String surahName(SurahInfo s) => isEn ? s.nameEnglish : s.nameArabic;

  static String revelation(SurahInfo s) => switch (language) {
        AppLanguage.arabic => s.revelationArabic,
        AppLanguage.english => s.isMeccan ? 'Meccan' : 'Medinan',
        AppLanguage.urdu => s.isMeccan ? 'مکی' : 'مدنی',
      };
}

/// Shorthand: `tr('عربي', 'English', 'اردو')`.
String tr(String ar, String en, [String? ur]) => L10n.tr(ar, en, ur);
