import 'dart:io';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/khatma_models.dart';

/// Handles platform system integrations via `com.mushaf.app/system`:
/// 1. Opening external URLs (such as the Help YouTube video).
/// 2. Scheduling / canceling the 24-hour Khatma reading reminder notification.
class MushafSystemService {
  MushafSystemService._() {
    _channel.setMethodCallHandler(_handleNativeCallback);
  }
  static final MushafSystemService instance = MushafSystemService._();

  static const MethodChannel _channel = MethodChannel('com.mushaf.app/system');

  void Function(double progress)? _activeVideoProgressCallback;

  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    if (call.method == 'onVideoProgress') {
      final args = call.arguments;
      if (args is Map && args['progress'] is num) {
        final p = (args['progress'] as num).toDouble().clamp(0.0, 1.0);
        _activeVideoProgressCallback?.call(p);
      }
    }
  }

  /// Language-specific YouTube tutorial URLs.
  static const String helpYoutubeUrlAr = 'https://youtu.be/tmzo2asUEIU';
  static const String helpYoutubeUrlEn =
      'https://youtube.com/shorts/3ZGP-RqtvYE';
  static const String helpYoutubeUrlUr =
      'https://youtube.com/shorts/4wVwTujVAmU';

  /// Returns the tutorial YouTube URL matching [lang].
  static String helpYoutubeUrlForLanguage(AppLanguage lang) => switch (lang) {
    AppLanguage.arabic => helpYoutubeUrlAr,
    AppLanguage.english => helpYoutubeUrlEn,
    AppLanguage.urdu => helpYoutubeUrlUr,
  };

  /// Opens [url] in the external browser or YouTube app.
  Future<bool> openExternalUrl(String url) async {
    try {
      final ok = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Syncs the 24-hour Khatma inactivity notification with [activeKhatma].
  ///
  /// - If [activeKhatma] is null (or completed), cancels any pending reminder.
  /// - If [activeKhatma] is active, schedules a localized reminder for 24 hours
  ///   after the user's last Khatma progress mark (or Khatma start time if no
  ///   mark has been placed yet).
  Future<void> syncKhatmaReminder(KhatmaRecord? activeKhatma) async {
    if (activeKhatma == null || !activeKhatma.isActive) {
      await cancelKhatmaReminder();
      return;
    }

    final DateTime lastActivity =
        activeKhatma.currentMark?.recordedAt ?? activeKhatma.startedAt;
    final DateTime nextFireTime = lastActivity.add(const Duration(hours: 24));
    final DateTime now = DateTime.now();

    // If less than 24h has passed since last activity, fire at (lastActivity + 24h).
    // If 24h has already elapsed while the app was closed, schedule the next 24h cycle.
    int delaySeconds = nextFireTime.difference(now).inSeconds;
    if (delaySeconds < 60) {
      delaySeconds = 86400;
    }

    final title = tr(
      'حان وقت وردك القرآني في مصحف الختمة 📖',
      'Time for your Quran Khatma reading 📖',
      'تلاوتِ قرآن اور ختمہ کا وقت 📖',
    );
    final body = tr(
      'مرّت ٢٤ ساعة منذ آخر علامة في ختمتك. لا تحرم قلبك نور القرآن اليوم ولو بصفحة واحدة — ﴿فَاقْرَؤُوا مَا تَيَسَّرَ مِنَ الْقُرْآنِ﴾.',
      '24 hours have passed since you last marked your Khatma progress. Illuminate your heart with the Quran today, even with a single page — "So recite what is easy for you of the Quran."',
      'آپ کے ختمہ میں آخری نشان لگائے ٢٤ گھنٹے گزر چکے ہیں۔ آج اپنے دل کو قرآن کے نور سے منور کریں، چاہے ایک ہی صفحہ پڑھیں — ﴿فَاقْرَؤُوا مَا تَيَسَّرَ مِنَ الْقُرْآنِ﴾۔',
    );

    try {
      await _channel.invokeMethod<bool>('scheduleKhatmaReminder', {
        'title': title,
        'body': body,
        'delaySeconds': delaySeconds,
      });
    } catch (_) {
      // Ignore in headless/test environments
    }
  }

  /// Cancels any pending Khatma inactivity notification.
  Future<void> cancelKhatmaReminder() async {
    try {
      await _channel.invokeMethod<bool>('cancelKhatmaReminder');
    } catch (_) {
      // Ignore in headless/test environments
    }
  }

  /// Opens the native OS Share Sheet to share plain [text] across other apps.
  Future<bool> shareText(String text) async {
    try {
      final ok = await _channel.invokeMethod<bool>('shareText', {'text': text});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Writes [pngBytes] to a temporary `.png` file and opens the native OS
  /// Share Sheet to share the decorated Ayah image across other apps.
  Future<bool> shareImageBytes(Uint8List pngBytes, {String? caption}) async {
    try {
      final tmpDir = Directory.systemTemp;
      final filePath =
          '${tmpDir.path}/khatma_mushaf_ayah_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes, flush: true);
      final ok = await _channel.invokeMethod<bool>('shareImage', {
        'path': file.path,
        if (caption != null && caption.isNotEmpty) 'caption': caption,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Combines the rendered card [pngBytes] and the ordered [audioFilePaths]
  /// into a lightweight `.mp4` video with a subtle ambient light effect,
  /// and opens the native OS Share Sheet.
  Future<bool> createAndShareRecitationVideo({
    required Uint8List pngBytes,
    required List<String> audioFilePaths,
    String? caption,
    void Function(double progress)? onProgress,
  }) async {
    _activeVideoProgressCallback = onProgress;
    try {
      final tmpDir = Directory.systemTemp;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final imgFile = File('${tmpDir.path}/khatma_mushaf_card_$ts.png');
      await imgFile.writeAsBytes(pngBytes, flush: true);

      final ok = await _channel
          .invokeMethod<bool>('createAndShareRecitationVideo', {
            'imagePath': imgFile.path,
            'audioPaths': audioFilePaths,
            if (caption != null && caption.isNotEmpty) 'caption': caption,
          });
      return ok ?? false;
    } catch (_) {
      return false;
    } finally {
      _activeVideoProgressCallback = null;
    }
  }

  /// Cancels an in-progress native recitation video export immediately.
  Future<void> cancelRecitationVideo() async {
    try {
      await _channel.invokeMethod<bool>('cancelRecitationVideo');
    } catch (_) {}
  }
}
