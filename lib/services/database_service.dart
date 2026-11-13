import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/mushaf_models.dart';
import '../utils/arabic_utils.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;
  final Map<int, MushafPageData> _pageCache = <int, MushafPageData>{};
  List<SurahInfo>? _surahsCache;
  List<JuzInfo>? _juzsCache;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbFolder = await getDatabasesPath();
    final dbPath = p.join(dbFolder, 'mushaf_v1.db');

    final exists = await databaseExists(dbPath);
    if (!exists) {
      await Directory(p.dirname(dbPath)).create(recursive: true);
      final byteData = await rootBundle.load('assets/mushaf.db');
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      await File(dbPath).writeAsBytes(bytes, flush: true);
    }

    final db = await openDatabase(dbPath);
    // Ensure bookmarks table exists for user data persistence
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        page_number INTEGER NOT NULL,
        surah_id INTEGER NOT NULL,
        ayah_number INTEGER,
        verse_key TEXT,
        title TEXT NOT NULL,
        snippet TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    return db;
  }

  /// Loads all 114 Surahs ordered by Surah ID.
  Future<List<SurahInfo>> getAllSurahs() async {
    if (_surahsCache != null) return _surahsCache!;
    final db = await database;
    final rows = await db.query('surahs', orderBy: 'id ASC');
    _surahsCache = rows.map(SurahInfo.fromMap).toList(growable: false);
    return _surahsCache!;
  }

  /// Loads all 30 Juzs ordered by Juz ID.
  Future<List<JuzInfo>> getAllJuzs() async {
    if (_juzsCache != null) return _juzsCache!;
    final db = await database;
    final rows = await db.query('juzs', orderBy: 'id ASC');
    _juzsCache = rows.map(JuzInfo.fromMap).toList(growable: false);
    return _juzsCache!;
  }

  /// Returns cached [MushafPageData] if already loaded in memory.
  MushafPageData? getCachedPageData(int pageNumber) => _pageCache[pageNumber];

  /// Fetches complete layout and word-level QPC V1 glyphs for [pageNumber] (1..604).
  Future<MushafPageData> getPageData(int pageNumber) async {
    final clamped = pageNumber.clamp(1, 604);
    final cached = _pageCache[clamped];
    if (cached != null) return cached;

    final db = await database;
    final pageRows = await db.query(
      'pages',
      where: 'page_number = ?',
      whereArgs: [clamped],
      limit: 1,
    );
    if (pageRows.isEmpty) {
      throw StateError('Page $clamped not found in mushaf.db');
    }
    final pageInfo = MushafPageInfo.fromMap(pageRows.first);

    final lineRows = await db.query(
      'page_lines',
      where: 'page_number = ?',
      whereArgs: [clamped],
      orderBy: 'line_number ASC',
    );

    final wordRows = await db.query(
      'line_words',
      where: 'page_number = ?',
      whereArgs: [clamped],
      orderBy: 'line_number ASC, word_index ASC',
    );

    final wordsByLine = <int, List<LineWord>>{};
    for (final wRow in wordRows) {
      final lineNum = wRow['line_number'] as int;
      (wordsByLine[lineNum] ??= <LineWord>[]).add(LineWord.fromMap(wRow));
    }

    final lines = lineRows.map((row) {
      final lineNum = row['line_number'] as int;
      return MushafPageLine(
        pageNumber: clamped,
        lineNumber: lineNum,
        lineType: row['line_type'] as String,
        surahId: row['surah_id'] as int?,
        headerText: row['header_text'] as String?,
        qpcV1Text: row['qpc_v1_text'] as String?,
        uthmaniText: row['uthmani_text'] as String?,
        verseRange: row['verse_range'] as String?,
        words: wordsByLine[lineNum] ?? const <LineWord>[],
      );
    }).toList(growable: false);

    final pageData = MushafPageData(info: pageInfo, lines: lines);

    // Keep cache bounded to ~30 pages around recent navigation
    if (_pageCache.length > 36) {
      final keysToRemove = _pageCache.keys
          .where((k) => (k - clamped).abs() > 12)
          .toList(growable: false);
      for (final k in keysToRemove) {
        _pageCache.remove(k);
      }
    }
    _pageCache[clamped] = pageData;
    return pageData;
  }

  /// Preloads page layout data for [centerPage] and neighbors.
  Future<void> preloadPages(int centerPage, {int radius = 2}) async {
    await getPageData(centerPage);
    for (int offset = 1; offset <= radius; offset++) {
      final next = centerPage + offset;
      final prev = centerPage - offset;
      if (next <= 604 && !_pageCache.containsKey(next)) {
        await getPageData(next);
      }
      if (prev >= 1 && !_pageCache.containsKey(prev)) {
        await getPageData(prev);
      }
    }
  }

  /// Fetches a single [AyahRecord] by `surah:ayah` key (e.g. `"2:255"`).
  Future<AyahRecord?> getAyahByVerseKey(String verseKey) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT a.*, s.name_arabic AS surah_name_arabic, s.name_english AS surah_name_english
      FROM ayahs a
      JOIN surahs s ON s.id = a.surah_id
      WHERE a.verse_key = ?
      LIMIT 1
      ''',
      [verseKey],
    );
    if (rows.isEmpty) return null;
    return AyahRecord.fromMap(rows.first);
  }

  /// Offline Arabic search using stripped/diacritic-free Uthmani text (`text_clean`).
  Future<List<AyahRecord>> searchAyahs(String rawQuery, {int limit = 100}) async {
    final normalized = ArabicUtils.normalizeForSearch(rawQuery);
    if (normalized.isEmpty) return const <AyahRecord>[];

    final db = await database;
    // Also support Teh Marbuta -> Heh normalized variant
    final normalizedHeh = normalized.replaceAll('ة', 'ه');

    final tokens = normalized
        .split(' ')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList(growable: false);

    if (tokens.isEmpty) return const <AyahRecord>[];

    // First match exact phrase or token sequence in text_clean
    final whereClauses = <String>[];
    final args = <Object?>[];

    for (final token in tokens) {
      final tokenHeh = token.replaceAll('ة', 'ه');
      if (token != tokenHeh) {
        whereClauses.add('(a.text_clean LIKE ? OR a.text_clean LIKE ?)');
        args.add('%$token%');
        args.add('%$tokenHeh%');
      } else {
        whereClauses.add('a.text_clean LIKE ?');
        args.add('%$token%');
      }
    }

    // Order exact phrase matches first, then by surah & ayah order
    args.add('%$normalized%');
    args.add('%$normalizedHeh%');
    args.add(limit);

    final rows = await db.rawQuery(
      '''
      SELECT a.*, s.name_arabic AS surah_name_arabic, s.name_english AS surah_name_english
      FROM ayahs a
      JOIN surahs s ON s.id = a.surah_id
      WHERE ${whereClauses.join(' AND ')}
      ORDER BY
        CASE WHEN a.text_clean LIKE ? OR a.text_clean LIKE ? THEN 0 ELSE 1 END,
        a.id ASC
      LIMIT ?
      ''',
      args,
    );

    return rows.map(AyahRecord.fromMap).toList(growable: false);
  }

  /// Fetches all user bookmarks ordered by newest first.
  Future<List<BookmarkItem>> getBookmarks() async {
    final db = await database;
    final rows = await db.query('bookmarks', orderBy: 'id DESC');
    return rows.map(BookmarkItem.fromMap).toList(growable: false);
  }

  /// Toggles a page bookmark for [pageInfo]. Returns true if bookmarked, false if removed.
  Future<bool> togglePageBookmark(MushafPageInfo pageInfo) async {
    final db = await database;
    final existing = await db.query(
      'bookmarks',
      where: 'type = ? AND page_number = ?',
      whereArgs: ['page', pageInfo.pageNumber],
    );
    if (existing.isNotEmpty) {
      await db.delete(
        'bookmarks',
        where: 'type = ? AND page_number = ?',
        whereArgs: ['page', pageInfo.pageNumber],
      );
      return false;
    } else {
      await db.insert('bookmarks', {
        'type': 'page',
        'page_number': pageInfo.pageNumber,
        'surah_id': pageInfo.firstSurahId,
        'ayah_number': pageInfo.firstAyahNumber,
        'verse_key': null,
        'title': pageInfo.surahNamesArabic,
        'snippet':
            'صفحة ${ArabicUtils.toArabicDigits(pageInfo.pageNumber)} • الجزء ${ArabicUtils.toArabicDigits(pageInfo.juzNumber)}',
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    }
  }

  /// Toggles an Ayah bookmark for [ayah]. Returns true if bookmarked, false if removed.
  Future<bool> toggleAyahBookmark(AyahRecord ayah) async {
    final db = await database;
    final existing = await db.query(
      'bookmarks',
      where: 'type = ? AND verse_key = ?',
      whereArgs: ['ayah', ayah.verseKey],
    );
    if (existing.isNotEmpty) {
      await db.delete(
        'bookmarks',
        where: 'type = ? AND verse_key = ?',
        whereArgs: ['ayah', ayah.verseKey],
      );
      return false;
    } else {
      await db.insert('bookmarks', {
        'type': 'ayah',
        'page_number': ayah.pageNumber,
        'surah_id': ayah.surahId,
        'ayah_number': ayah.ayahNumber,
        'verse_key': ayah.verseKey,
        'title':
            'سورة ${ayah.surahNameArabic} • الآية ${ArabicUtils.toArabicDigits(ayah.ayahNumber)}',
        'snippet': ayah.textUthmani,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    }
  }

  /// Deletes a bookmark by ID.
  Future<void> deleteBookmark(int id) async {
    final db = await database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }
}
