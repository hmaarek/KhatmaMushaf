class SurahInfo {
  final int id;
  final String nameArabic;
  final String nameArabicLong;
  final String nameEnglish;
  final String nameTranslation;
  final String revelationPlace; // 'Meccan' or 'Medinan'
  final int ayahCount;
  final int startPage;
  final int endPage;
  final bool bismillahPre;

  const SurahInfo({
    required this.id,
    required this.nameArabic,
    required this.nameArabicLong,
    required this.nameEnglish,
    required this.nameTranslation,
    required this.revelationPlace,
    required this.ayahCount,
    required this.startPage,
    required this.endPage,
    required this.bismillahPre,
  });

  String get surahCode => id.toString().padLeft(3, '0');
  bool get isMeccan => revelationPlace.toLowerCase() == 'meccan';
  String get revelationArabic => isMeccan ? 'مكية' : 'مدنية';

  factory SurahInfo.fromMap(Map<String, dynamic> map) {
    return SurahInfo(
      id: map['id'] as int,
      nameArabic: map['name_arabic'] as String,
      nameArabicLong: map['name_arabic_long'] as String,
      nameEnglish: map['name_english'] as String,
      nameTranslation: map['name_translation'] as String,
      revelationPlace: map['revelation_place'] as String,
      ayahCount: map['ayah_count'] as int,
      startPage: map['start_page'] as int,
      endPage: map['end_page'] as int,
      bismillahPre: (map['bismillah_pre'] as int) == 1,
    );
  }
}

class JuzInfo {
  final int id;
  final String nameArabic;
  final int startPage;
  final int endPage;
  final int startSurah;
  final int startAyah;
  final String startSurahNameArabic;
  final String startSurahNameEnglish;

  const JuzInfo({
    required this.id,
    required this.nameArabic,
    required this.startPage,
    required this.endPage,
    required this.startSurah,
    required this.startAyah,
    required this.startSurahNameArabic,
    required this.startSurahNameEnglish,
  });

  factory JuzInfo.fromMap(Map<String, dynamic> map) {
    return JuzInfo(
      id: map['id'] as int,
      nameArabic: map['name_arabic'] as String,
      startPage: map['start_page'] as int,
      endPage: map['end_page'] as int,
      startSurah: map['start_surah'] as int,
      startAyah: map['start_ayah'] as int,
      startSurahNameArabic: map['start_surah_name_arabic'] as String,
      startSurahNameEnglish: map['start_surah_name_english'] as String,
    );
  }
}

class MushafPageInfo {
  final int pageNumber;
  final int juzNumber;
  final int hizbNumber;
  final int firstSurahId;
  final int firstAyahNumber;
  final int lastSurahId;
  final int lastAyahNumber;
  final String surahNamesArabic;
  final String surahNamesEnglish;
  final bool isCentered;

  const MushafPageInfo({
    required this.pageNumber,
    required this.juzNumber,
    required this.hizbNumber,
    required this.firstSurahId,
    required this.firstAyahNumber,
    required this.lastSurahId,
    required this.lastAyahNumber,
    required this.surahNamesArabic,
    required this.surahNamesEnglish,
    required this.isCentered,
  });

  factory MushafPageInfo.fromMap(Map<String, dynamic> map) {
    return MushafPageInfo(
      pageNumber: map['page_number'] as int,
      juzNumber: map['juz_number'] as int,
      hizbNumber: map['hizb_number'] as int,
      firstSurahId: map['first_surah_id'] as int,
      firstAyahNumber: map['first_ayah_number'] as int,
      lastSurahId: map['last_surah_id'] as int,
      lastAyahNumber: map['last_ayah_number'] as int,
      surahNamesArabic: map['surah_names_arabic'] as String,
      surahNamesEnglish: map['surah_names_english'] as String,
      isCentered: (map['is_centered'] as int) == 1,
    );
  }
}

class LineWord {
  final int wordIndex;
  final String location;
  final int surahId;
  final int ayahNumber;
  final String verseKey;
  final String wordUthmani;
  final String qpcV1;

