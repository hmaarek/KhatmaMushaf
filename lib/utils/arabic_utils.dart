class ArabicUtils {
  static const List<String> _arabicDigits = [
    '٠',
    '١',
    '٢',
    '٣',
    '٤',
    '٥',
    '٦',
    '٧',
    '٨',
    '٩',
  ];

  /// Converts Western digits (0-9) to Eastern Arabic-Indic digits (٠-٩).
  static String toArabicDigits(Object value) {
    final s = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final code = s.codeUnitAt(i);
      if (code >= 48 && code <= 57) {
        buffer.write(_arabicDigits[code - 48]);
      } else {
        buffer.write(s[i]);
      }
    }
    return buffer.toString();
  }

  /// Strips Arabic tashkeel, tatweel, Quranic stop marks, and normalizes
  /// Alef/Hamza variants to match the `text_clean` column in `mushaf.db`.
  static String normalizeForSearch(String input) {
    var s = input;
    // Remove Quranic annotations, stop marks, rub el hizb, sajdah, small letters
    s = s.replaceAll(
      RegExp(r'[\u0610-\u061A\u06D6-\u06ED\u08D4-\u08FF\u06DD\u06DE\u06E9]'),
      '',
    );
    // Remove tatweel and dagger alef
    s = s.replaceAll('\u0640', '');
    s = s.replaceAll('\u0670', '');
    // Remove standard tashkeel / harakat
    s = s.replaceAll(RegExp(r'[\u064B-\u065F\u0653-\u0656]'), '');
    // Normalize Alef variants (أ إ آ ٱ -> ا) and Uthmani hamza-alef (ءا -> ا)
    s = s.replaceAll(RegExp(r'[أإآٱٲٳٵ]'), 'ا');
    s = s.replaceAll('ءا', 'ا');
    // Collapse multiple alefs
    s = s.replaceAll(RegExp(r'ا+'), 'ا');
    // Normalize Alef Maqsura (ى -> ي)
    s = s.replaceAll('ى', 'ي');
    // Collapse whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }
}
