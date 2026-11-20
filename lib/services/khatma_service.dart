import 'dart:convert';
import 'dart:math' as math;
import 'package:sqflite/sqflite.dart';

import '../models/khatma_models.dart';
import '../models/mushaf_models.dart';
import '../utils/arabic_utils.dart';
import 'database_service.dart';

class KhatmaService {
  KhatmaService._();
  static final KhatmaService instance = KhatmaService._();

  bool _tablesInitialized = false;

  Future<Database> _getDb() async {
    final db = await DatabaseService.instance.database;
    if (!_tablesInitialized) {
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
      _tablesInitialized = true;
    }
    return db;
  }

  /// Loads all Khatmas (active and completed) with their chronological progress logs.
  Future<List<KhatmaRecord>> getAllKhatmas() async {
    final db = await _getDb();
    final khatmaRows = await db.query('khatmas', orderBy: 'serial_number DESC');
    if (khatmaRows.isEmpty) return const <KhatmaRecord>[];

    final logRows = await db.query('khatma_logs', orderBy: 'id DESC');
    final logsByKhatma = <int, List<KhatmaProgressEntry>>{};
    for (final row in logRows) {
      final entry = KhatmaProgressEntry.fromMap(row);
      (logsByKhatma[entry.khatmaId] ??= <KhatmaProgressEntry>[]).add(entry);
    }

    return khatmaRows
        .map((row) {
          final id = row['id'] as int;
          return KhatmaRecord.fromMap(
            row,
            logs: logsByKhatma[id] ?? const <KhatmaProgressEntry>[],
          );
        })
        .toList(growable: false);
  }

  /// Starts a new Khatma, assigns it the next sequential serial number, and records start date/time.
  /// Supports a custom [startedAt] date (e.g., in the past when continuing a Khatma started
  /// on a physical Mushaf or another device) and an optional [initialAyah] starting position.
  Future<KhatmaRecord> startNewKhatma({
    String? customTitle,
    Map<String, dynamic>? metadata,
    AyahRecord? initialAyah,
    DateTime? startedAt,
  }) async {
    final db = await _getDb();
    final maxRow = await db.rawQuery(
      'SELECT COALESCE(MAX(serial_number), 0) AS max_serial FROM khatmas',
    );
    final nextSerial = ((maxRow.first['max_serial'] as int?) ?? 0) + 1;
    final effectiveStart = startedAt ?? DateTime.now();
    final startIso = effectiveStart.toIso8601String();
    final title = (customTitle != null && customTitle.trim().isNotEmpty)
        ? customTitle.trim()
        : 'الختمة رقم ${ArabicUtils.toArabicDigits(nextSerial)}';

    final mergedMeta = <String, dynamic>{
      if (metadata != null) ...metadata,
      if (initialAyah != null) ...{
        'initial_verse_key': initialAyah.verseKey,
        'initial_surah_id': initialAyah.surahId,
        'initial_ayah_number': initialAyah.ayahNumber,
        'initial_surah_name_arabic': initialAyah.surahNameArabic,
        'initial_page_number': initialAyah.pageNumber,
      },
    };

    final id = await db.insert('khatmas', {
      'serial_number': nextSerial,
      'title': title,
      'status': KhatmaStatus.active.dbValue,
      'started_at': startIso,
      'completed_at': null,
      'metadata_json': mergedMeta.isNotEmpty ? jsonEncode(mergedMeta) : null,
    });

    if (initialAyah != null &&
        (initialAyah.surahId != 1 || initialAyah.ayahNumber != 1)) {
      return (await markAyahProgress(
        id,
        initialAyah,
        notes: 'موضع بدء الختمة في التطبيق',
      )).khatma;
    }

    final all = await getAllKhatmas();
    return all.firstWhere((k) => k.id == id);
  }

