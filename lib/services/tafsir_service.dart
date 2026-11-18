import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../l10n/l10n.dart';
import '../models/mushaf_models.dart';
import '../utils/arabic_utils.dart';
import 'database_service.dart';
import 'smart_search_service.dart';

/// Concise / Summary Tafsir sources for the "المعنى الإجمالي" tab.
enum SummaryTafsirSource {
  muyassar(
    id: 'ar_muyassar',
    arabicTitle: 'التفسير الميسر',
    arabicAuthor: 'مجمع الملك فهد لطباعة المصحف الشريف',
    quranComResourceId: 16,
    alQuranCloudEdition: 'ar.muyassar',
  ),
  jalalayn(
    id: 'ar_jalalayn',
    arabicTitle: 'المختصر الوجيز (الجلالين)',
    arabicAuthor: 'بيان وجيز لمعاني الآية ومفرداتها',
    quranComResourceId: null,
    alQuranCloudEdition: 'ar.jalalayn',
  ),
  enSahih(
    id: 'en_sahih',
    arabicTitle: 'Saheeh International translation',
    arabicAuthor: 'Saheeh International',
    quranComResourceId: null,
    alQuranCloudEdition: 'en.sahih',
    isEnglish: true,
  ),
  enTazkirul(
    id: 'en_tazkirul',
    arabicTitle: 'Tazkirul Quran',
    arabicAuthor: 'Maulana Wahiduddin Khan',
    quranComResourceId: 817,
    alQuranCloudEdition: null,
    isEnglish: true,
  );

  final String id;
  final String arabicTitle;
  final String arabicAuthor;
  final int? quranComResourceId;
  final String? alQuranCloudEdition;
  final bool isEnglish;

  const SummaryTafsirSource({
    required this.id,
    required this.arabicTitle,
    required this.arabicAuthor,
    required this.quranComResourceId,
    required this.alQuranCloudEdition,
    this.isEnglish = false,
  });

  String get title => arabicTitle;
  String get author => arabicAuthor;

  /// Sources matching the active UI language.
  static List<SummaryTafsirSource> forLanguage() => values
      .where((s) => s.isEnglish == L10n.isEn)
      .toList(growable: false);
}

/// Authoritative Detailed Tafsir sources for the "التفسير التفصيلي" tab
/// (excluding Al-Sa'di per user preference).
enum DetailedTafsirSource {
  ibnKathir(
    id: 'ar_ibn_kathir',
    arabicTitle: 'تفسير ابن كثير',
    arabicAuthor: 'الإمام الحافظ عماد الدين ابن كثير (تفسير القرآن العظيم)',
    quranComResourceId: 14,
    alQuranCloudEdition: null,
  ),
  tabari(
    id: 'ar_tabari',
    arabicTitle: 'تفسير الطبري',
    arabicAuthor: 'الإمام محمد بن جرير الطبري (جامع البيان في تأويل القرآن)',
    quranComResourceId: 15,
    alQuranCloudEdition: null,
  ),
  baghawi(
    id: 'ar_baghawi',
    arabicTitle: 'تفسير البغوي',
    arabicAuthor: 'الإمام الحسين بن مسعود البغوي (معالم التنزيل)',
    quranComResourceId: 94,
    alQuranCloudEdition: 'ar.baghawi',
  ),
  qurtubi(
    id: 'ar_qurtubi',
    arabicTitle: 'تفسير القرطبي',
    arabicAuthor: 'الإمام شمس الدين القرطبي (الجامع لأحكام القرآن)',
    quranComResourceId: 90,
    alQuranCloudEdition: 'ar.qurtubi',
  ),
  waseet(
    id: 'ar_waseet',
    arabicTitle: 'التفسير الوسيط',
    arabicAuthor: 'مجمع البحوث الإسلامية بالأزهر الشريف',
    quranComResourceId: 93,
    alQuranCloudEdition: 'ar.waseet',
  ),
  enIbnKathir(
    id: 'en_ibn_kathir',
    arabicTitle: 'Ibn Kathir (Abridged)',
    arabicAuthor: 'Hafiz Ibn Kathir (Tafsir al-Qur\'an al-Azim, abridged)',
    quranComResourceId: 169,
    alQuranCloudEdition: null,
    isEnglish: true,
  ),
  enMaarif(
    id: 'en_maarif',
    arabicTitle: 'Ma\'arif al-Qur\'an',
    arabicAuthor: 'Mufti Muhammad Shafi',
    quranComResourceId: 168,
    alQuranCloudEdition: null,
    isEnglish: true,
  );