  const LineWord({
    required this.wordIndex,
    required this.location,
    required this.surahId,
    required this.ayahNumber,
    required this.verseKey,
    required this.wordUthmani,
    required this.qpcV1,
  });

  factory LineWord.fromMap(Map<String, dynamic> map) {
    return LineWord(
      wordIndex: map['word_index'] as int,
      location: map['location'] as String,
      surahId: map['surah_id'] as int,
      ayahNumber: map['ayah_number'] as int,
      verseKey: map['verse_key'] as String,
      wordUthmani: map['word_uthmani'] as String,
      qpcV1: map['qpc_v1'] as String,
    );
  }
}

class MushafPageLine {
  final int pageNumber;
  final int lineNumber;
  final String lineType; // 'surah-header', 'basmala', 'text'
  final int? surahId;
  final String? headerText;
  final String? qpcV1Text;
  final String? uthmaniText;
  final String? verseRange;
  final List<LineWord> words;

  const MushafPageLine({
    required this.pageNumber,
    required this.lineNumber,
    required this.lineType,
    this.surahId,
    this.headerText,
    this.qpcV1Text,
    this.uthmaniText,
    this.verseRange,
    this.words = const [],
  });

  bool get isSurahHeader => lineType == 'surah-header';
  bool get isBasmala => lineType == 'basmala';
  bool get isText => lineType == 'text';
  String get surahCode => (surahId ?? 1).toString().padLeft(3, '0');
}

class MushafPageData {
  final MushafPageInfo info;
  final List<MushafPageLine> lines;

  const MushafPageData({
    required this.info,
    required this.lines,
  });
}

class AyahRecord {
  final int id;
  final int surahId;
  final int ayahNumber;
  final String verseKey;
  final int pageNumber;
  final int juzNumber;
  final int hizbNumber;
  final String textUthmani;
  final String textClean;
  final String qpcV1Glyphs;
  final String surahNameArabic;
  final String surahNameEnglish;

  const AyahRecord({
    required this.id,
    required this.surahId,
    required this.ayahNumber,
    required this.verseKey,
    required this.pageNumber,
    required this.juzNumber,
    required this.hizbNumber,
    required this.textUthmani,
    required this.textClean,
    required this.qpcV1Glyphs,
    required this.surahNameArabic,
    required this.surahNameEnglish,
  });

  factory AyahRecord.fromMap(Map<String, dynamic> map) {
    return AyahRecord(
      id: map['id'] as int,
      surahId: map['surah_id'] as int,
      ayahNumber: map['ayah_number'] as int,
      verseKey: map['verse_key'] as String,
      pageNumber: map['page_number'] as int,
      juzNumber: map['juz_number'] as int,
      hizbNumber: map['hizb_number'] as int,
      textUthmani: map['text_uthmani'] as String,
      textClean: map['text_clean'] as String,
      qpcV1Glyphs: map['qpc_v1_glyphs'] as String,
      surahNameArabic: (map['surah_name_arabic'] as String?) ?? '',
      surahNameEnglish: (map['surah_name_english'] as String?) ?? '',
    );
  }
}

class BookmarkItem {
  final int? id;
  final String type; // 'page' or 'ayah'
  final int pageNumber;
  final int surahId;
  final int? ayahNumber;
  final String? verseKey;
  final String title;
  final String? snippet;
  final DateTime createdAt;

  const BookmarkItem({
    this.id,
    required this.type,
    required this.pageNumber,
    required this.surahId,
    this.ayahNumber,
    this.verseKey,
    required this.title,
    this.snippet,
    required this.createdAt,
  });

  bool get isPageBookmark => type == 'page';
  bool get isAyahBookmark => type == 'ayah';

  factory BookmarkItem.fromMap(Map<String, dynamic> map) {
    return BookmarkItem(
      id: map['id'] as int?,
      type: map['type'] as String,
      pageNumber: map['page_number'] as int,
      surahId: map['surah_id'] as int,
      ayahNumber: map['ayah_number'] as int?,
      verseKey: map['verse_key'] as String?,
      title: map['title'] as String,
      snippet: map['snippet'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