  /// Marks [ayah] as the current location reached in [khatmaId] and records the timestamp.
  /// If [ayah] is the final verse of the Quran (114:6 / global ID 6236), automatically
  /// completes the Khatma and returns `justCompleted: true`.
  Future<({KhatmaRecord khatma, bool justCompleted})> markAyahProgress(
    int khatmaId,
    AyahRecord ayah, {
    String? notes,
  }) async {
    final db = await _getDb();
    final nowIso = DateTime.now().toIso8601String();

    await db.insert('khatma_logs', {
      'khatma_id': khatmaId,
      'ayah_global_id': ayah.id,
      'surah_id': ayah.surahId,
      'ayah_number': ayah.ayahNumber,
      'verse_key': ayah.verseKey,
      'surah_name_arabic': ayah.surahNameArabic,
      'page_number': ayah.pageNumber,
      'juz_number': ayah.juzNumber,
      'recorded_at': nowIso,
      'notes': notes,
    });

    final isEndOfQuran =
        ayah.id >= 6236 || (ayah.surahId == 114 && ayah.ayahNumber == 6);

    bool justCompleted = false;
    if (isEndOfQuran) {
      await db.update(
        'khatmas',
        {'status': KhatmaStatus.completed.dbValue, 'completed_at': nowIso},
        where: 'id = ?',
        whereArgs: [khatmaId],
      );
      justCompleted = true;
    }

    final all = await getAllKhatmas();
    final updated = all.firstWhere((k) => k.id == khatmaId);
    return (khatma: updated, justCompleted: justCompleted);
  }

