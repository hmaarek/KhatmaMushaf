import 'dart:convert';

import '../l10n/l10n.dart';
import '../utils/arabic_utils.dart';

enum KhatmaStatus {
  active,
  completed;

  static KhatmaStatus fromString(String value) {
    return value == 'completed' ? KhatmaStatus.completed : KhatmaStatus.active;
  }

  String get dbValue => this == KhatmaStatus.completed ? 'completed' : 'active';
}

/// Time-of-day buckets used to analyze when the user does most of their reading.
enum ReadingTimeSlot {
  fajrMorning(
    arabicName: 'الفجر والصباح الباكر',
    englishName: 'Fajr & Early Morning',
    rangeLabel: '٤:٠٠ ص – ٩:٠٠ ص',
  ),
  forenoonNoon(
    arabicName: 'الضحى والظهيرة',
    englishName: 'Forenoon & Midday',
    rangeLabel: '٩:٠٠ ص – ٢:٠٠ م',
  ),
  asrAfternoon(
    arabicName: 'العصر والمساء المبكر',
    englishName: 'Asr & Afternoon',
    rangeLabel: '٢:٠٠ م – ٦:٠٠ م',
  ),
  maghribIsha(
    arabicName: 'المغرب والعشاء',
    englishName: 'Maghrib & Isha',
    rangeLabel: '٦:٠٠ م – ١٠:٠٠ م',
  ),
  nightQiyam(
    arabicName: 'الليل والثلث الأخير',
    englishName: 'Night & Qiyam',
    rangeLabel: '١٠:٠٠ م – ٤:٠٠ ص',
  );

  final String arabicName;
  final String englishName;
  final String rangeLabel;

  String get name => tr(arabicName, englishName);

  /// Time range label with digits/AM-PM localized.
  String get range => L10n.isAr
      ? rangeLabel
      : switch (this) {
          ReadingTimeSlot.fajrMorning => '4:00 AM – 9:00 AM',
          ReadingTimeSlot.forenoonNoon => '9:00 AM – 2:00 PM',
          ReadingTimeSlot.asrAfternoon => '2:00 PM – 6:00 PM',
          ReadingTimeSlot.maghribIsha => '6:00 PM – 10:00 PM',
          ReadingTimeSlot.nightQiyam => '10:00 PM – 4:00 AM',
        };

  const ReadingTimeSlot({
    required this.arabicName,
    required this.englishName,
    required this.rangeLabel,
  });

  static ReadingTimeSlot fromHour(int hour) {
    if (hour >= 4 && hour < 9) return ReadingTimeSlot.fajrMorning;
    if (hour >= 9 && hour < 14) return ReadingTimeSlot.forenoonNoon;
    if (hour >= 14 && hour < 18) return ReadingTimeSlot.asrAfternoon;
    if (hour >= 18 && hour < 22) return ReadingTimeSlot.maghribIsha;
    return ReadingTimeSlot.nightQiyam;
  }
}

/// A single progress checkpoint recorded when the user marks an Ayah in a Khatma.
class KhatmaProgressEntry {
  final int? id;
  final int khatmaId;
  final int ayahGlobalId; // 1..6236
  final int surahId;
  final int ayahNumber;
  final String verseKey;
  final String surahNameArabic;
  final int pageNumber;
  final int juzNumber;
  final DateTime recordedAt;
  final String? notes;

  const KhatmaProgressEntry({
    this.id,
    required this.khatmaId,
    required this.ayahGlobalId,
    required this.surahId,
    required this.ayahNumber,
    required this.verseKey,
    required this.surahNameArabic,
    required this.pageNumber,
    required this.juzNumber,
    required this.recordedAt,
    this.notes,
  });

  factory KhatmaProgressEntry.fromMap(Map<String, dynamic> map) {
    return KhatmaProgressEntry(
      id: map['id'] as int?,
      khatmaId: map['khatma_id'] as int,
      ayahGlobalId: map['ayah_global_id'] as int,
      surahId: map['surah_id'] as int,
      ayahNumber: map['ayah_number'] as int,
      verseKey: map['verse_key'] as String,
      surahNameArabic: (map['surah_name_arabic'] as String?) ?? '',
      pageNumber: map['page_number'] as int,
      juzNumber: map['juz_number'] as int,
      recordedAt:
          DateTime.tryParse(map['recorded_at'] as String? ?? '') ??
          DateTime.now(),
      notes: map['notes'] as String?,
    );
  }
}

