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

  /// Set by `L10n` consumers: when true, digits stay Western (English UI).
  static bool useWesternDigits = false;

  /// Converts Western digits (0-9) to Eastern Arabic-Indic digits (٠-٩)
  /// (unless the app language is English, in which case digits are unchanged).
  static String toArabicDigits(Object value) {
    final s = value.toString();
    if (useWesternDigits) return s;
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

  /// Produces clean, readable Arabic text without Tashkeel (harakat) or
  /// Quranic stop marks for plain-text sharing, while preserving standard
  /// hamzas (أ / إ / آ / ؤ / ئ / ء) and standard Arabic spelling:
  /// - Dagger alef in regular words becomes ا (العالمين، الكتاب، السماوات، رزقناهم)
  /// - Uthmani وٰة becomes اة (الصلاة، الزكاة، الحياة)
  /// - Dagger alef on ىٰ stays ى (على، إلى، حتى، موسى، هدى)
  /// - Words where Arabic spelling omits the alef keep their standard spelling
  ///   (هذا، هذه، هذان، هذين، هؤلاء، ذلك، ذلكم، كذلك، أولئك، لكن، لكنا، الرحمن، إله، الله).
  static String stripTashkeelForSharing(
    String textUthmani, {
    String? textClean,
  }) {
    var s = textUthmani;
    // 1. Remove dagger alef on top of Alef Maqsura (ىٰ -> ى, as in على، إلى، حتى، موسى، هدى)
    s = s.replaceAll(RegExp(r'\u0649[\u064B-\u065F]*\u0670\u0653?'), '\u0649');
    // 2. Convert Uthmani وٰة (as in الصلوٰة، الزكوٰة، الحيوٰة، الغدوٰة، النجوٰة، مشكوٰة، منوٰة) to اة
    s = s.replaceAll(
      RegExp(r'\u0648[\u064B-\u065F]*\u0670\u0653?(?=\u0629)'),
      '\u0627',
    );
    // And الربوٰا۟ -> الربا
    s = s.replaceAll(
      RegExp(r'\u0648[\u064B-\u065F]*\u0670\u0627\u06DF'),
      '\u0627',
    );
    // 3. Convert Uthmani ـَٔا and ءَا (as in الآخرة، الآيات، بآياتنا، آمنوا، القرآن) to آ
    s = s.replaceAll(RegExp(r'\u0640?\u0654[\u064B-\u0652]*\u0627'), '\u0622');
    s = s.replaceAll(RegExp(r'\u0621[\u064B-\u0652]*\u0627'), '\u0622');
    // And Uthmani ـُٔو (as in يَـُٔودُهُۥ) to ؤو
    s = s.replaceAll(RegExp(r'\u0640\u0654\u064F\u0648'), 'ؤو');
    // 4. Convert Alef Wasla (ٱ) to regular Alef (ا)
    s = s.replaceAll('\u0671', '\u0627');
    // 5. Convert remaining tatweel+dagger-alef (ـٰ) and bare dagger-alef (ٰ) to ا
    s = s.replaceAll(RegExp(r'\u0640?\u0670\u0653?'), '\u0627');
    // 6. Remove Quranic pause/annotation symbols, small high/low letters, tatweel, and harakat
    s = s.replaceAll(
      RegExp(
        r'[\u0610-\u061A\u06D6-\u06ED\u08D4-\u08FF\u06DD\u06DE\u06E9\u0640\u0670\u064B-\u065F]',
      ),
      '',
    );
    // 7. Fix the closed set of Arabic words where dagger alef is pronounced
    //    but NOT written in standard Arabic orthography (الرسم الإملائي)
    final wordFixes = <(RegExp, String Function(Match))>[
      (RegExp(r'(^|\s)([وفبكل]*)هاذا(?=\s|$)'), (m) => '${m[1]}${m[2]}هذا'),
      (RegExp(r'(^|\s)([وفبكل]*)هاذه(?=\s|$)'), (m) => '${m[1]}${m[2]}هذه'),
      (RegExp(r'(^|\s)([وفبكل]*)هاذان(?=\s|$)'), (m) => '${m[1]}${m[2]}هذان'),
      (RegExp(r'(^|\s)([وفبكل]*)هاذين(?=\s|$)'), (m) => '${m[1]}${m[2]}هذين'),
      (RegExp(r'(^|\s)([وفبكل]*)هاؤلاء(?=\s|$)'), (m) => '${m[1]}${m[2]}هؤلاء'),
      (
        RegExp(r'(^|\s)([وفبكل]*)ذالك(م|ما|ن)?(?=\s|$)'),
        (m) => '${m[1]}${m[2]}ذلك${m[3] ?? ''}',
      ),
      (
        RegExp(r'(^|\s)([وفب]*)كذالك(م|ما|ن)?(?=\s|$)'),
        (m) => '${m[1]}${m[2]}كذلك${m[3] ?? ''}',
      ),
      (
        RegExp(r'(^|\s)([وفبكل]*)أولائك(م)?(?=\s|$)'),
        (m) => '${m[1]}${m[2]}أولئك${m[3] ?? ''}',
      ),
      (
        RegExp(r'(^|\s)([وف]*)لاكن(ا|كم|هم|ي|ى|ه|ها)?(?=\s|$)'),
        (m) => '${m[1]}${m[2]}لكن${m[3] ?? ''}',
      ),
      (
        RegExp(r'(^|\s)([وفبكل]*)الرحمان(?=\s|$)'),
        (m) => '${m[1]}${m[2]}الرحمن',
      ),
      (RegExp(r'(^|\s)([وفبكل]*)رحمان(?=\s|$)'), (m) => '${m[1]}${m[2]}رحمن'),
      (
        RegExp(r'(^|\s)([وفبكل]*)إلاه(ا|ي|ى|ك|كم|نا|هم|ه|ين)?(?=\s|$)'),
        (m) => '${m[1]}${m[2]}إله${m[3] ?? ''}',
      ),
      (
        RegExp(r'(^|\s)([وفبكل]*)اللاه(م)?(?=\s|$)'),
        (m) => '${m[1]}${m[2]}الله${m[3] ?? ''}',
      ),
    ];
    for (final (pattern, builder) in wordFixes) {
      s = s.replaceAllMapped(pattern, builder);
    }
    // Collapse multiple spaces
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isNotEmpty) return s;
    if (textClean != null && textClean.contains(' | ')) {
      return textClean.split(' | ').first.trim();
    }
    return textClean?.trim() ?? '';
  }
}
