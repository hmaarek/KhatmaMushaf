import 'dart:math' as math;

import '../models/mushaf_models.dart';
import '../utils/arabic_utils.dart';
import 'database_service.dart';

/// Categories of smart search matches, ordered by priority.
enum SearchMatchCategory {
  direct(
    arabicLabel: 'تطابق مباشر',
    shortBadge: 'مطابقة مباشرة',
  ),
  root(
    arabicLabel: 'بالجذر والاشتقاقات',
    shortBadge: 'مشتق من الجذر',
  ),
  approximate(
    arabicLabel: 'تطابق تقريبي',
    shortBadge: 'تطابق جزئي / تقريبي',
  ),
  synonymTopic(
    arabicLabel: 'مرادفات ومواضيع',
    shortBadge: 'مرادف / موضوع ذو صلة',
  );

  final String arabicLabel;
  final String shortBadge;

  const SearchMatchCategory({
    required this.arabicLabel,
    required this.shortBadge,
  });
}

/// A single ranked Ayah match returned by [SmartSearchService].
class SmartSearchResultItem {
  final AyahRecord ayah;
  final SearchMatchCategory category;
  final double score;

  /// Normalized surface words in the Ayah that triggered this match
  /// (used for highlighting inside the Uthmani Ayah text).
  final List<String> matchedCleanWords;

  /// Human-readable reason badge (e.g. "الجذر: غ-ف-ر (غفور)" or "مرادف: الفردوس").
  final String matchReasonLabel;

  const SmartSearchResultItem({
    required this.ayah,
    required this.category,
    required this.score,
    required this.matchedCleanWords,
    required this.matchReasonLabel,
  });
}

/// Complete response for a smart Quran search query.
class SmartSearchResponse {
  final String rawQuery;
  final String normalizedQuery;

  /// Primary extracted Arabic roots for the query words (e.g. ["غفر"]).
  final List<String> extractedRoots;

  /// Derived Quranic words sharing the extracted root(s), sorted by frequency.
  final Map<String, int> rootDerivativesCounts;

  /// Related synonym/topic terms triggered by the query.
  final List<String> relatedTopicTerms;

  /// Primary results (Direct + Root + Approximate), sorted by relevance score.
  final List<SmartSearchResultItem> primaryResults;

  /// Synonym & Topic results, grouped separately as requested.
  final List<SmartSearchResultItem> synonymTopicResults;

  const SmartSearchResponse({
    required this.rawQuery,
    required this.normalizedQuery,
    required this.extractedRoots,
    required this.rootDerivativesCounts,
    required this.relatedTopicTerms,
    required this.primaryResults,
    required this.synonymTopicResults,
  });

  bool get isEmpty => primaryResults.isEmpty && synonymTopicResults.isEmpty;

  int get totalCount => primaryResults.length + synonymTopicResults.length;

  List<SmartSearchResultItem> byCategory(SearchMatchCategory category) {
    if (category == SearchMatchCategory.synonymTopic) {
      return synonymTopicResults;
    }
    return primaryResults
        .where((item) => item.category == category)
        .toList(growable: false);
  }
}

class _IndexedAyah {
  final AyahRecord record;
  final String textClean;
  final String textImlai;
  final List<String> cleanWords;
  final List<String> imlaiWords;
  final List<String> wordRoots;

  const _IndexedAyah({
    required this.record,
    required this.textClean,
    required this.textImlai,
    required this.cleanWords,
    required this.imlaiWords,
    required this.wordRoots,
  });
}

/// High-performance offline Smart Quran Search Engine combining:
/// 1. Pre-indexed in-memory Quranic word, Imla'i (modern spelling), and root tables
/// 2. Live Arabic morphological stemmer & root extractor (Khoja/ISRI + Quranic irregular lexicon)
/// 3. Multi-word relevance scoring & fuzzy edit-distance matching
/// 4. Quranic Synonym & Thematic Thesaurus (grouped separately)
class SmartSearchService {
  SmartSearchService._();
  static final SmartSearchService instance = SmartSearchService._();

  bool _isIndexed = false;
  Future<void>? _indexingFuture;

  final List<_IndexedAyah> _indexedAyahs = <_IndexedAyah>[];

  /// Maps 3/4-letter root -> list of Ayah indices (0..6235)
  final Map<String, Set<int>> _rootToAyahIndices = <String, Set<int>>{};

  /// Maps 3/4-letter root -> map of surface clean word -> count in Quran
  final Map<String, Map<String, int>> _rootToSurfaceWords =
      <String, Map<String, int>>{};

  /// Maps normalized or Imla'i word -> list of Ayah indices (0..6235)
  final Map<String, Set<int>> _wordToAyahIndices = <String, Set<int>>{};

  /// Ensures all 6,236 Ayahs are indexed in memory for sub-10ms smart search.
  Future<void> ensureIndexed() async {
    if (_isIndexed) return;
    if (_indexingFuture != null) {
      await _indexingFuture;
      return;
    }
    _indexingFuture = _buildInMemoryIndex();
    await _indexingFuture;
  }

  Future<void> _buildInMemoryIndex() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery('''
      SELECT a.*, s.name_arabic AS surah_name_arabic, s.name_english AS surah_name_english
      FROM ayahs a
      JOIN surahs s ON s.id = a.surah_id
      ORDER BY a.id ASC
    ''');

    _indexedAyahs.clear();
    _rootToAyahIndices.clear();
    _rootToSurfaceWords.clear();
    _wordToAyahIndices.clear();

    for (int idx = 0; idx < rows.length; idx++) {
      final ayah = AyahRecord.fromMap(rows[idx]);
      final clean = ayah.textClean.trim();
      final cleanWords = clean
          .split(' ')
          .where((w) => w.isNotEmpty)
          .toList(growable: false);

      final imlaiWords = <String>[];
      final roots = <String>[];

      for (final w in cleanWords) {
        final imlai = toModernImlaiWord(w);
        final root = extractArabicRoot(imlai);
        imlaiWords.add(imlai);
        roots.add(root);

        (_wordToAyahIndices[w] ??= <int>{}).add(idx);
        if (imlai != w) {
          (_wordToAyahIndices[imlai] ??= <int>{}).add(idx);
        }

        if (root.length >= 3) {
          (_rootToAyahIndices[root] ??= <int>{}).add(idx);
          final surfaceMap =
              (_rootToSurfaceWords[root] ??= <String, int>{});
          surfaceMap[w] = (surfaceMap[w] ?? 0) + 1;
        }
      }

      _indexedAyahs.add(
        _IndexedAyah(
          record: ayah,
          textClean: clean,
          textImlai: imlaiWords.join(' '),
          cleanWords: cleanWords,
          imlaiWords: imlaiWords,
          wordRoots: roots,
        ),
      );
    }