/// Represents a Quran Khatma (reading cycle from beginning to end).
/// Includes open `metadata` map for future Khatma extensions (daily Wird targets, reminders, etc.).
class KhatmaRecord {
  final int id;
  final int serialNumber;
  final String title;
  final KhatmaStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final Map<String, dynamic> metadata;
  final List<KhatmaProgressEntry> logs; // Ordered newest first

  const KhatmaRecord({
    required this.id,
    required this.serialNumber,
    required this.title,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.metadata = const <String, dynamic>{},
    this.logs = const <KhatmaProgressEntry>[],
  });

  /// Localized display title: auto-generated titles ("الختمة رقم N") are shown
  /// as "Khatma #N" in English; custom titles are shown as typed.
  String get displayTitle {
    final isDefault = title.startsWith('الختمة رقم');
    if (!isDefault) return title;
    return tr(
      'الختمة رقم ${ArabicUtils.toArabicDigits(serialNumber)}',
      'Khatma #$serialNumber',
    );
  }

  bool get isActive => status == KhatmaStatus.active;
  bool get isCompleted => status == KhatmaStatus.completed;

  /// The current (latest) location reached in this Khatma, or null if no mark has been placed yet.
  KhatmaProgressEntry? get currentMark => logs.isNotEmpty ? logs.first : null;

  /// The previous known location before [currentMark], if any.
  KhatmaProgressEntry? get previousMark => logs.length > 1 ? logs[1] : null;

  /// Completion ratio (0.0 .. 1.0) based on global Ayah index (out of 6,236).
  double get progressRatio {
    if (isCompleted) return 1.0;
    final mark = currentMark;
    if (mark == null) return 0.0;
    return (mark.ayahGlobalId / 6236.0).clamp(0.0, 1.0);
  }

  int get reachedAyahsCount {
    if (isCompleted) return 6236;
    return currentMark?.ayahGlobalId ?? 0;
  }

  int get reachedPageNumber {
    if (isCompleted) return 604;
    return currentMark?.pageNumber ?? 1;
  }

  int get reachedJuzNumber {
    if (isCompleted) return 30;
    return currentMark?.juzNumber ?? 1;
  }

  factory KhatmaRecord.fromMap(
    Map<String, dynamic> map, {
    List<KhatmaProgressEntry> logs = const <KhatmaProgressEntry>[],
  }) {
    Map<String, dynamic> parsedMeta = const <String, dynamic>{};
    final rawMeta = map['metadata_json'] as String?;
    if (rawMeta != null && rawMeta.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMeta);
        if (decoded is Map<String, dynamic>) {
          parsedMeta = decoded;
        }
      } catch (_) {}
    }

    return KhatmaRecord(
      id: map['id'] as int,
      serialNumber: map['serial_number'] as int,
      title: (map['title'] as String?) ?? '',
      status: KhatmaStatus.fromString((map['status'] as String?) ?? 'active'),
      startedAt:
          DateTime.tryParse(map['started_at'] as String? ?? '') ??
          DateTime.now(),
      completedAt: map['completed_at'] != null
          ? DateTime.tryParse(map['completed_at'] as String)
          : null,
      metadata: parsedMeta,
      logs: logs,
    );
  }
}

/// Comprehensive statistical report generated upon completing (or inspecting) a Khatma.
class KhatmaReport {
  final int khatmaId;
  final int serialNumber;
  final DateTime startedAt;
  final DateTime completedAt;
  final Duration exactDuration;
  final double durationInDays;
  final int calendarDaysSpan;
  final int totalCheckpoints;
  final double averageAyahsPerDay;
  final double averagePagesPerDay;
  final double averageJuzPerDay;
  final ReadingTimeSlot usualReadingSlot;
  final int peakReadingHour; // 0..23
  final Map<ReadingTimeSlot, int> slotDistribution;
  final DateTime? estimatedCompletionDate;
  final int? estimatedRemainingDays;
  final int totalLettersRead;
  final int estimatedHasanat;

  const KhatmaReport({
    required this.khatmaId,
    required this.serialNumber,
    required this.startedAt,
    required this.completedAt,
    required this.exactDuration,
    required this.durationInDays,
    required this.calendarDaysSpan,
    required this.totalCheckpoints,
    required this.averageAyahsPerDay,
    required this.averagePagesPerDay,
    required this.averageJuzPerDay,
    required this.usualReadingSlot,
    required this.peakReadingHour,
    required this.slotDistribution,
    this.estimatedCompletionDate,
    this.estimatedRemainingDays,
    this.totalLettersRead = 0,
    this.estimatedHasanat = 0,
  });
}
