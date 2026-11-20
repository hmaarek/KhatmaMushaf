import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../l10n/l10n.dart';
import '../models/mushaf_models.dart';

/// Famous Quran reciters for Full Ayah playback.
enum QuranReciter {
  husaryMurattal(
    id: 'husary_murattal',
    arabicName: 'الشيخ محمود خليل الحصري (مرتل)',
    shortArabicName: 'الحصري (مرتل)',
    everyAyahFolder: 'Husary_128kbps',
    quranFoundationPath: 'Husary_128kbps',
  ),
  husaryMuallim(
    id: 'husary_muallim',
    arabicName: 'الشيخ محمود خليل الحصري (المصحف المعلم)',
    shortArabicName: 'الحصري (المعلم)',
    everyAyahFolder: 'Husary_Muallim_128kbps',
    quranFoundationPath: 'Husary_Muallim_128kbps',
  ),
  minshawiMurattal(
    id: 'minshawi_murattal',
    arabicName: 'الشيخ محمد صديق المنشاوي (مرتل)',
    shortArabicName: 'المنشاوي (مرتل)',
    everyAyahFolder: 'Minshawy_Murattal_128kbps',
    quranFoundationPath: 'Minshawy_Murattal_128kbps',
  ),
  alafasy(
    id: 'alafasy',
    arabicName: 'الشيخ مشاري راشد العفاسي',
    shortArabicName: 'مشاري العفاسي',
    everyAyahFolder: 'Alafasy_128kbps',
    quranFoundationPath: 'Alafasy/mp3',
  ),
  abdulBasitMurattal(
    id: 'abdul_basit',
    arabicName: 'الشيخ عبد الباسط عبد الصمد (مرتل)',
    shortArabicName: 'عبد الباسط (مرتل)',
    everyAyahFolder: 'Abdul_Basit_Murattal_192kbps',
    quranFoundationPath: 'AbdulBaset/Mujawwad/mp3',
  );

  final String id;
  final String arabicName;
  final String shortArabicName;
  final String everyAyahFolder;
  final String quranFoundationPath;

  String get displayName => tr(arabicName, switch (this) {
    QuranReciter.husaryMurattal => 'Sheikh Mahmoud Khalil Al-Husary (Murattal)',
    QuranReciter.husaryMuallim => 'Sheikh Mahmoud Khalil Al-Husary (Muallim)',
    QuranReciter.minshawiMurattal =>
      'Sheikh Muhammad Siddiq Al-Minshawi (Murattal)',
    QuranReciter.alafasy => 'Sheikh Mishary Rashid Al-Afasy',
    QuranReciter.abdulBasitMurattal =>
      'Sheikh Abdul Basit Abdul Samad (Murattal)',
  });

  String get shortDisplayName => tr(shortArabicName, switch (this) {
    QuranReciter.husaryMurattal => 'Al-Husary (Murattal)',
    QuranReciter.husaryMuallim => 'Al-Husary (Muallim)',
    QuranReciter.minshawiMurattal => 'Al-Minshawi (Murattal)',
    QuranReciter.alafasy => 'Al-Afasy',
    QuranReciter.abdulBasitMurattal => 'Abdul Basit (Murattal)',
  });

  const QuranReciter({
    required this.id,
    required this.arabicName,
    required this.shortArabicName,
    required this.everyAyahFolder,
    required this.quranFoundationPath,
  });
}

enum QuranAudioState {
  idle,
  loadingWord,
  playingWord,
  loadingAyah,
  playingAyah,
  error,
}

class QuranAudioService extends ChangeNotifier {
  QuranAudioService._() {
    _channel.setMethodCallHandler(_handleNativeCallback);
  }

  static final QuranAudioService instance = QuranAudioService._();

  static const MethodChannel _channel = MethodChannel('com.mushaf.app/audio');

  QuranAudioState _state = QuranAudioState.idle;
  LineWord? _activeWord;
  String? _activeVerseKey;
  int? _activeSurahId;
  int? _activeAyahNumber;
  String? _statusMessage;
  bool _usedOfflineTtsFallback = false;

  int _playbackCounter = 0;
  bool _pendingAutoPlayAyah = false;
  QuranReciter _pendingReciter = QuranReciter.husaryMurattal;
  String? _pendingAyahFallbackText;

  String? _cacheRootPath;

  QuranAudioState get state => _state;
  LineWord? get activeWord => _activeWord;
  String? get activeVerseKey => _activeVerseKey;
  int? get activeSurahId => _activeSurahId;
  int? get activeAyahNumber => _activeAyahNumber;
  String? get statusMessage => _statusMessage;
  bool get usedOfflineTtsFallback => _usedOfflineTtsFallback;

  bool get isBusy =>
      _state == QuranAudioState.loadingWord ||
      _state == QuranAudioState.loadingAyah;

  bool get isPlaying =>
      _state == QuranAudioState.playingWord ||
      _state == QuranAudioState.playingAyah;

  bool get isPlayingWord =>
      _state == QuranAudioState.loadingWord ||
      _state == QuranAudioState.playingWord;

