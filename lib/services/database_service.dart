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
  Future<Database>? _initFuture;
  final Map<int, MushafPageData> _pageCache = <int, MushafPageData>{};
  List<SurahInfo>? _surahsCache;
  List<JuzInfo>? _juzsCache;
  List<int>? _cumulativeLettersByAyah;

  Future<Database> get database {
    if (_db != null) return Future<Database>.value(_db!);
    return _initFuture ??= _initDatabase().then((db) {
      _db = db;
      return db;
    }).catchError((Object err) {
      _initFuture = null;
      throw err;
    });
  }

  static const String _expectedLayoutVersion = 'qcf4_1441h_v1';

  Future<Database> _initDatabase() async {
    final dbFolder = await getDatabasesPath();
    final dbPath = p.join(dbFolder, 'mushaf_v1.db');

    await Directory(p.dirname(dbPath)).create(recursive: true);
    final exists = await databaseExists(dbPath);
    if (!exists) {
      final initTmpPath = p.join(dbFolder, 'mushaf_v1_init.db');
      await _copyBundledDatabaseTo(initTmpPath);
      await File(initTmpPath).rename(dbPath);
    }

    var db = await openDatabase(dbPath);

    // Check if an existing installation needs the QCF4 (1441H) layout upgrade.
    // Atomically builds the upgraded DB and preserves ALL user tables
    // (bookmarks, khatmas, khatma_logs, tafsir_cache, word_gloss_cache).
    if (!await _hasExpectedLayoutVersion(db)) {
      final savedBookmarks = await _safeQueryAll(db, 'bookmarks');
      final savedKhatmas = await _safeQueryAll(db, 'khatmas');
      final savedKhatmaLogs = await _safeQueryAll(db, 'khatma_logs');
      final savedTafsirCache = await _safeQueryAll(db, 'tafsir_cache');
      final savedWordGlossCache = await _safeQueryAll(db, 'word_gloss_cache');
      await db.close();

      final tmpPath = p.join(dbFolder, 'mushaf_v1_migrating.db');
      await _copyBundledDatabaseTo(tmpPath);
      final migratedDb = await openDatabase(tmpPath);
      try {
        await _ensureUserTables(migratedDb);
        await migratedDb.transaction((txn) async {
          final batch = txn.batch();
          for (final row in savedBookmarks) {
            batch.insert(
              'bookmarks',
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          for (final row in savedKhatmas) {
            batch.insert(
              'khatmas',
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          for (final row in savedKhatmaLogs) {
            batch.insert(
              'khatma_logs',
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          for (final row in savedTafsirCache) {
            batch.insert(
              'tafsir_cache',
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          for (final row in savedWordGlossCache) {
            batch.insert(
              'word_gloss_cache',
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        });
      } finally {
        await migratedDb.close();
      }

      // Clean up any stale SQLite WAL/SHM/journal sidecar files before swapping
      for (final suffix in const ['-wal', '-shm', '-journal']) {
        final oldSidecar = File('$dbPath$suffix');
        if (await oldSidecar.exists()) await oldSidecar.delete();
        final tmpSidecar = File('$tmpPath$suffix');
        if (await tmpSidecar.exists()) await tmpSidecar.delete();
      }

    // Atomically swap migrated DB into place only after all user rows succeeded.
      await File(tmpPath).rename(dbPath);
      db = await openDatabase(dbPath);
    } else {
      await _ensureUserTables(db);
    }

    // Self-healing sanity check: if a previous interrupted install ever left
    // an incomplete pages table, rebuild cleanly from bundled assets.
    if (!await _isCoreSchemaHealthy(db)) {
      await db.close();
      for (final suffix in const ['', '-wal', '-shm', '-journal']) {
        final f = File('$dbPath$suffix');
        if (await f.exists()) await f.delete();
      }
      final repairTmpPath = p.join(dbFolder, 'mushaf_v1_repair.db');
      await _copyBundledDatabaseTo(repairTmpPath);
      await File(repairTmpPath).rename(dbPath);
      db = await openDatabase(dbPath);
      await _ensureUserTables(db);
    }

    return db;
  }

  Future<bool> _isCoreSchemaHealthy(Database db) async {
    try {
      final rows = await db.rawQuery('SELECT COUNT(*) AS cnt FROM pages');
      final cnt = (rows.first['cnt'] as int?) ?? 0;
      return cnt == 604;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, Object?>>> _safeQueryAll(
    Database db,
    String table,
  ) async {
    try {
      return await db.query(table);
    } catch (_) {
      return const <Map<String, Object?>>[];
    }
  }

  Future<void> _copyBundledDatabaseTo(String dbPath) async {
    final byteData = await rootBundle.load('assets/mushaf.db');
    final bytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    await File(dbPath).writeAsBytes(bytes, flush: true);
  }

  Future<bool> _hasExpectedLayoutVersion(Database db) async {
    try {
      final rows = await db.query(
        'db_meta',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['layout_version'],
        limit: 1,
      );
      return rows.isNotEmpty && rows.first['value'] == _expectedLayoutVersion;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureUserTables(Database db) async {
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS khatmas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        serial_number INTEGER NOT NULL,
        title TEXT NOT NULL,
        status TEXT NOT NULL,
        started_at TEXT NOT NULL,
        completed_at TEXT,
        metadata_json TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS khatma_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        khatma_id INTEGER NOT NULL,
        ayah_global_id INTEGER NOT NULL,
        surah_id INTEGER NOT NULL,
        ayah_number INTEGER NOT NULL,
        verse_key TEXT NOT NULL,
        surah_name_arabic TEXT NOT NULL,
        page_number INTEGER NOT NULL,
        juz_number INTEGER NOT NULL,
        recorded_at TEXT NOT NULL,
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_khatma_logs_khatma
      ON khatma_logs(khatma_id, id DESC)
    ''');
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

  /// Preloads the cumulative Arabic letter count for each of the 6,236 ayahs
  /// so Khatma Thawab (Hasanat = letters * 10) can be calculated synchronously.
  Future<void> ensureLetterCountsLoaded() async {
    if (_cumulativeLettersByAyah != null) return;
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT id,
             length(replace(
               CASE
                 WHEN instr(text_clean, ' | ') > 0
                 THEN substr(text_clean, 1, instr(text_clean, ' | ') - 1)
                 ELSE text_clean
               END,
               ' ', ''
             )) AS letter_count
      FROM ayahs
      ORDER BY id ASC
    ''');
    final cumulative = List<int>.filled(6237, 0);
    int running = 0;
    for (final row in rows) {
      final id = (row['id'] as int?) ?? 0;
      final count = (row['letter_count'] as int?) ?? 0;
      running += count;
      if (id >= 1 && id <= 6236) {
        cumulative[id] = running;
      }
    }
    for (int i = 1; i <= 6236; i++) {
      if (cumulative[i] < cumulative[i - 1]) {
        cumulative[i] = cumulative[i - 1];
      }
    }
    _cumulativeLettersByAyah = cumulative;
  }

  /// Returns the total number of Arabic letters across all 6,236 ayahs of the Quran.
  int get totalQuranLetters {
    final table = _cumulativeLettersByAyah;
    if (table != null && table.length > 6236 && table[6236] > 0) {
      return table[6236];
    }
    return 324290;
  }

  /// Returns the cumulative number of Quranic Arabic letters from Ayah 1 up to
  /// [ayahGlobalId] (1..6236). Total letters across the Quran = 324,290.
  int getCumulativeLettersUpToAyah(int ayahGlobalId) {
    if (ayahGlobalId <= 0) return 0;
    final table = _cumulativeLettersByAyah;
    if (table != null) {
      final idx = ayahGlobalId.clamp(0, table.length - 1);
      return table[idx];
    }
    return ((ayahGlobalId.clamp(0, 6236) / 6236.0) * 324290).round();
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

    final lines = lineRows
        .map((row) {
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
        })
        .toList(growable: false);

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

  /// Fetches a contiguous range of [AyahRecord]s in [surahId] starting at
  /// [startAyahNumber] for [count] ayahs (clamped to the end of the Surah).
  Future<List<AyahRecord>> getAyahRangeInSurah({
    required int surahId,
    required int startAyahNumber,
    required int count,
  }) async {
    final db = await database;
    final endAyahNumber = startAyahNumber + (count < 1 ? 0 : count - 1);
    final rows = await db.rawQuery(
      '''
      SELECT a.*, s.name_arabic AS surah_name_arabic, s.name_english AS surah_name_english
      FROM ayahs a
      JOIN surahs s ON s.id = a.surah_id
      WHERE a.surah_id = ? AND a.ayah_number >= ? AND a.ayah_number <= ?
      ORDER BY a.ayah_number ASC
      ''',
      [surahId, startAyahNumber, endAyahNumber],
    );
    return rows.map(AyahRecord.fromMap).toList(growable: false);
  }

  /// Fetches all [LineWord] items belonging to [verseKey] (e.g. `"2:255"`) ordered by appearance.
  Future<List<LineWord>> getWordsForVerseKey(String verseKey) async {
    final db = await database;
    final rows = await db.query(
      'line_words',
      where: 'verse_key = ?',
      whereArgs: [verseKey],
      orderBy: 'id ASC',
    );
    return rows
        .map(LineWord.fromMap)
        .where((w) => !w.isStandaloneVerseMarker)
        .toList(growable: false);
  }

  /// Offline Arabic search using stripped/diacritic-free Uthmani text (`text_clean`).
  Future<List<AyahRecord>> searchAyahs(
    String rawQuery, {
    int limit = 100,
  }) async {
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

    final rows = await db.rawQuery('''
      SELECT a.*, s.name_arabic AS surah_name_arabic, s.name_english AS surah_name_english
      FROM ayahs a
      JOIN surahs s ON s.id = a.surah_id
      WHERE ${whereClauses.join(' AND ')}
      ORDER BY
        CASE WHEN a.text_clean LIKE ? OR a.text_clean LIKE ? THEN 0 ELSE 1 END,
        a.id ASC
      LIMIT ?
      ''', args);

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

  /// Returns `(verseKey, ayahNumber, textIndopak)` for all ayahs on [pageNumber].
  Future<
    List<({String verseKey, int surahId, int ayahNumber, String textIndopak})>
  >
  getIndoPakVersesForPage(int pageNumber) async {
    final db = await database;
    final rows = await db.query(
      'ayahs',
      columns: [
        'verse_key',
        'surah_id',
        'ayah_number',
        'text_indopak',
        'text_uthmani',
      ],
      where: 'page_number = ?',
      whereArgs: [pageNumber],
      orderBy: 'id ASC',
    );
    return rows
        .map((r) {
          final ip =
              (r['text_indopak'] as String?) ??
              (r['text_uthmani'] as String? ?? '');
          return (
            verseKey: r['verse_key'] as String,
            surahId: r['surah_id'] as int,
            ayahNumber: r['ayah_number'] as int,
            textIndopak: ip,
          );
        })
        .toList(growable: false);
  }
}