  final String id;
  final String arabicTitle;
  final String arabicAuthor;
  final int? quranComResourceId;
  final String? alQuranCloudEdition;
  final bool isEnglish;

  const DetailedTafsirSource({
    required this.id,
    required this.arabicTitle,
    required this.arabicAuthor,
    required this.quranComResourceId,
    required this.alQuranCloudEdition,
    this.isEnglish = false,
  });

  String get title => arabicTitle;
  String get author => arabicAuthor;

  /// Sources matching the active UI language.
  static List<DetailedTafsirSource> forLanguage() => values
      .where((s) => s.isEnglish == L10n.isEn)
      .toList(growable: false);
}

class WordMeaningItem {
  final LineWord word;
  final String cleanWord;
  final String arabicRoot;
  final String arabicMeaning;
  final String? englishMeaning;
  final String? transliteration;

  const WordMeaningItem({
    required this.word,
    required this.cleanWord,
    required this.arabicRoot,
    required this.arabicMeaning,
    this.englishMeaning,
    this.transliteration,
  });
}

class AyahWordMeaningsResult {
  final String verseKey;
  final List<WordMeaningItem> words;
  final String? ayahVocabularyOverview;
  final bool isFromOnline;

  const AyahWordMeaningsResult({
    required this.verseKey,
    required this.words,
    this.ayahVocabularyOverview,
    required this.isFromOnline,
  });
}

class TafsirTextResult {
  final String sourceId;
  final String title;
  final String author;
  final String verseKey;
  final String text;
  final bool isCachedOffline;
  final bool isEnglish;

  const TafsirTextResult({
    required this.sourceId,
    required this.title,
    required this.author,
    required this.verseKey,
    required this.text,
    required this.isCachedOffline,
    this.isEnglish = false,
  });
}

class TafsirService {
  TafsirService._();
  static final TafsirService instance = TafsirService._();

  bool _tablesInitialized = false;