    _isIndexed = true;
  }

  /// Executes a multi-layered smart search across all 6,236 Ayahs.
  Future<SmartSearchResponse> search(
    String rawQuery, {
    int maxPrimaryResults = 150,
    int maxSynonymResults = 80,
  }) async {
    await ensureIndexed();

    final normalizedQuery = normalizeSmartQuery(rawQuery);
    if (normalizedQuery.isEmpty) {
      return SmartSearchResponse(
        rawQuery: rawQuery,
        normalizedQuery: '',
        extractedRoots: const <String>[],
        rootDerivativesCounts: const <String, int>{},
        relatedTopicTerms: const <String>[],
        primaryResults: const <SmartSearchResultItem>[],
        synonymTopicResults: const <SmartSearchResultItem>[],
      );
    }

    final rawTokens = normalizedQuery
        .split(' ')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList(growable: false);

    // Filter out pure Arabic stop words only when there are other content words
    final contentTokens = rawTokens
        .where((t) => !_arabicStopWords.contains(t))
        .toList(growable: false);
    final queryTokens = contentTokens.isNotEmpty ? contentTokens : rawTokens;

    final queryImlaiTokens =
        queryTokens.map(toModernImlaiWord).toList(growable: false);
    final queryStems =
        queryImlaiTokens.map(stripClitics).toList(growable: false);

    // Extract roots for each content token
    final queryRoots = <String>[];
    for (final token in queryImlaiTokens) {
      if (!_arabicStopWords.contains(token)) {
        final root = extractArabicRoot(token);
        if (root.length >= 3 && !queryRoots.contains(root)) {
          queryRoots.add(root);
        }
      }
    }

    // Collect derivative word counts for the extracted roots
    final derivativesCounts = <String, int>{};
    for (final root in queryRoots) {
      final surfaceMap = _rootToSurfaceWords[root];
      if (surfaceMap != null) {
        for (final entry in surfaceMap.entries) {
          derivativesCounts[entry.key] =
              (derivativesCounts[entry.key] ?? 0) + entry.value;
        }
      }
    }
    final sortedDerivativesEntries = derivativesCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topDerivativesMap = <String, int>{
      for (final e in sortedDerivativesEntries.take(18)) e.key: e.value,
    };

    // Expand synonyms and thematic terms for the query
    final synonymTerms = _expandSynonymsAndTopics(
      normalizedQuery,
      queryImlaiTokens,
      queryRoots,
    );

    final primaryMatches = <SmartSearchResultItem>[];
    final synonymMatches = <SmartSearchResultItem>[];
    final matchedPrimaryAyahIds = <int>{};

    final fullImlaiPhrase = queryImlaiTokens.join(' ');
    final isSingleWordQuery = queryTokens.length == 1;

    for (int i = 0; i < _indexedAyahs.length; i++) {
      final item = _indexedAyahs[i];

      // 1. Check Direct / Exact Phrase or All-Words Match
      final directEval = _evaluateDirectMatch(
        item: item,
        normalizedQuery: normalizedQuery,
        fullImlaiPhrase: fullImlaiPhrase,
        queryTokens: queryTokens,
        queryImlaiTokens: queryImlaiTokens,
        queryStems: queryStems,
      );

      if (directEval != null) {
        primaryMatches.add(
          SmartSearchResultItem(
            ayah: item.record,
            category: SearchMatchCategory.direct,
            score: directEval.score,
            matchedCleanWords: directEval.matchedWords,
            matchReasonLabel: directEval.reason,
          ),
        );
        matchedPrimaryAyahIds.add(item.record.id);
        continue;
      }

      // 2. Check Root & Morphological Derivative Match
      if (queryRoots.isNotEmpty) {
        final rootEval = _evaluateRootMatch(
          item: item,
          queryRoots: queryRoots,
          isSingleWordQuery: isSingleWordQuery,
        );
        if (rootEval != null) {
          primaryMatches.add(
            SmartSearchResultItem(
              ayah: item.record,
              category: SearchMatchCategory.root,
              score: rootEval.score,
              matchedCleanWords: rootEval.matchedWords,
              matchReasonLabel: rootEval.reason,
            ),
          );
          matchedPrimaryAyahIds.add(item.record.id);
          continue;
        }
      }

      // 3. Check Approximate / Partial Phrase or Typo-Tolerant Match
      final approxEval = _evaluateApproximateMatch(
        item: item,
        queryImlaiTokens: queryImlaiTokens,
        queryStems: queryStems,
        queryRoots: queryRoots,
      );
      if (approxEval != null) {
        primaryMatches.add(
          SmartSearchResultItem(
            ayah: item.record,
            category: SearchMatchCategory.approximate,
            score: approxEval.score,
            matchedCleanWords: approxEval.matchedWords,
            matchReasonLabel: approxEval.reason,
          ),
        );
        matchedPrimaryAyahIds.add(item.record.id);
        continue;
      }

      // 4. Check Synonym & Topic Match (grouped separately)
      if (synonymTerms.isNotEmpty) {
        final synEval = _evaluateSynonymTopicMatch(
          item: item,
          synonymTerms: synonymTerms,
        );
        if (synEval != null) {
          synonymMatches.add(
            SmartSearchResultItem(
              ayah: item.record,
              category: SearchMatchCategory.synonymTopic,
              score: synEval.score,
              matchedCleanWords: synEval.matchedWords,
              matchReasonLabel: synEval.reason,
            ),
          );
        }
      }
    }

    // Sort primary matches by category priority and descending score, then Mushaf order
    primaryMatches.sort((a, b) {
      final catCmp = a.category.index.compareTo(b.category.index);
      if (catCmp != 0) return catCmp;
      final scoreCmp = b.score.compareTo(a.score);
      if (scoreCmp != 0) return scoreCmp;
      return a.ayah.id.compareTo(b.ayah.id);
    });

    synonymMatches.sort((a, b) {
      final scoreCmp = b.score.compareTo(a.score);
      if (scoreCmp != 0) return scoreCmp;
      return a.ayah.id.compareTo(b.ayah.id);
    });

    return SmartSearchResponse(
      rawQuery: rawQuery,
      normalizedQuery: normalizedQuery,
      extractedRoots: queryRoots,
      rootDerivativesCounts: topDerivativesMap,
      relatedTopicTerms: synonymTerms.take(12).toList(growable: false),
      primaryResults:
          primaryMatches.take(maxPrimaryResults).toList(growable: false),
      synonymTopicResults:
          synonymMatches.take(maxSynonymResults).toList(growable: false),
    );
  }

  // -------------------- Match Evaluators --------------------

  ({double score, List<String> matchedWords, String reason})?
      _evaluateDirectMatch({
    required _IndexedAyah item,
    required String normalizedQuery,
    required String fullImlaiPhrase,
    required List<String> queryTokens,
    required List<String> queryImlaiTokens,
    required List<String> queryStems,
  }) {
    // Check exact contiguous phrase in clean or Imla'i text
    final hasExactCleanPhrase = item.textClean.contains(normalizedQuery);
    final hasExactImlaiPhrase =
        fullImlaiPhrase.isNotEmpty && item.textImlai.contains(fullImlaiPhrase);

    final matchedSurfaceWords = <String>[];
    int exactWordMatches = 0;
    int stemOrSubMatches = 0;

    for (int qIdx = 0; qIdx < queryTokens.length; qIdx++) {
      final qRaw = queryTokens[qIdx];
      final qImlai = queryImlaiTokens[qIdx];
      final qStem = queryStems[qIdx];

      bool foundThisToken = false;
      for (int wIdx = 0; wIdx < item.cleanWords.length; wIdx++) {
        final wClean = item.cleanWords[wIdx];
        final wImlai = item.imlaiWords[wIdx];
        final wStem = stripClitics(wImlai);

        if (wClean == qRaw || wImlai == qImlai) {
          exactWordMatches++;
          if (!matchedSurfaceWords.contains(wClean)) {
            matchedSurfaceWords.add(wClean);
          }
          foundThisToken = true;
          break;
        } else if ((qStem.length >= 3 && wStem == qStem) ||
            (qImlai.length >= 3 &&
                (wClean.contains(qRaw) || wImlai.contains(qImlai)))) {
          stemOrSubMatches++;
          if (!matchedSurfaceWords.contains(wClean)) {
            matchedSurfaceWords.add(wClean);
          }
          foundThisToken = true;
          break;
        }
      }

      if (!foundThisToken) {
        // Not all tokens matched directly
        if (hasExactCleanPhrase || hasExactImlaiPhrase) {
          return (
            score: 950.0,
            matchedWords: matchedSurfaceWords,
            reason: 'مطابقة تامة للعبارة',
          );
        }
        return null;
      }
    }

    double score = 700.0 + (exactWordMatches * 40.0) + (stemOrSubMatches * 20.0);
    String reason = 'مطابقة مباشرة للكلمات';
    if (hasExactCleanPhrase || hasExactImlaiPhrase) {
      score += 300.0;
      reason = queryTokens.length > 1
          ? 'مطابقة تامة للعبارة'
          : 'مطابقة مباشرة للكلمة';
    } else if (exactWordMatches == queryTokens.length) {
      score += 120.0;
      reason = 'مطابقة تامة للكلمات';
    }

    return (
      score: score,
      matchedWords: matchedSurfaceWords,
      reason: reason,
    );
  }

  ({double score, List<String> matchedWords, String reason})?
      _evaluateRootMatch({
    required _IndexedAyah item,
    required List<String> queryRoots,
    required bool isSingleWordQuery,
  }) {
    final matchedSurfaceWords = <String>[];
    final matchedDerivatives = <String>[];
    int matchedRootCount = 0;

    for (final qRoot in queryRoots) {
      bool foundForThisRoot = false;
      for (int wIdx = 0; wIdx < item.wordRoots.length; wIdx++) {
        if (item.wordRoots[wIdx] == qRoot) {
          foundForThisRoot = true;
          final surface = item.cleanWords[wIdx];
          if (!matchedSurfaceWords.contains(surface)) {
            matchedSurfaceWords.add(surface);
          }
          if (!matchedDerivatives.contains(surface)) {
            matchedDerivatives.add(surface);
          }
        }
      }
      if (foundForThisRoot) {
        matchedRootCount++;
      }
    }

    if (isSingleWordQuery) {
      if (matchedRootCount == 0) return null;
      final rootFormatted = formatRootLetters(queryRoots.first);
      final derivSample = matchedDerivatives.take(2).join('، ');
      return (
        score: 500.0 + (matchedSurfaceWords.length * 15.0),
        matchedWords: matchedSurfaceWords,
        reason: 'الجذر [$rootFormatted] • $derivSample',
      );
    } else {
      // Multi-word query: require all query roots to be present in the Ayah for a pure Root match
      if (matchedRootCount < queryRoots.length) return null;
      final rootsFormatted = queryRoots.map(formatRootLetters).join(' + ');
      return (
        score: 520.0 + (matchedRootCount * 30.0),
        matchedWords: matchedSurfaceWords,
        reason: 'تطابق الجذور [$rootsFormatted]',
      );
    }
  }

  ({double score, List<String> matchedWords, String reason})?
      _evaluateApproximateMatch({
    required _IndexedAyah item,
    required List<String> queryImlaiTokens,
    required List<String> queryStems,
    required List<String> queryRoots,
  }) {
    final matchedSurfaceWords = <String>[];

    // Case A: Single-word typo tolerance (edit distance == 1 on words >= 4 chars)
    if (queryImlaiTokens.length == 1) {
      final target = queryStems.first;
      if (target.length < 4) return null;

      for (int wIdx = 0; wIdx < item.imlaiWords.length; wIdx++) {
        final candidate = stripClitics(item.imlaiWords[wIdx]);
        if ((candidate.length - target.length).abs() <= 1 &&
            candidate.length >= 4 &&
            _isEditDistanceAtMostOne(target, candidate)) {
          final surface = item.cleanWords[wIdx];
          matchedSurfaceWords.add(surface);
          return (
            score: 310.0,
            matchedWords: matchedSurfaceWords,
            reason: 'تقارب إملائي ($surface)',
          );
        }
      }
      return null;
    }

    // Case B: Multi-word partial match (at least 60% of words or roots match, minimum 1 word if 2-word query with long word, or >=2 words for 3+ words)
    int matchedTokenCount = 0;
    for (int qIdx = 0; qIdx < queryImlaiTokens.length; qIdx++) {
      final qImlai = queryImlaiTokens[qIdx];
      final qStem = queryStems[qIdx];
      final qRoot = qIdx < queryRoots.length ? queryRoots[qIdx] : '';

      bool tokenMatched = false;
      for (int wIdx = 0; wIdx < item.imlaiWords.length; wIdx++) {
        final wClean = item.cleanWords[wIdx];
        final wImlai = item.imlaiWords[wIdx];
        final wStem = stripClitics(wImlai);
        final wRoot = item.wordRoots[wIdx];

        if (wImlai == qImlai ||
            (qStem.length >= 3 && wStem == qStem) ||
            (qRoot.length >= 3 && wRoot == qRoot) ||
            (qStem.length >= 4 &&
                (wStem.length - qStem.length).abs() <= 1 &&
                _isEditDistanceAtMostOne(qStem, wStem))) {
          tokenMatched = true;
          if (!matchedSurfaceWords.contains(wClean)) {
            matchedSurfaceWords.add(wClean);
          }
          break;
        }
      }
      if (tokenMatched) matchedTokenCount++;
    }

    final totalTokens = queryImlaiTokens.length;
    final minRequired = totalTokens == 2
        ? 1
        : math.max(2, (totalTokens * 0.6).ceil());

    if (matchedTokenCount < minRequired) return null;
    // For 2-word queries where only 1 word matched, require that matched word to be specific (>= 4 chars)
    if (totalTokens == 2 &&
        matchedTokenCount == 1 &&
        matchedSurfaceWords.first.length < 5) {
      return null;
    }

    final ratio = matchedTokenCount / totalTokens;
    return (
      score: 300.0 + (ratio * 150.0) + (matchedTokenCount * 20.0),
      matchedWords: matchedSurfaceWords,
      reason:
          'تطابق جزئي (${ArabicUtils.toArabicDigits(matchedTokenCount)} من ${ArabicUtils.toArabicDigits(totalTokens)} كلمات)',
    );
  }

  ({double score, List<String> matchedWords, String reason})?
      _evaluateSynonymTopicMatch({
    required _IndexedAyah item,
    required List<String> synonymTerms,
  }) {
    final matchedSurfaceWords = <String>[];
    final matchedTopics = <String>[];

    for (final syn in synonymTerms) {
      final synImlai = toModernImlaiWord(syn);
      final synRoot = extractArabicRoot(synImlai);

      for (int wIdx = 0; wIdx < item.cleanWords.length; wIdx++) {
        final wClean = item.cleanWords[wIdx];
        final wImlai = item.imlaiWords[wIdx];
        final wStem = stripClitics(wImlai);
        final wRoot = item.wordRoots[wIdx];

        if (wClean == syn ||
            wImlai == synImlai ||
            wStem == synImlai ||
            (synRoot.length >= 3 && wRoot == synRoot && wStem.contains(synImlai.substring(0, math.min(2, synImlai.length))))) {
          if (!matchedSurfaceWords.contains(wClean)) {
            matchedSurfaceWords.add(wClean);
          }
          if (!matchedTopics.contains(syn)) {
            matchedTopics.add(syn);
          }
        }
      }
    }

    if (matchedSurfaceWords.isEmpty) return null;

    final sampleTopics = matchedTopics.take(2).join('، ');
    return (
      score: 200.0 + (matchedTopics.length * 25.0),
      matchedWords: matchedSurfaceWords,
      reason: 'مرادف / موضوع: $sampleTopics',
    );
  }

  // -------------------- Arabic Normalization, Imla'i & Root Engine --------------------

  /// Normalizes user search input (strips diacritics, normalizes Alef/Hamza/Ya/Teh Marbuta).
  static String normalizeSmartQuery(String input) {
    var s = ArabicUtils.normalizeForSearch(input);
    // Normalize standalone or seated hamzas to ease matching
    s = s.replaceAll(RegExp(r'[ؤئ]'), 'ء');
    // Remove punctuation
    s = s.replaceAll(RegExp(r'[^\u0621-\u064A\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// Bridges Uthmani orthography (`الصلوة`, `السموت`, `ابرهيم`) and modern Arabic Imla'i spelling
  /// into a unified canonical Arabic word form.
  static String toModernImlaiWord(String word) {
    var w = ArabicUtils.normalizeForSearch(word);
    if (w.isEmpty) return w;

    // Normalize Teh Marbuta at end of word to Heh for consistent matching
    if (w.endsWith('ة')) {
      w = '${w.substring(0, w.length - 1)}ه';
    }

    // Direct lookup in Uthmani-to-Imla'i bridge map
    final direct = _uthmaniToImlaiMap[w];
    if (direct != null) return direct;

    // Strip common prefixes (و، ف، ب، ك، ل) and check lookup again
    if (w.length > 3 && 'وفبكل'.contains(w[0])) {
      final prefix = w[0];
      final rest = w.substring(1);
      final mappedRest = _uthmaniToImlaiMap[rest];
      if (mappedRest != null) return '$prefix$mappedRest';
    }

    // Handle Uthmani Waw-Alef replacement patterns (صلوة -> صلاه, زكوة -> زكاه, حيوة -> حياه, غدوة -> غداه, مشكوة -> مشكاه)
    w = w
        .replaceAll('صلوه', 'صلاه')
        .replaceAll('زكوه', 'زكاه')
        .replaceAll('حيوه', 'حياه')
        .replaceAll('غدوه', 'غداه')
        .replaceAll('مشكوه', 'مشكاه')
        .replaceAll('نجوه', 'نجاه')
        .replaceAll('سموت', 'سماوات')
        .replaceAll('سموات', 'سماوات')
        .replaceAll('الرحمن', 'الرحمان')
        .replaceAll('رحمن', 'رحمان')
        .replaceAll('ابرهيم', 'ابراهيم')
        .replaceAll('اسمعيل', 'اسماعيل')
        .replaceAll('اسحق', 'اسحاق')
        .replaceAll('سليمن', 'سليمان')
        .replaceAll('هرون', 'هارون')
        .replaceAll('قران', 'قرءان')
        .replaceAll('مومن', 'مؤمن')
        .replaceAll('مليكه', 'ملائكه')
        .replaceAll('اوليك', 'اولئك');

    // Unify seated hamzas
    w = w.replaceAll(RegExp(r'[ؤئء]'), 'ا');
    w = w.replaceAll(RegExp(r'ا+'), 'ا');

    return w;
  }

  /// Strips attached Arabic prefixes (clitics, articles) and pronoun/plural suffixes.
  static String stripClitics(String word) {
    var w = word;
    if (w.length <= 3) return w;

    for (final prefix in _prefixes) {
      if (w.startsWith(prefix) && (w.length - prefix.length) >= 3) {
        w = w.substring(prefix.length);
        break;
      }
    }

    for (final suffix in _suffixes) {
      if (w.endsWith(suffix) && (w.length - suffix.length) >= 3) {
        w = w.substring(0, w.length - suffix.length);
        break;
      }
    }

    return w;
  }

  /// Extracts the 3-letter (or 4-letter) Arabic linguistic root for [rawWord]
  /// using a hybrid Quranic irregular lexicon + morphological pattern analyzer.
  static String extractArabicRoot(String rawWord) {
    if (rawWord.isEmpty) return '';
    var w = toModernImlaiWord(rawWord);

    // 1. Check direct word-to-root dictionary first
    final directRoot = _irregularWordToRoot[w];
    if (directRoot != null) return directRoot;

    // 2. Strip prefixes & suffixes and check dictionary again
    var stem = stripClitics(w);
    final stemRoot = _irregularWordToRoot[stem];
    if (stemRoot != null) return stemRoot;

    // Also try stripping a single leading conjunction (و / ف / ب / ل) if still attached
    if (stem.length > 3 && 'وفبكلس'.contains(stem[0])) {
      final afterConj = stem.substring(1);
      final conjRoot = _irregularWordToRoot[afterConj];
      if (conjRoot != null) return conjRoot;
      final afterConjStripped = stripClitics(afterConj);
      final conjStrippedRoot = _irregularWordToRoot[afterConjStripped];
      if (conjStrippedRoot != null) return conjStrippedRoot;
      stem = afterConjStripped;
    }

    if (stem.length <= 3) {
      return _irregularWordToRoot[stem] ?? stem;
    }

    // 3. Strip verbal/nominal prefixes (است، مست، مت، يت، تت، نت، ان، ين، تن، من)
    for (final vPref in _derivationalPrefixes) {
      if (stem.startsWith(vPref) && (stem.length - vPref.length) >= 3) {
        final candidate = stem.substring(vPref.length);
        if (_irregularWordToRoot.containsKey(candidate)) {
          return _irregularWordToRoot[candidate]!;
        }
        stem = candidate;
        break;
      }
    }

    if (stem.length == 3) {
      return _irregularWordToRoot[stem] ?? stem;
    }

    // 4. Apply Arabic Morphological Pattern Reductions (الأوزان الصرفية)
    // Length 6 patterns: استفعل / افعوعل / افعال
    if (stem.length == 6) {
      if (stem.startsWith('است')) {
        return stem.substring(3);
      }
      if (stem.startsWith('ا') && stem[4] == 'ا') {
        // انفعال / افتعال / افعلال -> remove 0, 2, 4 or similar
        if (stem[1] == 'ن') {
          return '${stem[2]}${stem[3]}${stem[5]}';
        }
        if (stem[2] == 'ت') {
          return '${stem[1]}${stem[3]}${stem[5]}';
        }
      }
    }

    // Length 5 patterns:
    // افتعل (0=ا, 2=ت) -> 1,3,4
    // انفعل (0=ا, 1=ن) -> 2,3,4
    // تفاعل (0=ت, 2=ا) -> 1,3,4
    // تفعلل / مفاعل (0=م, 2=ا) -> 1,3,4
    // مفعول (0=م, 3=و) -> 1,2,4
    // تفعيل (0=ت, 3=ي) -> 1,2,4
    // افعال (0=ا, 3=ا) -> 1,2,4
    // فعلان (3=ا, 4=ن) -> 0,1,2
    if (stem.length == 5) {
      if (stem[0] == 'ا' && stem[2] == 'ت') {
        return '${stem[1]}${stem[3]}${stem[4]}';
      }
      if (stem[0] == 'ا' && stem[1] == 'ن') {
        return '${stem[2]}${stem[3]}${stem[4]}';
      }
      if ((stem[0] == 'ت' || stem[0] == 'م' || stem[0] == 'ي') &&
          stem[2] == 'ا') {
        return '${stem[1]}${stem[3]}${stem[4]}';
      }
      if ((stem[0] == 'م' || stem[0] == 'ت' || stem[0] == 'ي') &&
          (stem[3] == 'و' || stem[3] == 'ي' || stem[3] == 'ا')) {
        return '${stem[1]}${stem[2]}${stem[4]}';
      }
      if (stem[0] == 'ا' && stem[3] == 'ا') {
        return '${stem[1]}${stem[2]}${stem[4]}';
      }
      if (stem.endsWith('ان') || stem.endsWith('ين') || stem.endsWith('ون')) {
        return stem.substring(0, 3);
      }
    }

    // Length 4 patterns:
    // فاعل (1=ا) -> 0,2,3
    // فعال / فعيل / فعول (2=ا/ي/و) -> 0,1,3
    // مفعل / تفعل / يفعل / نفعل / افعل (0=م/ت/ي/ن/ا) -> 1,2,3
    // فعله / فعلي (3=ه/ي) -> 0,1,2
    if (stem.length == 4) {
      if (stem[1] == 'ا' || stem[1] == 'و' || stem[1] == 'ي') {
        return '${stem[0]}${stem[2]}${stem[3]}';
      }
      if (stem[2] == 'ا' || stem[2] == 'ي' || stem[2] == 'و') {
        return '${stem[0]}${stem[1]}${stem[3]}';
      }
      if ('متينأا'.contains(stem[0])) {
        return stem.substring(1);
      }
      if ('هيكت'.contains(stem[3])) {
        return stem.substring(0, 3);
      }
    }

    // Fallback: strip long vowels (ا و ي) if length > 3
    if (stem.length > 3) {
      final buf = StringBuffer();
      for (int i = 0; i < stem.length; i++) {
        final ch = stem[i];
        if (!'اوي'.contains(ch) || (buf.length + (stem.length - i)) <= 3) {
          buf.write(ch);
        }
        if (buf.length == 3) break;
      }
      final reduced = buf.toString();
      if (reduced.length == 3) {
        return _irregularWordToRoot[reduced] ?? reduced;
      }
    }

    return stem.length > 4 ? stem.substring(0, 3) : stem;
  }

  /// Formats a root like `"غفر"` as `"غ - ف - ر"`.
  static String formatRootLetters(String root) {
    return root.split('').join(' - ');
  }

  static bool _isEditDistanceAtMostOne(String a, String b) {
    if (a == b) return true;
    final lenA = a.length;
    final lenB = b.length;
    if ((lenA - lenB).abs() > 1) return false;

    int i = 0;
    int j = 0;
    int edits = 0;

    while (i < lenA && j < lenB) {
      if (a[i] == b[j]) {
        i++;
        j++;
      } else {
        edits++;
        if (edits > 1) return false;
        if (lenA > lenB) {
          i++;
        } else if (lenB > lenA) {
          j++;
        } else {
          i++;
          j++;
        }
      }
    }
    if (i < lenA || j < lenB) edits++;
    return edits <= 1;
  }

  List<String> _expandSynonymsAndTopics(
    String normalizedQuery,
    List<String> queryImlaiTokens,
    List<String> queryRoots,
  ) {
    final expanded = <String>[];
    final querySet = <String>{
      normalizedQuery,
      ...queryImlaiTokens,
      ...queryImlaiTokens.map(stripClitics),
      ...queryRoots,
    };

    for (final cluster in _quranicTopicSynonymClusters) {
      bool matchesCluster = false;
      for (final term in cluster) {
        final normTerm = toModernImlaiWord(term);
        final stemTerm = stripClitics(normTerm);
        if (querySet.contains(normTerm) || querySet.contains(stemTerm)) {
          matchesCluster = true;
          break;
        }
      }
      if (matchesCluster) {
        for (final term in cluster) {
          final normTerm = toModernImlaiWord(term);
          final stemTerm = stripClitics(normTerm);
          if (!querySet.contains(normTerm) &&
              !querySet.contains(stemTerm) &&
              !expanded.contains(term)) {
            expanded.add(term);
          }
        }
      }
    }
    return expanded;
  }

  // -------------------- Linguistic Tables & Thesaurus --------------------

  static const Set<String> _arabicStopWords = <String>{
    'في',
    'من',
    'على',
    'علي',
    'الى',
    'الي',
    'عن',
    'ان',
    'لا',
    'ما',
    'هو',
    'هي',
    'هم',
    'كم',
    'انما',
    'الذي',
    'الذين',
    'التي',
    'هذا',
    'هذه',
    'ذلك',
    'تلك',
    'او',
    'ثم',
    'بل',
    'قد',
    'لم',
    'لن',
    'لو',
    'لولا',
    'اذ',
    'اذا',
    'كل',
    'كان',
    'كانت',
    'كانوا',
    'يا',
    'ايها',
    'يايها',
  };

  static const List<String> _prefixes = <String>[
    'وكال',
    'وبال',
    'وفال',
    'ولل',
    'وال',
    'فال',
    'بال',
    'كال',
    'لل',
    'ال',
    'ول',
    'فل',
    'وس',
    'فس',
  ];

  static const List<String> _derivationalPrefixes = <String>[
    'است',
    'مست',
    'يست',
    'تست',
    'نست',
    'مت',
    'يت',
    'تت',
    'نت',
    'من',
    'ين',
    'تن',
  ];

  static const List<String> _suffixes = <String>[
    'كموها',
    'تموها',
    'موها',
    'ونهم',
    'ينهم',
    'ونه',
    'ينه',
    'تموه',
    'ناهم',
    'ناكم',
    'همو',
    'كما',
    'هما',
    'اتكم',
    'اتهم',
    'اتنا',
    'ونكم',
    'ينكم',
    'وننا',
    'يننا',
    'تاه',
    'تان',
    'تين',
    'ات',
    'ون',
    'ين',
    'ان',
    'وا',
    'تم',
    'تن',
    'كم',
    'هم',
    'هن',
    'نا',
    'ها',
    'ني',
    'يه',
    'ه',
    'ك',
    'ي',
  ];

  static const Map<String, String> _uthmaniToImlaiMap = <String, String>{
    'الصلوه': 'الصلاه',
    'صلوه': 'صلاه',
    'صلوتهم': 'صلاتهم',
    'صلوتك': 'صلاتك',
    'الزكوه': 'الزكاه',
    'زكوه': 'زكاه',
    'الحيوه': 'الحياه',
    'حيوه': 'حياه',
    'الربوا': 'الربا',
    'الغدوه': 'الغداه',
    'مشكوه': 'مشكاه',
    'نجوه': 'نجاه',
    'السموت': 'السماوات',
    'سموت': 'سماوات',
    'السموات': 'السماوات',
    'سموات': 'سماوات',
    'الرحمن': 'الرحمان',
    'رحمن': 'رحمان',
    'ابرهيم': 'ابراهيم',
    'اسمعيل': 'اسماعيل',
    'اسحق': 'اسحاق',
    'سليمن': 'سليمان',
    'هرون': 'هارون',
    'داود': 'داوود',
    'الصلحت': 'الصالحات',
    'صلحت': 'صالحات',
    'المومنون': 'المؤمنون',
    'المومنين': 'المؤمنين',
    'المومنات': 'المؤمنات',
    'القران': 'القرءان',
    'قران': 'قرءان',
    'قرانا': 'قرءانا',
    'المليكه': 'الملائكه',
    'مليكه': 'ملائكه',
    'ملئكه': 'ملائكه',
    'الملئكه': 'الملائكه',
    'اوليك': 'اولئك',
    'اولئك': 'اولئك',
  };

  /// Curated mapping of common, weak, geminate, and irregular Quranic words/stems
  /// to their exact 3-letter Arabic roots.
  static const Map<String, String> _irregularWordToRoot = <String, String>{
    // الله / إله
    'الله': 'اله',
    'اللهم': 'اله',
    'اله': 'اله',
    'الها': 'اله',
    'الهه': 'اله',
    // صلاة
    'الصلاه': 'صلو',
    'صلاه': 'صلو',
    'الصلوه': 'صلو',
    'صلوه': 'صلو',
    'صلاتهم': 'صلو',
    'صلاتك': 'صلو',
    'صلوات': 'صلو',
    'يصلي': 'صلو',
    'يصلون': 'صلو',
    'صلوا': 'صلو',
    'المصلين': 'صلو',
    'مصلين': 'صلو',
    'مصلي': 'صلو',
    // زكاة
    'الزكاه': 'زكو',
    'زكاه': 'زكو',
    'الزكوه': 'زكو',
    'زكوه': 'زكو',
    'يزكي': 'زكو',
    'يزكيهم': 'زكو',
    'تزكي': 'زكو',
    'تزكا': 'زكو',
    'ازكي': 'زكو',
    'زكي': 'زكو',
    // حياة
    'الحياه': 'حيي',
    'حياه': 'حيي',
    'الحيوه': 'حيي',
    'حيوه': 'حيي',
    'الحي': 'حيي',
    'حي': 'حيي',
    'حيا': 'حيي',
    'يحيي': 'حيي',
    'يحي': 'حيي',
    'احيا': 'حيي',
    'احياكم': 'حيي',
    'محياي': 'حيي',
    'يستحيي': 'حيي',
    // تقوى / وقي
    'تقوي': 'وقي',
    'التقوي': 'وقي',
    'اتقوا': 'وقي',
    'اتق': 'وقي',
    'يتقي': 'وقي',
    'يتقون': 'وقي',
    'المتقين': 'وقي',
    'المتقون': 'وقي',
    'متقين': 'وقي',
    'تتقون': 'وقي',
    'وقاهم': 'وقي',
    'قوا': 'وقي',
    // هدى
    'هدي': 'هدي',
    'الهدي': 'هدي',
    'هداه': 'هدي',
    'هداهم': 'هدي',
    'يهدي': 'هدي',
    'تهدي': 'هدي',
    'اهدنا': 'هدي',
    'اهتدي': 'هدي',
    'اهتدوا': 'هدي',
    'يهتدي': 'هدي',
    'يهتدون': 'هدي',
    'المهتدين': 'هدي',
    'المهتدون': 'هدي',
    'مهتدين': 'هدي',
    'هاد': 'هدي',
    // إيمان / أمن
    'ايمان': 'امن',
    'الايمان': 'امن',
    'ايمانهم': 'امن',
    'ايمانكم': 'امن',
    'امن': 'امن',
    'امنوا': 'امن',
    'امنت': 'امن',
    'امنا': 'امن',
    'يؤمن': 'امن',
    'يؤمنون': 'امن',
    'تؤمنون': 'امن',
    'مؤمن': 'امن',
    'مؤمنين': 'امن',
    'مؤمنون': 'امن',
    'المؤمنين': 'امن',
    'المؤمنون': 'امن',
    'المؤمنات': 'امن',
    'امين': 'امن',
    'الامين': 'امن',
    'امانه': 'امن',
    'الامانه': 'امن',
    'اماناتكم': 'امن',
    // توبة
    'توبه': 'توب',
    'التوبه': 'توب',
    'تاب': 'توب',
    'تابوا': 'توب',
    'يتوب': 'توب',
    'توبوا': 'توب',
    'التواب': 'توب',
    'توابا': 'توب',
    'التوابين': 'توب',
    // دعاء
    'دعاء': 'دعو',
    'الدعاء': 'دعو',
    'دعا': 'دعو',
    'دعوا': 'دعو',
    'يدعو': 'دعو',
    'يدعون': 'دعو',
    'تدعون': 'دعو',
    'ادعوا': 'دعو',
    'ادعوني': 'دعو',
    'الداعي': 'دعو',
    'دعوه': 'دعو',
    // قيام / إقامة / قوم
    'القيامه': 'قوم',
    'قيامه': 'قوم',
    'اقام': 'قوم',
    'اقاموا': 'قوم',
    'يقيمون': 'قوم',
    'اقيموا': 'قوم',
    'المقيمين': 'قوم',
    'مستقيم': 'قوم',
    'المستقيم': 'قوم',
    'قائما': 'قوم',
    'القائمين': 'قوم',
    'القيوم': 'قوم',
    'قيوم': 'قوم',
    'قام': 'قوم',
    'قاموا': 'قوم',
    'يقوم': 'قوم',
    'قوم': 'قوم',
    'القوم': 'قوم',
    // صيام / صوم
    'الصيام': 'صوم',
    'صيام': 'صوم',
    'الصوم': 'صوم',
    'صوم': 'صوم',
    'صائما': 'صوم',
    'الصائمين': 'صوم',
    'الصائمات': 'صوم',
    'تصوموا': 'صوم',
    'يصوم': 'صوم',
    // جنة
    'جنه': 'جنن',
    'الجنه': 'جنن',
    'جنات': 'جنن',
    'الجنات': 'جنن',
    'الجن': 'جنن',
    'مجنون': 'جنن',
    // نار / نور
    'نار': 'نور',
    'النار': 'نور',
    'نارا': 'نور',
    'نور': 'نور',
    'النور': 'نور',
    'منير': 'نور',
    // سماء
    'سماء': 'سمو',
    'السماء': 'سمو',
    'سماوات': 'سمو',
    'السماوات': 'سمو',
    'اسم': 'سمو',
    'اسماء': 'سمو',
    'الاسماء': 'سمو',
    // ماء
    'ماء': 'موه',
    'الماء': 'موه',
    // قول
    'قال': 'قول',
    'قالوا': 'قول',
    'قالت': 'قول',
    'قل': 'قول',
    'يقول': 'قول',
    'يقولون': 'قول',
    'تقولون': 'قول',
    'قول': 'قول',
    'قولا': 'قول',
    'القول': 'قول',
    'قيل': 'قول',
    'قائل': 'قول',
    // خوف
    'خوف': 'خوف',
    'الخوف': 'خوف',
    'خاف': 'خوف',
    'خافوا': 'خوف',
    'يخاف': 'خوف',
    'يخافون': 'خوف',
    'تخافوا': 'خوف',
    'خيفه': 'خوف',
    // رجاء
    'رجاء': 'رجو',
    'يرجو': 'رجو',
    'يرجون': 'رجو',
    'ترجون': 'رجو',
    // حب / مودة
    'حب': 'حبب',
    'يحب': 'حبب',
    'يحبهم': 'حبب',
    'يحبون': 'حبب',
    'تحبون': 'حبب',
    'احب': 'حبب',
    'محبه': 'حبب',
    'موده': 'ودد',
    'ود': 'ودد',
    'يود': 'ودد',
    'الودود': 'ودد',
    // بر / إحسان
    'البر': 'برر',
    'بر': 'برر',
    'الابرار': 'برر',
    'ابرار': 'برر',
    'بارا': 'برر',
    'احسان': 'حسن',
    'الاحسان': 'حسن',
    'احسن': 'حسن',
    'احسنوا': 'حسن',
    'يحسنون': 'حسن',
    'المحسنين': 'حسن',
    'محسنين': 'حسن',
    'حسنه': 'حسن',
    'الحسنه': 'حسن',
    'حسنا': 'حسن',
    'الحسني': 'حسن',
    // والدين / أولاد
    'والد': 'ولد',
    'والدين': 'ولد',
    'الوالدين': 'ولد',
    'والديه': 'ولد',
    'بوالديه': 'ولد',
    'لوالديه': 'ولد',
    'ولد': 'ولد',
    'ولدا': 'ولد',
    'اولاد': 'ولد',
    'اولادكم': 'ولد',
    'اولادهم': 'ولد',
    'يلد': 'ولد',
    'يولد': 'ولد',
    // الناس / إنسان
    'الناس': 'انس',
    'ناس': 'انس',
    'انسان': 'انس',
    'الانسان': 'انس',
    'الانس': 'انس',
    'انسا': 'انس',
    // نساء
    'نساء': 'نسو',
    'النساء': 'نسو',
    // ربا
    'الربا': 'ربو',
    'ربا': 'ربو',
    'يربي': 'ربو',
    'يربو': 'ربو',
    // عفو
    'عفو': 'عفو',
    'العفو': 'عفو',
    'عفا': 'عفو',
    'يعفو': 'عفو',
    'اعف': 'عفو',
    // شاء / مشيئة
    'شاء': 'شيء',
    'يشاء': 'شيء',
    'تشاءون': 'شيء',
    'شيء': 'شيء',
    'شيا': 'شيء',
    // رؤية
    'راي': 'راي',
    'يرى': 'راي',
    'يري': 'راي',
    'ترى': 'راي',
    'تري': 'راي',
    'يرون': 'راي',
    'رؤيا': 'راي',
    'الرؤيا': 'راي',
    // أتى / إيتاء
    'اتي': 'اتي',
    'ياتي': 'اتي',
    'اتينا': 'اتي',
    'اتنا': 'اتي',
    'اتوا': 'اتي',
    'يؤتي': 'اتي',
    'يؤتون': 'اتي',
    'ايتاء': 'اتي',
    'الاتي': 'اتي',
    // طاعة
    'طاعه': 'طوع',
    'الطاعه': 'طوع',
    'اطاع': 'طوع',
    'اطيعوا': 'طوع',
    'يطيع': 'طوع',
    'يطيعون': 'طوع',
    'طوعا': 'طوع',
    'استطاع': 'طوع',
    'استطاعوا': 'طوع',
    'يستطيع': 'طوع',
    'يستطيعون': 'طوع',
    // موت
    'الموت': 'موت',
    'موت': 'موت',
    'موتا': 'موت',
    'مات': 'موت',
    'ماتوا': 'موت',
    'يموت': 'موت',
    'تموتن': 'موت',
    'الموتي': 'موت',
    'ميت': 'موت',
    'ميتا': 'موت',
    'اموات': 'موت',
    'امواتا': 'موت',
  };

  /// Curated Quranic Synonym & Thematic Clusters.
  /// When a user searches for any word in a cluster, the other words in that
  /// cluster are searched and presented in the separate "Synonyms & Topics" group.
  static const List<List<String>> _quranicTopicSynonymClusters = <List<String>>[
    // 1. الجنة والنعيم
    [
      'الجنة',
      'جنة',
      'جنات',
      'الفردوس',
      'النعيم',
      'دار السلام',
      'الخلد',
      'المأوى',
      'عدن',
      'أنهار',
      'الأبرار',
    ],
    // 2. النار والعذاب
    [
      'النار',
      'نار',
      'جهنم',
      'الجحيم',
      'السعير',
      'سقر',
      'لظى',
      'الحطمة',
      'الهاوية',
      'العذاب',
      'عذاب',
      'العقاب',
    ],
    // 3. يوم القيامة والآخرة
    [
      'القيامة',
      'الآخرة',
      'الساعة',
      'يوم الدين',
      'البعث',
      'الحشر',
      'النشور',
      'الحساب',
      'الميزان',
      'القارعة',
      'الواقعة',
      'الحاقة',
      'الغاشية',
    ],
    // 4. التوبة والمغفرة والعفو
    [
      'التوبة',
      'توبة',
      'تاب',
      'المغفرة',
      'مغفرة',
      'يغفر',
      'غفور',
      'استغفروا',
      'العفو',
      'يعفو',
      'الذنوب',
      'السيئات',
      'تكفير',
    ],
    // 5. الصبر والابتلاء والفرج
    [
      'الصبر',
      'صبر',
      'الصابرين',
      'اصبروا',
      'الابتلاء',
      'بلاء',
      'الفتنة',
      'المصيبة',
      'العسر',
      'اليسر',
      'الفرج',
      'الضر',
      'البأساء',
      'الضراء',
    ],
    // 6. الرزق والمال والإنفاق والصدقة
    [
      'الرزق',
      'رزق',
      'يرزق',
      'المال',
      'أموال',
      'الإنفاق',
      'ينفقون',
      'أنفقوا',
      'الصدقة',
      'الصدقات',
      'الزكاة',
      'الفقراء',
      'المساكين',
      'اليتيم',
      'الربا',
    ],
    // 7. الدعاء والذكر والتسبيح
    [
      'الدعاء',
      'دعاء',
      'ادعوني',
      'يدعو',
      'الذكر',
      'ذكر',
      'اذكروا',
      'التسبيح',
      'سبح',
      'يسبحون',
      'الحمد',
      'التضرع',
      'الخشوع',
    ],
    // 8. الوالدين والأسرة والذرية
    [
      'الوالدين',
      'والديه',
      'الأم',
      'الأب',
      'الأولاد',
      'الذرية',
      'الأزواج',
      'النساء',
      'النكاح',
      'الطلاق',
      'المودة',
      'الأرحام',
    ],
    // 9. العلم والحكمة والتفكر
    [
      'العلم',
      'علم',
      'العلماء',
      'يعلمون',
      'الحكمة',
      'العقل',
      'يعقلون',
      'التفكر',
      'يتفكرون',
      'يدبرون',
      'أولو الألباب',
      'البصيرة',
    ],
    // 10. العدل والظلم والحق
    [
      'العدل',
      'عدل',
      'القسط',
      'المقسطين',
      'الحق',
      'الظلم',
      'ظلم',
      'الظالمين',
      'البغي',
      'الفساد',
      'الإصلاح',
    ],
    // 11. التقوى والإيمان والإحسان
    [
      'التقوى',
      'المتقين',
      'اتقوا',
      'الإيمان',
      'المؤمنين',
      'الإحسان',
      'المحسنين',
      'البر',
      'العمل الصالح',
      'الصالحات',
      'الهدى',
    ],
    // 12. الصلاة والعبادة والصيام والحج
    [
      'الصلاة',
      'الصلوة',
      'المصلين',
      'السجود',
      'الركوع',
      'العبادة',
      'اعبدوا',
      'الصيام',
      'الصوم',
      'الحج',
      'الكعبة',
      'المسجد الحرام',
    ],
  ];
}