  bool get isPlayingAyah =>
      _state == QuranAudioState.loadingAyah ||
      _state == QuranAudioState.playingAyah;

  bool get hasActivePanel => _activeWord != null || _activeVerseKey != null;

  Future<String> _ensureCacheDir(String subFolder) async {
    _cacheRootPath ??= p.join(await getDatabasesPath(), 'quran_audio_cache');
    final dir = Directory(p.join(_cacheRootPath!, subFolder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    if (call.method == 'onPlaybackCompleted') {
      final args = call.arguments;
      int? finishedId;
      if (args is Map) {
        finishedId = args['playbackId'] as int?;
      }
      if (finishedId != null && finishedId != _playbackCounter) {
        return;
      }

      if (_state == QuranAudioState.playingWord &&
          _pendingAutoPlayAyah &&
          _activeSurahId != null &&
          _activeAyahNumber != null) {
        _pendingAutoPlayAyah = false;
        await playFullAyah(
          surahId: _activeSurahId!,
          ayahNumber: _activeAyahNumber!,
          reciter: _pendingReciter,
          fallbackTextUthmani: _pendingAyahFallbackText,
          keepActiveWord: true,
        );
        return;
      }

      _state = QuranAudioState.idle;
      _statusMessage = null;
      notifyListeners();
    }
  }

  /// Plays the exact Quranic Word-by-Word pronunciation for [word].
  /// If [autoPlayAyahAfter] is true, automatically transitions to playing
  /// the Full Ayah with [reciter] right after the word finishes reciting.
  Future<void> playWord(
    LineWord word, {
    required bool autoPlayAyahAfter,
    required QuranReciter reciter,
    String? ayahFallbackText,
  }) async {
    final myPlaybackId = ++_playbackCounter;
    _activeWord = word;
    _activeVerseKey = word.verseKey;
    _activeSurahId = word.surahId;
    _activeAyahNumber = word.ayahNumber;
    _pendingAutoPlayAyah = autoPlayAyahAfter;
    _pendingReciter = reciter;
    _pendingAyahFallbackText = ayahFallbackText;
    _usedOfflineTtsFallback = false;
    _state = QuranAudioState.loadingWord;
    _statusMessage = tr(
      'جاري تحميل نطق الكلمة...',
      'Loading word pronunciation...',
    );
    notifyListeners();

    final s3 = word.surahId.toString().padLeft(3, '0');
    final a3 = word.ayahNumber.toString().padLeft(3, '0');
    final w3 = word.wordNumberInAyah.toString().padLeft(3, '0');
    final fileName = '${s3}_${a3}_$w3.mp3';

    final urls = <String>[
      'https://audio.qurancdn.com/wbw/$fileName',
      'https://verses.quran.foundation/wbw/$fileName',
    ];

    try {
      final cacheDir = await _ensureCacheDir('wbw');
      final filePath = p.join(cacheDir, fileName);
      final downloaded = await _ensureAudioFile(filePath: filePath, urls: urls);

      if (myPlaybackId != _playbackCounter) return;

      if (downloaded) {
        _state = QuranAudioState.playingWord;
        _statusMessage = autoPlayAyahAfter
            ? tr(
                'جاري نطق الكلمة (يتبعها تلاوة الآية)...',
                'Pronouncing word (followed by ayah)...',
              )
            : tr('جاري نطق الكلمة...', 'Pronouncing word...');
        notifyListeners();

        await _channel.invokeMethod('playFile', {
          'path': filePath,
          'playbackId': myPlaybackId,
        });
      } else {
        // Offline TTS fallback for the vocalized word
        _usedOfflineTtsFallback = true;
        _state = QuranAudioState.playingWord;
        _statusMessage = tr(
          'نطق صوتي محلي (بدون اتصال بالإنترنت)',
          'Offline speech (no internet)',
        );
        notifyListeners();

        await _channel.invokeMethod('speakArabic', {
          'text': word.cleanWordUthmani,
          'playbackId': myPlaybackId,
          'rate': 0.38,
        });
      }
    } catch (_) {
      if (myPlaybackId != _playbackCounter) return;
      _state = QuranAudioState.error;
      _statusMessage = tr(
        'تعذر تشغيل الصوت، يرجى التحقق من الاتصال بالإنترنت',
        'Unable to play audio. Please check your internet connection.',
      );
      notifyListeners();
    }
  }

  /// Plays the full Ayah recitation for [surahId] : [ayahNumber] using [reciter].
  Future<void> playFullAyah({
    required int surahId,
    required int ayahNumber,
    required QuranReciter reciter,
    String? fallbackTextUthmani,
    bool keepActiveWord = false,
  }) async {
    final myPlaybackId = ++_playbackCounter;
    if (!keepActiveWord) {
      _activeWord = null;
    }
    _activeSurahId = surahId;
    _activeAyahNumber = ayahNumber;
    _activeVerseKey = '$surahId:$ayahNumber';
    _pendingAutoPlayAyah = false;
    _usedOfflineTtsFallback = false;
    _state = QuranAudioState.loadingAyah;
    _statusMessage = tr(
      'جاري تحميل تلاوة الآية (${reciter.shortArabicName})...',
      'Loading ayah recitation (${reciter.shortDisplayName})...',
    );
    notifyListeners();

    final s3 = surahId.toString().padLeft(3, '0');
    final a3 = ayahNumber.toString().padLeft(3, '0');
    final fileName = '$s3$a3.mp3';

    final urls = <String>[
      'https://everyayah.com/data/${reciter.everyAyahFolder}/$fileName',
      'https://verses.quran.foundation/${reciter.quranFoundationPath}/$fileName',
    ];

    try {
      final cacheDir = await _ensureCacheDir('ayahs_${reciter.id}');
      final filePath = p.join(cacheDir, fileName);
      final downloaded = await _ensureAudioFile(filePath: filePath, urls: urls);

      if (myPlaybackId != _playbackCounter) return;

      if (downloaded) {
        _state = QuranAudioState.playingAyah;
        _statusMessage = tr(
          'تلاوة الآية • ${reciter.shortArabicName}',
          'Reciting ayah • ${reciter.shortDisplayName}',
        );
        notifyListeners();

        await _channel.invokeMethod('playFile', {
          'path': filePath,
          'playbackId': myPlaybackId,
        });
      } else if (fallbackTextUthmani != null &&
          fallbackTextUthmani.trim().isNotEmpty) {
        _usedOfflineTtsFallback = true;
        _state = QuranAudioState.playingAyah;
        _statusMessage = tr(
          'قراءة محلية للآية (بدون إنترنت)',
          'Offline ayah speech (no internet)',
        );
        notifyListeners();

        await _channel.invokeMethod('speakArabic', {
          'text': fallbackTextUthmani,
          'playbackId': myPlaybackId,
          'rate': 0.42,
        });
      } else {
        _state = QuranAudioState.error;
        _statusMessage = tr(
          'يتطلب تشغيل تلاوة الآية الاتصال بالإنترنت للمرة الأولى',
          'Internet connection required for first-time ayah recitation',
        );
        notifyListeners();
      }
    } catch (_) {
      if (myPlaybackId != _playbackCounter) return;
      _state = QuranAudioState.error;
      _statusMessage = tr(
        'تعذر تشغيل تلاوة الآية',
        'Unable to play ayah recitation',
      );
      notifyListeners();
    }
  }

  /// Stops any active audio playback immediately.
  Future<void> stop({bool clearSelection = false}) async {
    _playbackCounter++;
    _pendingAutoPlayAyah = false;
    _state = QuranAudioState.idle;
    _statusMessage = null;
    if (clearSelection) {
      _activeWord = null;
      _activeVerseKey = null;
      _activeSurahId = null;
      _activeAyahNumber = null;
    }
    notifyListeners();

    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }

  /// Ensures the `.mp3` recitation files for [ayahs] with [reciter] are
  /// downloaded and cached locally, reporting progress via [onProgress].
  /// Returns the ordered list of local file paths, or `null` if any file
  /// could not be fetched (e.g. no internet connection for an uncached ayah).
  Future<List<String>?> ensureAyahRangeAudioFiles({
    required List<AyahRecord> ayahs,
    required QuranReciter reciter,
    void Function(int completed, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final cacheDir = await _ensureCacheDir('ayahs_${reciter.id}');
    final paths = <String>[];
    final total = ayahs.length;
    onProgress?.call(0, total);

    for (int i = 0; i < total; i++) {
      if (isCancelled?.call() == true) {
        return null;
      }
      final ayah = ayahs[i];
      final s3 = ayah.surahId.toString().padLeft(3, '0');
      final a3 = ayah.ayahNumber.toString().padLeft(3, '0');
      final fileName = '$s3$a3.mp3';
      final filePath = p.join(cacheDir, fileName);
      final urls = <String>[
        'https://everyayah.com/data/${reciter.everyAyahFolder}/$fileName',
        'https://verses.quran.foundation/${reciter.quranFoundationPath}/$fileName',
      ];
      final ok = await _ensureAudioFile(filePath: filePath, urls: urls);
      if (isCancelled?.call() == true || !ok) {
        return null;
      }
      paths.add(filePath);
      onProgress?.call(i + 1, total);
    }
    return paths;
  }

  Future<bool> _ensureAudioFile({
    required String filePath,
    required List<String> urls,
  }) async {
    final file = File(filePath);
    if (await file.exists()) {
      final length = await file.length();
      if (length > 256) {
        return true;
      }
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 7);
    try {
      for (final urlStr in urls) {
        try {
          final uri = Uri.parse(urlStr);
          final req = await client.getUrl(uri);
          final resp = await req.close().timeout(const Duration(seconds: 10));
          if (resp.statusCode == 200) {
            final bytes = await consolidateHttpClientResponseBytes(resp);
            if (bytes.length > 256) {
              final tempFile = File('$filePath.tmp');
              await tempFile.writeAsBytes(bytes, flush: true);
              await tempFile.rename(filePath);
              return true;
            }
          }
        } catch (_) {
          // Try next fallback URL
        }
      }
    } finally {
      client.close(force: true);
    }
    return false;
  }
}