  Future<Database> _getDb() async {
    final db = await DatabaseService.instance.database;
    if (!_tablesInitialized) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tafsir_cache (
          source_id TEXT NOT NULL,
          verse_key TEXT NOT NULL,
          content TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          PRIMARY KEY (source_id, verse_key)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS word_gloss_cache (
          verse_key TEXT NOT NULL PRIMARY KEY,
          json_payload TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      _tablesInitialized = true;
    }
    return db;
  }

  /// Fetches Summary Tafsir for [verseKey] using [source].
  Future<TafsirTextResult> getSummaryTafsir(
    String verseKey,
    SummaryTafsirSource source,
  ) async {
    final text = await _fetchOrGetCachedTafsir(
      sourceId: source.id,
      verseKey: verseKey,
      quranComResourceId: source.quranComResourceId,
      alQuranCloudEdition: source.alQuranCloudEdition,
    );
    return TafsirTextResult(
      sourceId: source.id,
      title: source.title,
      author: source.author,
      verseKey: verseKey,
      text: text.content,
      isCachedOffline: text.fromCache,
      isEnglish: source.isEnglish,
    );
  }

  /// Fetches Detailed Tafsir for [verseKey] using [source].
  Future<TafsirTextResult> getDetailedTafsir(
    String verseKey,
    DetailedTafsirSource source,
  ) async {
    final text = await _fetchOrGetCachedTafsir(
      sourceId: source.id,
      verseKey: verseKey,
      quranComResourceId: source.quranComResourceId,
      alQuranCloudEdition: source.alQuranCloudEdition,
    );
    return TafsirTextResult(
      sourceId: source.id,
      title: source.title,
      author: source.author,
      verseKey: verseKey,
      text: text.content,
      isCachedOffline: text.fromCache,
      isEnglish: source.isEnglish,
    );
  }

  /// Builds complete Word-by-Word meaning & vocabulary breakdown for [verseKey].
  Future<AyahWordMeaningsResult> getWordMeaningsForAyah(String verseKey) async {
    final db = await _getDb();
    final lineWords =
        await DatabaseService.instance.getWordsForVerseKey(verseKey);

    // 1. Check cached online word glosses & vocabulary overview
    Map<String, dynamic>? glossPayload;
    bool isOnlineAvailable = false;

    final cachedRows = await db.query(
      'word_gloss_cache',
      where: 'verse_key = ?',
      whereArgs: [verseKey],
      limit: 1,
    );

    if (cachedRows.isNotEmpty) {
      try {
        glossPayload = jsonDecode(cachedRows.first['json_payload'] as String)
            as Map<String, dynamic>;
        isOnlineAvailable = true;
      } catch (_) {}
    }

    if (glossPayload == null) {
      glossPayload = await _fetchOnlineWordGlossPayload(verseKey);
      if (glossPayload != null) {
        isOnlineAvailable = true;
        await db.insert(
          'word_gloss_cache',
          {
            'verse_key': verseKey,
            'json_payload': jsonEncode(glossPayload),
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    final Map<String, dynamic> englishByPos =
        (glossPayload?['en_by_pos'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
    final Map<String, dynamic> translitByPos =
        (glossPayload?['tr_by_pos'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
    final String? vocabOverview = glossPayload?['ar_vocab_overview'] as String?;

    // Extract phrase-level Arabic glosses from the vocabulary overview if present
    final Map<String, String> extractedArabicGlosses =
        _extractInlineArabicWordGlosses(vocabOverview);

    final items = <WordMeaningItem>[];
    for (final w in lineWords) {
      final cleanWord = w.cleanWordUthmani;
      final normalized = ArabicUtils.normalizeForSearch(cleanWord);
      final root = SmartSearchService.extractArabicRoot(normalized);
      final posKey = w.wordNumberInAyah.toString();

      final englishGloss = englishByPos[posKey] as String?;
      final translit = translitByPos[posKey] as String?;

      final arabicMeaning = _resolveArabicWordMeaning(
        cleanUthmani: cleanWord,
        normalizedWord: normalized,
        root: root,
        extractedGlosses: extractedArabicGlosses,
      );

      items.add(
        WordMeaningItem(
          word: w,
          cleanWord: cleanWord,
          arabicRoot: _formatRootDisplay(root),
          arabicMeaning: arabicMeaning,
          englishMeaning: englishGloss,
          transliteration: translit,
        ),
      );
    }

    return AyahWordMeaningsResult(
      verseKey: verseKey,
      words: items,
      ayahVocabularyOverview: vocabOverview,
      isFromOnline: isOnlineAvailable,
    );
  }

  Future<({String content, bool fromCache})> _fetchOrGetCachedTafsir({
    required String sourceId,
    required String verseKey,
    required int? quranComResourceId,
    required String? alQuranCloudEdition,
  }) async {
    final db = await _getDb();
    final rows = await db.query(
      'tafsir_cache',
      where: 'source_id = ? AND verse_key = ?',
      whereArgs: [sourceId, verseKey],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final cachedText = (rows.first['content'] as String).trim();
      if (cachedText.isNotEmpty) {
        return (content: cachedText, fromCache: true);
      }
    }

    String? fetched;
    if (quranComResourceId != null) {
      fetched = await _fetchFromQuranComTafsir(quranComResourceId, verseKey);
    }
    if ((fetched == null || fetched.isEmpty) && alQuranCloudEdition != null) {
      fetched = await _fetchFromAlQuranCloud(alQuranCloudEdition, verseKey);
    }

    if (fetched != null && fetched.trim().isNotEmpty) {
      final cleaned = _cleanHtmlAndFormatting(fetched);
      await db.insert(
        'tafsir_cache',
        {
          'source_id': sourceId,
          'verse_key': verseKey,
          'content': cleaned,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return (content: cleaned, fromCache: false);
    }

    throw const SocketException('Unable to load Tafsir from online service');
  }

  Future<String?> _fetchFromQuranComTafsir(
    int resourceId,
    String verseKey,
  ) async {
    final urls = <String>[
      'https://api.quran.com/api/v4/tafsirs/$resourceId/by_ayah/$verseKey',
      'https://api.qurancdn.com/api/qdc/tafsirs/$resourceId/by_ayah/$verseKey',
    ];

    for (final url in urls) {
      final jsonMap = await _httpGetJson(url);
      if (jsonMap != null) {
        final tafsirObj = jsonMap['tafsir'];
        if (tafsirObj is Map<String, dynamic>) {
          final text = tafsirObj['text'] as String?;
          if (text != null && text.trim().isNotEmpty) {
            return text;
          }
        }
      }
    }
    return null;
  }

  Future<String?> _fetchFromAlQuranCloud(
    String edition,
    String verseKey,
  ) async {
    final url = 'https://api.alquran.cloud/v1/ayah/$verseKey/$edition';
    final jsonMap = await _httpGetJson(url);
    if (jsonMap != null && jsonMap['code'] == 200) {
      final data = jsonMap['data'];
      if (data is Map<String, dynamic>) {
        final text = data['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          return text;
        }
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchOnlineWordGlossPayload(
    String verseKey,
  ) async {
    final enByPos = <String, String>{};
    final trByPos = <String, String>{};
    String? arVocabOverview;

    // Fetch Quran.com v4 word-by-word glosses and AlQuran.cloud vocabulary edition in parallel
    final results = await Future.wait<Object?>([
      _httpGetJson(
        'https://api.quran.com/api/v4/verses/by_key/$verseKey?language=${L10n.isUr ? 'ur' : 'en'}&words=true&word_fields=text_uthmani,location',
      ),
      _fetchFromAlQuranCloud('ar.miqbas', verseKey),
      _fetchFromAlQuranCloud('ar.jalalayn', verseKey),
    ]);

    final quranComJson = results[0] as Map<String, dynamic>?;
    final miqbasText = results[1] as String?;
    final jalalaynText = results[2] as String?;

    if (quranComJson != null) {
      final verse = quranComJson['verse'];
      if (verse is Map<String, dynamic>) {
        final words = verse['words'];
        if (words is List) {
          for (final w in words) {
            if (w is Map<String, dynamic>) {
              final charType = w['char_type_name'] as String?;
              if (charType == 'end') continue;
              final pos = w['position']?.toString();
              if (pos == null) continue;
              final trMap = w['translation'];
              if (trMap is Map<String, dynamic>) {
                final t = trMap['text'] as String?;
                if (t != null && t.trim().isNotEmpty) {
                  enByPos[pos] = t.trim();
                }
              }
              final translitMap = w['transliteration'];
              if (translitMap is Map<String, dynamic>) {
                final tl = translitMap['text'] as String?;
                if (tl != null && tl.trim().isNotEmpty) {
                  trByPos[pos] = tl.trim();
                }
              }
            }
          }
        }
      }
    }

    if (miqbasText != null && miqbasText.trim().isNotEmpty) {
      arVocabOverview = _cleanHtmlAndFormatting(miqbasText);
    } else if (jalalaynText != null && jalalaynText.trim().isNotEmpty) {
      arVocabOverview = _cleanHtmlAndFormatting(jalalaynText);
    }

    if (enByPos.isEmpty && arVocabOverview == null) {
      return null;
    }

    return <String, dynamic>{
      'en_by_pos': enByPos,
      'tr_by_pos': trByPos,
      'ar_vocab_overview': arVocabOverview,
    };
  }

  Future<Map<String, dynamic>?> _httpGetJson(String url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.parse(url);
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final resp = await req.close().timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (_) {
      // Ignore network errors and allow fallback
    } finally {
      client.close(force: true);
    }
    return null;
  }

  static String _cleanHtmlAndFormatting(String raw) {
    var s = raw
        // Remove footnote sup tags and their content e.g. <sup foot_note=...>1</sup>
        .replaceAll(RegExp(r'<sup[^>]*>.*?</sup>', dotAll: true), '')
        // Replace paragraph and break tags with newlines
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n• ')
        .replaceAll(RegExp(r'</(ul|ol|blockquote)\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<h[1-6][^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</h[1-6]\s*>', caseSensitive: false), '\n')
        // Strip remaining HTML tags
        .replaceAll(RegExp(r'<[^>]+>'), '')
        // Decode common HTML entities
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&rsquo;', '\u2019')
        .replaceAll('&lsquo;', '\u2018')
        .replaceAll('&ldquo;', '\u201C')
        .replaceAll('&rdquo;', '\u201D')
        .replaceAll('&#x27;', "'");

    // Normalize multiple blank lines
    s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }

  static Map<String, String> _extractInlineArabicWordGlosses(String? overview) {
    final result = <String, String>{};
    if (overview == null || overview.isEmpty) return result;

    // Match parenthetical Quranic expressions like (كلمـة) تفسيرها or {كلمة} تفسيرها
    final regex = RegExp(r'[\(\{﴿]([^\)\}﴾]{1,35})[\)\}﴾]\s*([^\(\{﴿\n]{2,110})');
    for (final m in regex.allMatches(overview)) {
      final phrase = m.group(1)?.trim() ?? '';
      final gloss = m.group(2)?.trim() ?? '';
      if (phrase.isNotEmpty && gloss.isNotEmpty) {
        final normPhrase = ArabicUtils.normalizeForSearch(phrase);
        for (final token in normPhrase.split(' ')) {
          final t = token.trim();
          if (t.length >= 2 && !result.containsKey(t)) {
            result[t] = gloss.replaceAll(RegExp(r'^[،:.\-\s]+|[،:.\-\s]+$'), '');
          }
        }
      }
    }
    return result;
  }

  static String _formatRootDisplay(String root) {
    if (root.length == 3) {
      return '${root[0]} - ${root[1]} - ${root[2]}';
    }
    if (root.length == 4) {
      return '${root[0]} - ${root[1]} - ${root[2]} - ${root[3]}';
    }
    return root;
  }

  static String _resolveArabicWordMeaning({
    required String cleanUthmani,
    required String normalizedWord,
    required String root,
    required Map<String, String> extractedGlosses,
  }) {
    // 1. Direct normalized word match in curated Quranic lexicon
    final direct = _curatedWordMeanings[normalizedWord];
    if (direct != null) return direct;

    // Strip common prefixes (و، ف، ب، ل، ك، ال) and check curated word meanings
    for (final prefix in const ['وال', 'فال', 'بال', 'كال', 'لل', 'ال', 'و', 'ف', 'ب', 'ل']) {
      if (normalizedWord.startsWith(prefix) &&
          normalizedWord.length - prefix.length >= 2) {
        final stripped = normalizedWord.substring(prefix.length);
        final hit = _curatedWordMeanings[stripped];
        if (hit != null) return hit;
      }
    }

    // 2. Match from inline Ayah commentary (تنوير المقباس / الجلالين)
    final inlineHit = extractedGlosses[normalizedWord];
    if (inlineHit != null && inlineHit.isNotEmpty) {
      return inlineHit;
    }

    // 3. Match by triliteral/quadriliteral Arabic root in curated Quranic root lexicon
    final rootHit = _curatedRootMeanings[root];
    if (rootHit != null) return rootHit;

    return 'من الجذر اللغوي (${_formatRootDisplay(root)}) — انظر بيان مفردات الآية والمعنى الإجمالي أدناه';
  }

  static const Map<String, String> _curatedWordMeanings = <String, String>{
    'بسم': 'أبدأ مستعيناً ومتبركاً باسم الله',
    'الله': 'العَلَم على الذات الإلهية المستحق للعبادة وحده',
    'الرحمن': 'ذو الرحمة الواسعة الشاملة لجميع الخلائق',
    'الرحيم': 'الموصل رحمته الخاصة بالمؤمنين في الدنيا والآخرة',
    'الحمد': 'الثناء الكامل بالجميل والكمال مع المحبة والتعظيم',
    'لله': 'استحقاق الحمد والملك لله وحده',
    'رب': 'المالك المتصرف والمربي لجميع العالمين بنعمه',
    'العالمين': 'جميع المخلوقات من الإنس والجن والملائكة وسائر الكائنات',
    'مالك': 'المتصرف المطلق وصاحب الملك التام',
    'يوم': 'زمان الجزاء والحساب',
    'الدين': 'الجزاء والحساب في الآخرة',
    'اياك': 'نخصك وحدك لا شريك لك',
    'نعبد': 'نخضع ونذل ونطيع لك وحدك بالعبادة',
    'نستعين': 'نطلب المعونة والتوفيق منك وحدك على طاعتك وأمورنا',
    'اهدنا': 'دلّنا وأرشدنا وثبّتنا على طريق الحق',
    'الصراط': 'الطريق الواضح المستقيم الذي لا اعوجاج فيه (الإسلام)',
    'المستقيم': 'القويم المعتدل الموصل إلى رضوان الله وجنته',
    'صراط': 'طريق ومنهج',
    'الذين': 'أهل الإيمان والطاعة من النبيين والصديقين والشهداء والصالحين',
    'انعمت': 'تفضّلت عليهم بالهداية والتوفيق والنعمة',
    'عليهم': 'على أولئك المنعم عليهم بالهدى',
    'غير': 'سِوى طريق',
    'المغضوب': 'الذين عرفوا الحق وتركوه فاستحقوا غضب الله',
    'ولا': 'وليس طريق',
    'الضالين': 'التائهين عن الحق الذين عبدوا الله على جهل وضلال',
    'الم': 'حروف مقطعة في أوائل السور للإعجاز والتنبيه على عظمة القرآن',
    'المص': 'حروف مقطعة من إعجاز القرآن الكريم، والله أعلم بمراده بها',
    'الر': 'حروف مقطعة للدلالة على إعجاز القرآن المؤلف من جنس هذه الحروف',
    'طه': 'حرفان من الحروف المقطعة في فواتح السور',
    'يس': 'حرفان من الحروف المقطعة في أوائل السور',
    'حم': 'حرفان من الحروف المقطعة في أوائل السور',
    'ذلك': 'هذا القرآن العظيم الرفيع الشأن',
    'الكتاب': 'القرآن الكريم الجامع للهدى والشريعة',
    'لا': 'نفي قاطع',
    'ريب': 'شك أو تردد، فلا شك أنه تنزيل من عند الله',
    'فيه': 'في هذا القرآن الكريم',
    'هدى': 'بيان ورشاد ونور يخرج من الظلمات إلى النور',
    'للمتقين': 'للذين يتقون عذاب الله بفعل أوامره واجتناب نواهيه',
    'يؤمنون': 'يصدقون تصديقاً جازماً مع الإقرار والعمل',
    'بالغيب': 'بما غاب عن الحواس مما أخبر الله به كالملائكة والبعث والجنة والنار',
    'ويقيمون': 'يؤدونها تامة بأركانها وشروطها وخشوعها في أوقاتها',
    'الصلاه': 'العبادة المفروضة ذات الأقوال والأفعال المخصوصة تعظيماً لله',
    'ومما': 'ومن الذي أعطيناهم وتفضلنا به عليهم',
    'رزقناهم': 'أعطيناهم من الأموال والنعم',
    'ينفقون': 'يتصدقون ويخرجون الزكاة والنفقة في وجوه الخير',
    'المفلحون': 'الفائزون بمطلوبهم والناجون منرهوبهم في الدنيا والآخرة',
    'الصمد': 'السيد الكامل الذي تقصده الخلائق كلها في حوائجها وهو الغني عنهم',
    'كفوا': 'مكافئاً أو مماثلاً أو نظيراً',
    'الفلق': 'الصبح حين ينفلق عن ظلمة الليل، أو كل ما انفلق عن خلق الله',
    'غاسق': 'الليل المظلم إذا دخل واشتد ظلامه',
    'وقب': 'دخل ظلامه وانتشر',
    'النفاثات': 'السواحر اللاتي ينفثن في عقد الخيوط',
    'العقد': 'ما يعقدنه من الخيوط للسحر',
    'الوسواس': 'الشيطان الذي يلقي الوسوسة في الصدور خفية',
    'الخناس': 'الذي يتأخر ويختفي إذا ذكر العبد ربه',
  };

  static const Map<String, String> _curatedRootMeanings = <String, String>{
    'رحم': 'يدل على الرقة والعطف والمغفرة والإحسان والنعمة الواسعة',
    'حمد': 'يدل على الثناء بالجميل والرضا والشكر لله تعالى',
    'عبد': 'يدل على الخضوع والتذلل والطاعة لله رب العالمين',
    'هدي': 'يدل على الإرشاد والدلالة بلطف إلى طريق الحق والرشاد',
    'صراط': 'الطريق الواضح المستقيم الموصل إلى الغاية',
    'صلو': 'الدعاء والعبادة والتعظيم والصلة بين العبد وربه',
    'زكو': 'النماء والطهارة والبركة وإخراج حق المال',
    'صوم': 'الإمساك والكف عن المفطرات تقرباً إلى الله',
    'حجج': 'القصد إلى بيت الله الحرام لأداء المناسك، أو البرهان الساطع',
    'امن': 'التصديق الجازم والطمأنينة والسكينة وزوال الخوف',
    'كفر': 'الستر والجحود والتكذيب بآيات الله أو نعمه',
    'نفق': 'إخراج المال في سبيل الله، أو النفاق بإظهار خلاف الباطن',
    'رزق': 'العطاء والإنعام وما ينتفع به الحي من فضل الله',
    'علم': 'إدراك حقيقة الشيء واليقين والمعرفة الراسخة',
    'حكم': 'إتقان الأمور ووضع الشيء في موضعه والقضاء بالعدل (الحكمة والحكم)',
    'خلق': 'الإيجاد والإنشاء على غير مثال سابق والتقدير المتقن',
    'فلح': 'الفوز والظفر بالخير والبقاء في النعيم',
    'وقي': 'التقوى: صيانة النفس بطاعة الله واجتناب معاصيه',
    'ذكر': 'استحضار القلب واللسان لعظمة الله والاتعاظ بآياته',
    'شكر': 'الاعتراف بنعمة المنعم والثناء عليه وصرفها في مرضاته',
    'صبر': 'حبس النفس على طاعة الله وعن معصيته وعلى أقداره',
    'توب': 'الرجوع إلى الله والندم على الذنب والعزم على تركه',
    'غفر': 'ستر الذنب والتجاوز عنه ومحو أثره',
    'عدل': 'الإنصاف والاستقامة وإعطاء كل ذي حق حقه',
    'ظلم': 'وضع الشيء في غير موضعه ومجاوزة الحق والاعتداء',
    'صدق': 'مطابقة القول والعمل للحق والوفاء بالعهد',
    'كذب': 'الإخبار بخلاف الواقع والافتراء',
    'جنن': 'البساتين الملتفة الأشجار (الجنة دار النعيم المقيم)',
    'نور': 'الضياء والبيان والهدى الذي يبدد الظلمات',
    'قلب': 'الفؤاد ومحل العقل والإيمان والنية في الإنسان',
    'نفس': 'الروح والذات الإنسانية',
    'سما': 'العلو والرفعة (السماوات العلى)',
    'ارض': 'الأرض الممهدة لمعاش الخلائق',
    'ملك': 'السلطان والقدرة والتصرف التام أو الملائكة الكرام',
    'رسل': 'البعث والتوجيه بالرسالة الإلهية لتبليغ الوحي',
    'نبأ': 'الخبر العظيم ذو الشأن والنبوة',
    'بعث': 'الإحياء والنشر بعد الموت ليوم الحساب',
    'حشر': 'الجمع والسوق إلى موقف الحساب يوم القيامة',
    'حسب': 'العد والإحصاء والمحاسبة أو الكفاية (حسبي الله)',
    'شفء': 'البرء والعافية من السقم والمرض للقلوب والأبدان',
    'فقه': 'الفهم الدقيق العميق لمعاني الكلام والدين',
    'بصر': 'الرؤية والإدراك البصري أو البصيرة القلبية',
    'سمع': 'إدراك المسموعات والاستجابة والقبول',
  };
}