  /// Deletes the current (latest) Khatma mark for [khatmaId], rolling the mark
  /// back to the previous last known location.
  Future<KhatmaRecord?> deleteCurrentMark(int khatmaId) async {
    final db = await _getDb();
    final latestRows = await db.query(
      'khatma_logs',
      where: 'khatma_id = ?',
      whereArgs: [khatmaId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (latestRows.isEmpty) return null;

    final latestId = latestRows.first['id'] as int;
    await db.delete('khatma_logs', where: 'id = ?', whereArgs: [latestId]);

    // If the Khatma was completed, rolling back the last mark re-activates it
    await db.update(
      'khatmas',
      {'status': KhatmaStatus.active.dbValue, 'completed_at': null},
      where: 'id = ?',
      whereArgs: [khatmaId],
    );

    final all = await getAllKhatmas();
    for (final k in all) {
      if (k.id == khatmaId) return k;
    }
    return null;
  }

  /// Deletes a specific log entry by [logId] and re-evaluates Khatma status.
  Future<KhatmaRecord?> deleteLogEntry(int khatmaId, int logId) async {
    final db = await _getDb();
    await db.delete('khatma_logs', where: 'id = ?', whereArgs: [logId]);

    final all = await getAllKhatmas();
    for (final k in all) {
      if (k.id == khatmaId) return k;
    }
    return null;
  }

  /// Manually marks [khatmaId] as completed at the end of the Quran (114:6).
  Future<KhatmaRecord> completeKhatmaAtEnd(int khatmaId) async {
    final lastAyah = await DatabaseService.instance.getAyahByVerseKey('114:6');
    if (lastAyah != null) {
      final res = await markAyahProgress(khatmaId, lastAyah);
      return res.khatma;
    }
    final db = await _getDb();
    final nowIso = DateTime.now().toIso8601String();
    await db.update(
      'khatmas',
      {'status': KhatmaStatus.completed.dbValue, 'completed_at': nowIso},
      where: 'id = ?',
      whereArgs: [khatmaId],
    );
    final all = await getAllKhatmas();
    return all.firstWhere((k) => k.id == khatmaId);
  }

  /// Deletes an entire Khatma and its logs.
  Future<void> deleteKhatma(int khatmaId) async {
    final db = await _getDb();
    await db.delete(
      'khatma_logs',
      where: 'khatma_id = ?',
      whereArgs: [khatmaId],
    );
    await db.delete('khatmas', where: 'id = ?', whereArgs: [khatmaId]);
  }

  /// Generates a full statistical [KhatmaReport] for [khatma].
  KhatmaReport generateReport(KhatmaRecord khatma) {
    final start = khatma.startedAt;
    final now = DateTime.now();
    final end = khatma.isCompleted
        ? (khatma.completedAt ?? (khatma.currentMark?.recordedAt ?? now))
        : now;
    final rawDiff = end.difference(start);
    final exactDuration = rawDiff.isNegative ? Duration.zero : rawDiff;

    final exactDays = exactDuration.inSeconds / 86400.0;
    // Effective days for daily averages (minimum 1.0 day so same-day completions
    // report 1-day averages cleanly without dividing by near-zero).
    final effectiveDays = math.max(exactDays, 1.0);

    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final calendarDays = math.max(endDay.difference(startDay).inDays + 1, 1);

    final totalAyahsReached = khatma.isCompleted
        ? 6236
        : (khatma.currentMark?.ayahGlobalId ?? 0);
    final totalPagesReached = khatma.isCompleted
        ? 604
        : (khatma.currentMark?.pageNumber ?? 1);
    final totalJuzReached = khatma.isCompleted
        ? 30
        : (khatma.currentMark?.juzNumber ?? 1);

    final avgAyahs = totalAyahsReached / effectiveDays;
    final avgPages = totalPagesReached / effectiveDays;
    final avgJuz = totalJuzReached / effectiveDays;

    final int lettersRead = DatabaseService.instance
        .getCumulativeLettersUpToAyah(totalAyahsReached);
    final int estimatedHasanat = lettersRead * 10;

    int? estimatedRemainingDays;
    DateTime? estimatedCompletionDate;
    if (khatma.isCompleted) {
      estimatedRemainingDays = 0;
      estimatedCompletionDate = end;
    } else if (totalAyahsReached > 0 && avgAyahs > 0) {
      final remainingAyahs = math.max(6236 - totalAyahsReached, 0);
      estimatedRemainingDays = (remainingAyahs / avgAyahs).ceil();
      estimatedCompletionDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: estimatedRemainingDays));
    }

    // Analyze usual time of day from all progress timestamps (and start timestamp if no logs)
    final slotCounts = <ReadingTimeSlot, int>{
      for (final slot in ReadingTimeSlot.values) slot: 0,
    };
    final hourCounts = List<int>.filled(24, 0);

    if (khatma.logs.isEmpty) {
      final slot = ReadingTimeSlot.fromHour(start.hour);
      slotCounts[slot] = (slotCounts[slot] ?? 0) + 1;
      hourCounts[start.hour]++;
    } else {
      for (final entry in khatma.logs) {
        final h = entry.recordedAt.hour;
        final slot = ReadingTimeSlot.fromHour(h);
        slotCounts[slot] = (slotCounts[slot] ?? 0) + 1;
        hourCounts[h]++;
      }
    }

    ReadingTimeSlot bestSlot = ReadingTimeSlot.maghribIsha;
    int maxSlotCount = -1;
    for (final entry in slotCounts.entries) {
      if (entry.value > maxSlotCount) {
        maxSlotCount = entry.value;
        bestSlot = entry.key;
      }
    }

    int peakHour = start.hour;
    int maxHourCount = -1;
    for (int h = 0; h < 24; h++) {
      if (hourCounts[h] > maxHourCount) {
        maxHourCount = hourCounts[h];
        peakHour = h;
      }
    }

    return KhatmaReport(
      khatmaId: khatma.id,
      serialNumber: khatma.serialNumber,
      startedAt: start,
      completedAt: end,
      exactDuration: exactDuration,
      durationInDays: exactDays,
      calendarDaysSpan: calendarDays,
      totalCheckpoints: khatma.logs.length,
      averageAyahsPerDay: avgAyahs,
      averagePagesPerDay: avgPages,
      averageJuzPerDay: avgJuz,
      usualReadingSlot: bestSlot,
      peakReadingHour: peakHour,
      slotDistribution: slotCounts,
      estimatedCompletionDate: estimatedCompletionDate,
      estimatedRemainingDays: estimatedRemainingDays,
      totalLettersRead: lettersRead,
      estimatedHasanat: estimatedHasanat,
    );
  }
}
