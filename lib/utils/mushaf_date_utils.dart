import '../l10n/l10n.dart';
import 'arabic_utils.dart';

/// Offline Hijri + Gregorian date formatting utility for Khatma Mushaf.
///
/// Formats all dates without time-of-day, using `dd-MonthName-Year`,
/// and places the Hijri date on the line above the Gregorian date.
class MushafDateUtils {
  MushafDateUtils._();

  static const List<String> _gregorianMonthsAr = <String>[
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  static const List<String> _gregorianMonthsEn = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _gregorianMonthsUr = <String>[
    'جنوری',
    'فروری',
    'مارچ',
    'اپریل',
    'مئی',
    'جون',
    'جولائی',
    'اگست',
    'ستمبر',
    'اکتوبر',
    'نومبر',
    'دسمبر',
  ];

  static const List<String> _hijriMonthsAr = <String>[
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  static const List<String> _hijriMonthsEn = <String>[
    'Muharram',
    'Safar',
    'Rabi al-Awwal',
    'Rabi al-Thani',
    'Jumada al-Ula',
    'Jumada al-Akhirah',
    'Rajab',
    'Shaban',
    'Ramadan',
    'Shawwal',
    'Dhu al-Qadah',
    'Dhu al-Hijjah',
  ];

  static const List<String> _hijriMonthsUr = <String>[
    'محرم',
    'صفر',
    'ربیع الاول',
    'ربیع الثانی',
    'جمادی الاولیٰ',
    'جمادی الثانیہ',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذوالقعدہ',
    'ذوالحجہ',
  ];

  /// Converts a Gregorian [DateTime] (date part only) into a Hijri
  /// `(year, month, day)` triple using the standard astronomical tabular
  /// Islamic calendar conversion from Julian Day Number.
  static ({int year, int month, int day}) toHijri(DateTime date) {
    final int y = date.year;
    final int m = date.month;
    final int d = date.day;

    // Gregorian date to Julian Day Number (JDN)
    final int a = (14 - m) ~/ 12;
    final int y2 = y + 4800 - a;
    final int m2 = m + 12 * a - 3;
    final int jdn =
        d +
        ((153 * m2 + 2) ~/ 5) +
        365 * y2 +
        (y2 ~/ 4) -
        (y2 ~/ 100) +
        (y2 ~/ 400) -
        32045;

    // JDN to Hijri (Islamic civil / Kuwaiti tabular calendar)
    final int l = jdn - 1948440 + 10632;
    final int n = (l - 1) ~/ 10631;
    final int l2 = l - 10631 * n + 354;
    final int j =
        (((10985 - l2) ~/ 5316)) * (((50 * l2) ~/ 17719)) +
        ((l2 ~/ 5670)) * (((43 * l2) ~/ 15238));
    final int l3 =
        l2 -
        (((30 - j) ~/ 15)) * (((17719 * j) ~/ 50)) -
        ((j ~/ 16)) * (((15238 * j) ~/ 43)) +
        29;
    final int hMonth = ((24 * l3) ~/ 709).clamp(1, 12);
    final int hDay = (l3 - ((709 * hMonth) ~/ 24)).clamp(1, 30);
    final int hYear = 30 * n + j - 30;

    return (year: hYear, month: hMonth, day: hDay);
  }

  /// Formats the Gregorian date as `dd-MonthName-Year` in the active language,
  /// ignoring the time of day.
  static String formatGregorian(DateTime dt) {
    final dayStr = ArabicUtils.toArabicDigits(
      dt.day.toString().padLeft(2, '0'),
    );
    final yearStr = ArabicUtils.toArabicDigits(dt.year);
    final mIdx = (dt.month - 1).clamp(0, 11);
    final monthName = switch (L10n.language) {
      AppLanguage.arabic => _gregorianMonthsAr[mIdx],
      AppLanguage.english => _gregorianMonthsEn[mIdx],
      AppLanguage.urdu => _gregorianMonthsUr[mIdx],
    };
    final suffix = switch (L10n.language) {
      AppLanguage.arabic => ' م',
      AppLanguage.english => '',
      AppLanguage.urdu => 'ء',
    };
    return '$dayStr-$monthName-$yearStr$suffix';
  }

  /// Formats the Hijri date as `dd-HijriMonthName-Year` in the active language,
  /// ignoring the time of day.
  static String formatHijri(DateTime dt) {
    final h = toHijri(dt);
    final dayStr = ArabicUtils.toArabicDigits(h.day.toString().padLeft(2, '0'));
    final yearStr = ArabicUtils.toArabicDigits(h.year);
    final mIdx = (h.month - 1).clamp(0, 11);
    final monthName = switch (L10n.language) {
      AppLanguage.arabic => _hijriMonthsAr[mIdx],
      AppLanguage.english => _hijriMonthsEn[mIdx],
      AppLanguage.urdu => _hijriMonthsUr[mIdx],
    };
    final suffix = switch (L10n.language) {
      AppLanguage.arabic => ' هـ',
      AppLanguage.english => ' AH',
      AppLanguage.urdu => ' ھ',
    };
    return '$dayStr-$monthName-$yearStr$suffix';
  }

  /// Returns a two-line date string with the Hijri date on the top line
  /// and the Gregorian date (`dd-MonthName-Year`) on the line below.
  static String formatHijriAboveGregorian(DateTime dt) {
    return '${formatHijri(dt)}\n${formatGregorian(dt)}';
  }
}
