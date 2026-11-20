import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/mushaf_models.dart';
import '../services/font_loader_service.dart';
import '../services/mushaf_system_service.dart';
import '../services/quran_audio_service.dart';
import '../state/mushaf_controller.dart';
import '../theme/mushaf_theme.dart';
import '../utils/arabic_utils.dart';
import '../widgets/surah_header_banner.dart';

/// Sharing format chosen by the user.
enum AyahShareFormat {
  decoratedImage,
  videoWithRecitation,
  textWithTashkeel,
  plainTextNoTashkeel,
}

/// Opens the modal sheet allowing the user to select how many ayahs to share
/// starting from [initialAyah] and choose between:
/// 1. Decorated Image card (PNG)
/// 2. Decorated Video with Recitation (lightweight MP4 with reciter voice & ambient light effect)
/// 3. Plain Text with Tashkeel
/// 4. Plain Text without Tashkeel
Future<void> showShareAyahsSheet(
  BuildContext context, {
  required MushafController controller,
  required AyahRecord initialAyah,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _ShareAyahsSheet(controller: controller, initialAyah: initialAyah),
  );
}

class _ShareAyahsSheet extends StatefulWidget {
  final MushafController controller;
  final AyahRecord initialAyah;

  const _ShareAyahsSheet({required this.controller, required this.initialAyah});

  @override
  State<_ShareAyahsSheet> createState() => _ShareAyahsSheetState();
}

class _ShareAyahsSheetState extends State<_ShareAyahsSheet>
    with SingleTickerProviderStateMixin {
  static const int _maxTextOrImageAyahs = 15;
  static const int _maxVideoRecitationAyahs = 7;

  final GlobalKey _cardBoundaryKey = GlobalKey();
  late final AnimationController _ambientLightController;

  late int _remainingInSurah;
  int _selectedCount = 1;
  AyahShareFormat _format = AyahShareFormat.decoratedImage;
  late MushafThemeType _cardThemeType;
  late QuranReciter _selectedReciter;

  List<AyahRecord> _ayahs = const <AyahRecord>[];
  bool _loadingAyahs = true;
  bool _sharing = false;
  bool _cancelRequested = false;
  double _shareProgress = 0.0;
  String? _shareProgressStatus;

  int get _effectiveMaxCount {
    final cap = _format == AyahShareFormat.videoWithRecitation
        ? _maxVideoRecitationAyahs
        : _maxTextOrImageAyahs;
    return math.min(_remainingInSurah, cap);
  }

  bool get _isVisualCardFormat =>
      _format == AyahShareFormat.decoratedImage ||
      _format == AyahShareFormat.videoWithRecitation;

  @override
  void initState() {
    super.initState();
    _cardThemeType = widget.controller.themeType;
    _selectedReciter = widget.controller.selectedReciter;
    _ambientLightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    final surahInfo = widget.controller.getSurahById(
      widget.initialAyah.surahId,
    );
    final totalInSurah = surahInfo?.ayahCount ?? widget.initialAyah.ayahNumber;
    _remainingInSurah = math.max(
      1,
      totalInSurah - widget.initialAyah.ayahNumber + 1,
    );
    _ayahs = <AyahRecord>[widget.initialAyah];
    _loadSelectedRange(1);
  }

  @override
  void dispose() {
    if (_sharing) {
      _cancelRequested = true;
      MushafSystemService.instance.cancelRecitationVideo();
    }
    _ambientLightController.dispose();
    super.dispose();
  }

  Future<void> _handleCancelSharing() async {
    if (!_sharing) return;
    setState(() {
      _cancelRequested = true;
      _shareProgressStatus = tr(
        'جاري إلغاء تجهيز الفيديو...',
        'Canceling video preparation...',
        'ویڈیو کی تیاری منسوخ کی جا رہی ہے...',
      );
    });
    await MushafSystemService.instance.cancelRecitationVideo();
  }

  void _selectFormat(AyahShareFormat newFormat) {
    if (_format == newFormat) return;
    setState(() {
      _format = newFormat;
    });
    if (_selectedCount > _effectiveMaxCount) {
      _loadSelectedRange(_effectiveMaxCount);
    }
  }

  Future<void> _loadSelectedRange(int count) async {
    final clamped = count.clamp(1, _effectiveMaxCount);
    setState(() {
      _selectedCount = clamped;
      _loadingAyahs = true;
    });
    final fetched = await widget.controller.getAyahRangeInSurah(
      surahId: widget.initialAyah.surahId,
      startAyahNumber: widget.initialAyah.ayahNumber,
      count: clamped,
    );
    final list = fetched.isNotEmpty
        ? fetched
        : <AyahRecord>[widget.initialAyah];
    // Ensure QPC page fonts are loaded for all pages spanned by the selected ayahs
    final pages = list.map((a) => a.pageNumber).toSet();
    await Future.wait(
      pages.map((p) => QpcFontLoaderService.instance.ensurePageFontLoaded(p)),
    );
    if (!mounted) return;
    setState(() {
      _ayahs = list;
      _loadingAyahs = false;
    });
  }

  SurahInfo? get _surahInfo =>
      widget.controller.getSurahById(widget.initialAyah.surahId);

  String get _surahDisplayName {
    final info = _surahInfo;
    if (info != null) return L10n.surahName(info);
    return widget.initialAyah.surahNameArabic;
  }

  String get _ayahRangeLabel {
    final first = _ayahs.first.ayahNumber;
    final last = _ayahs.last.ayahNumber;
    if (first == last) {
      return tr(
        'الآية ${L10n.n(first)}',
        'Ayah ${L10n.n(first)}',
        'آیت ${L10n.n(first)}',
      );
    }
    return tr(
      'الآيات ${L10n.n(first)} - ${L10n.n(last)}',
      'Ayahs ${L10n.n(first)}–${L10n.n(last)}',
      'آیات ${L10n.n(first)} تا ${L10n.n(last)}',
    );
  }

  String get _juzAndPageLabel {
    final firstJuz = _ayahs.first.juzNumber;
    final lastJuz = _ayahs.last.juzNumber;
    final firstPage = _ayahs.first.pageNumber;
    final lastPage = _ayahs.last.pageNumber;

    final juzPart = firstJuz == lastJuz
        ? tr(
            'الجزء ${L10n.n(firstJuz)}',
            'Juz ${L10n.n(firstJuz)}',
            'پارہ ${L10n.n(firstJuz)}',
          )
        : tr(
            'الأجزاء ${L10n.n(firstJuz)}-${L10n.n(lastJuz)}',
            'Juz ${L10n.n(firstJuz)}–${L10n.n(lastJuz)}',
            'پارہ ${L10n.n(firstJuz)}-${L10n.n(lastJuz)}',
          );

    final pagePart = firstPage == lastPage
        ? tr(
            'صفحة ${L10n.n(firstPage)}',
            'Page ${L10n.n(firstPage)}',
            'صفحہ ${L10n.n(firstPage)}',
          )
        : tr(
            'ص ${L10n.n(firstPage)}-${L10n.n(lastPage)}',
            'pp. ${L10n.n(firstPage)}–${L10n.n(lastPage)}',
            'صفحہ ${L10n.n(firstPage)}-${L10n.n(lastPage)}',
          );

    return '$juzPart • $pagePart';
  }

  String get _metadataFooterLine {
    final surahTitle = tr(
      'سورة $_surahDisplayName',
      'Surah $_surahDisplayName',
      'سورۃ $_surahDisplayName',
    );
    return '[$surahTitle | $_ayahRangeLabel | $_juzAndPageLabel]';
  }

  String _buildFormattedShareText({required bool withTashkeel}) {
    final buf = StringBuffer();
    for (int i = 0; i < _ayahs.length; i++) {
      final a = _ayahs[i];
      final verseText = withTashkeel
          ? a.textUthmani.trim()
          : ArabicUtils.stripTashkeelForSharing(
              a.textUthmani,
              textClean: a.textClean,
            );
      if (i > 0) buf.write(' ');
      buf.write('$verseText ﴿${ArabicUtils.toArabicDigits(a.ayahNumber)}﴾');
    }
    return '﴿ ${buf.toString()} ﴾\n\n$_metadataFooterLine';
  }

  Future<Uint8List?> _captureCardPngBytes() async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final boundary =
        _cardBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final ui.Image img = await boundary.toImage(pixelRatio: 3.0);
    final ByteData? byteData = await img.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData?.buffer.asUint8List();
  }

  Future<void> _handleShareNow() async {
    if (_sharing || _loadingAyahs) return;
    setState(() {
      _sharing = true;
      _cancelRequested = false;
      _shareProgress = 0.05;
      _shareProgressStatus = null;
    });

    try {
      if (_format == AyahShareFormat.textWithTashkeel) {
        final text = _buildFormattedShareText(withTashkeel: true);
        await MushafSystemService.instance.shareText(text);
      } else if (_format == AyahShareFormat.plainTextNoTashkeel) {
        final text = _buildFormattedShareText(withTashkeel: false);
        await MushafSystemService.instance.shareText(text);
      } else if (_format == AyahShareFormat.decoratedImage) {
        final pngBytes = await _captureCardPngBytes();
        if (pngBytes == null) return;
        await MushafSystemService.instance.shareImageBytes(
          pngBytes,
          caption: _metadataFooterLine,
        );
      } else if (_format == AyahShareFormat.videoWithRecitation) {
        // Step 1: Capture the decorated card (which includes the Reciter badge)
        setState(() {
          _shareProgress = 0.10;
          _shareProgressStatus = tr(
            'جاري تجهيز بطاقة الآيات المزخرفة...',
            'Preparing decorated ayah card...',
            'آیات کا کارڈ تیار کیا جا رہا ہے...',
          );
        });
        final pngBytes = await _captureCardPngBytes();
        if (pngBytes == null || _cancelRequested) return;

        // Step 2: Download/verify MP3 recitation files for the selected ayahs
        final totalAyahs = _ayahs.length;
        final audioPaths = await QuranAudioService.instance.ensureAyahRangeAudioFiles(
          ayahs: _ayahs,
          reciter: _selectedReciter,
          isCancelled: () => _cancelRequested || !mounted,
          onProgress: (completed, total) {
            if (!mounted || _cancelRequested) return;
            final frac = total > 0 ? (completed / total) : 1.0;
            setState(() {
              _shareProgress = 0.12 + (frac * 0.58);
              _shareProgressStatus = tr(
                'جاري تحميل التلاوة الصوتية (${L10n.n(completed)} / ${L10n.n(totalAyahs)})...',
                'Loading audio recitation ($completed / $totalAyahs)...',
                'تلاوت ڈاؤن لوڈ ہو رہی ہے (${L10n.n(completed)} / ${L10n.n(totalAyahs)})...',
              );
            });
          },
        );

        if (_cancelRequested) return;

        if (audioPaths == null || audioPaths.isEmpty) {
          if (!mounted) return;
          final theme = widget.controller.theme;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: theme.hudSurface,
                content: Directionality(
                  textDirection: L10n.dir,
                  child: Text(
                    tr(
                      'تعذر تحميل تلاوة الآيات. يرجى التحقق من الاتصال بالإنترنت.',
                      'Unable to download ayah recitation. Please check your internet connection.',
                      'تلاوت ڈاؤن لوڈ نہیں ہو سکی۔ براہ کرم انٹرنیٹ کنکشن چیک کریں۔',
                    ),
                    style: TextStyle(color: theme.hudText),
                  ),
                ),
              ),
            );
          return;
        }

        // Step 3: Mux the card image + ambient light effect + audio into a lightweight MP4
        if (!mounted || _cancelRequested) return;
        setState(() {
          _shareProgress = 0.72;
          _shareProgressStatus = tr(
            'جاري دمج الصورة مع التلاوة وإنشاء فيديو MP4 خفيف...',
            'Creating lightweight MP4 video with recitation...',
            'تلاوت کے ساتھ ہلکی MP4 ویڈیو بنائی جا رہی ہے...',
          );
        });

        final ok = await MushafSystemService.instance
            .createAndShareRecitationVideo(
              pngBytes: pngBytes,
              audioFilePaths: audioPaths,
              caption: _metadataFooterLine,
              onProgress: (progress) {
                if (!mounted || _cancelRequested) return;
                setState(() {
                  _shareProgress = progress.clamp(0.72, 1.0);
                });
              },
            );

        if (!ok && !_cancelRequested && mounted) {
          final theme = widget.controller.theme;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: theme.hudSurface,
                content: Directionality(
                  textDirection: L10n.dir,
                  child: Text(
                    tr(
                      'تعذر إنشاء فيديو التلاوة.',
                      'Could not create recitation video.',
                      'تلاوت کی ویڈیو نہیں بن سکی۔',
                    ),
                    style: TextStyle(color: theme.hudText),
                  ),
                ),
              ),
            );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _sharing = false;
          _cancelRequested = false;
          _shareProgress = 0.0;
          _shareProgressStatus = null;
        });
      }
    }
  }

  Future<void> _handleCopyText() async {
    final withTashkeel = _format != AyahShareFormat.plainTextNoTashkeel;
    final text = _buildFormattedShareText(withTashkeel: withTashkeel);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    final theme = widget.controller.theme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1600),
          behavior: SnackBarBehavior.floating,
          backgroundColor: theme.hudSurface,
          content: Directionality(
            textDirection: L10n.dir,
            child: Text(
              tr(
                'تم نسخ الآيات مع بيانات السورة والجزء إلى الحافظة',
                'Ayahs and Surah/Juz details copied to clipboard',
                'آیات اور سورۃ/پارہ کی تفصیلات کاپی ہو گئیں',
              ),
              style: TextStyle(color: theme.hudText),
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.controller.theme;
    final cardTheme = MushafThemeData.fromType(_cardThemeType);
    final maxCount = _effectiveMaxCount;
    final presetCounts = <int>{
      1,
      2,
      3,
      5,
      7,
      10,
      maxCount,
    }.where((c) => c >= 1 && c <= maxCount).toList()..sort();

    return Directionality(
      textDirection: L10n.dir,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.91,
        ),
        decoration: BoxDecoration(
          color: theme.pageBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: theme.pageOuterBorder, width: 1.5),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.secondaryTextColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 14, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.ios_share_rounded,
                            color: theme.ornamentPrimary,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr(
                                    'مشاركة آية أو آيات من المصحف',
                                    'Share Ayah / Ayat',
                                    'قرآن کی آیت یا آیات شیئر کریں',
                                  ),
                                  style: TextStyle(
                                    color: theme.glyphColor,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${tr('سورة $_surahDisplayName', 'Surah $_surahDisplayName', 'سورۃ $_surahDisplayName')} • $_ayahRangeLabel • $_juzAndPageLabel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.secondaryTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.glyphColor),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: theme.pageInnerBorder.withValues(alpha: 0.5),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Number of Ayahs selector
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.ornamentFill,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: theme.pageInnerBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tr(
                                          'عدد الآيات للمشاركة (بداية من الآية ${L10n.n(widget.initialAyah.ayahNumber)})',
                                          'Number of Ayahs (from Ayah ${L10n.n(widget.initialAyah.ayahNumber)})',
                                          'آیات کی تعداد (آیت ${L10n.n(widget.initialAyah.ayahNumber)} سے)',
                                        ),
                                        style: TextStyle(
                                          color: theme.glyphColor,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$_ayahRangeLabel • $_juzAndPageLabel',
                                        style: TextStyle(
                                          color: theme.ornamentPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    _StepperIconButton(
                                      icon: Icons.remove_rounded,
                                      enabled: _selectedCount > 1 && !_sharing,
                                      theme: theme,
                                      onTap: () => _loadSelectedRange(
                                        _selectedCount - 1,
                                      ),
                                    ),
                                    Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 42,
                                      ),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        L10n.n(_selectedCount),
                                        style: TextStyle(
                                          color: theme.glyphColor,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    _StepperIconButton(
                                      icon: Icons.add_rounded,
                                      enabled:
                                          _selectedCount < maxCount &&
                                          !_sharing,
                                      theme: theme,
                                      onTap: () => _loadSelectedRange(
                                        _selectedCount + 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (presetCounts.length > 1) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: presetCounts.map((count) {
                                  final isSel = _selectedCount == count;
                                  final label = count == 1
                                      ? tr('آية واحدة', '1 Ayah', '١ آیت')
                                      : count == 2
                                      ? tr('آيتان', '2 Ayahs', '٢ آیات')
                                      : tr(
                                          '${L10n.n(count)} آيات',
                                          '$count Ayahs',
                                          '${L10n.n(count)} آیات',
                                        );
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: _sharing
                                        ? null
                                        : () => _loadSelectedRange(count),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSel
                                            ? theme.ornamentPrimary
                                            : theme.pageBackground,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSel
                                              ? theme.ornamentPrimary
                                              : theme.pageInnerBorder,
                                        ),
                                      ),
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          color: isSel
                                              ? Colors.white
                                              : theme.glyphColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            if (_format ==
                                AyahShareFormat.videoWithRecitation) ...[
                              const SizedBox(height: 6),
                              Text(
                                tr(
                                  '• الحد الأقصى للفيديو بالتلاوة ${L10n.n(_maxVideoRecitationAyahs)} آيات للحفاظ على خفة وسرعة ملف الفيديو (MP4).',
                                  '• Video recitation is capped at $_maxVideoRecitationAyahs ayahs to keep the MP4 lightweight and fast.',
                                  '• ویڈیو تلاوت کے لیے زیادہ سے زیادہ ${L10n.n(_maxVideoRecitationAyahs)} آیات منتخب کی جا سکتی ہیں تاکہ ویڈیو ہلکی رہے۔',
                                ),
                                style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. 4-Way Share Format Selector (2x2 Grid)
                      Text(
                        tr(
                          'صيغة المشاركة',
                          'Share Format',
                          'شیئر کرنے کا انداز',
                        ),
                        style: TextStyle(
                          color: theme.glyphColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _FormatOptionButton(
                            icon: Icons.image_rounded,
                            label: tr(
                              'صورة مزخرفة',
                              'Decorated Image',
                              'خوبصورت تصویر',
                            ),
                            isSelected:
                                _format == AyahShareFormat.decoratedImage,
                            theme: theme,
                            onTap: _sharing
                                ? () {}
                                : () => _selectFormat(
                                    AyahShareFormat.decoratedImage,
                                  ),
                          ),
                          const SizedBox(width: 8),
                          _FormatOptionButton(
                            icon: Icons.videocam_rounded,
                            label: tr(
                              'فيديو بالتلاوة',
                              'Video Recitation',
                              'تلاوت والی ویڈیو',
                            ),
                            isSelected:
                                _format == AyahShareFormat.videoWithRecitation,
                            theme: theme,
                            onTap: _sharing
                                ? () {}
                                : () => _selectFormat(
                                    AyahShareFormat.videoWithRecitation,
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _FormatOptionButton(
                            icon: Icons.text_fields_rounded,
                            label: tr(
                              'نص بالتشكيل',
                              'Text (Tashkeel)',
                              'اعراب کے ساتھ متن',
                            ),
                            isSelected:
                                _format == AyahShareFormat.textWithTashkeel,
                            theme: theme,
                            onTap: _sharing
                                ? () {}
                                : () => _selectFormat(
                                    AyahShareFormat.textWithTashkeel,
                                  ),
                          ),
                          const SizedBox(width: 8),
                          _FormatOptionButton(
                            icon: Icons.notes_rounded,
                            label: tr(
                              'نص بدون تشكيل',
                              'Plain Text',
                              'سادہ متن',
                            ),
                            isSelected:
                                _format == AyahShareFormat.plainTextNoTashkeel,
                            theme: theme,
                            onTap: _sharing
                                ? () {}
                                : () => _selectFormat(
                                    AyahShareFormat.plainTextNoTashkeel,
                                  ),
                          ),
                        ],
                      ),

                      // Reciter selector when Video with Recitation is selected
                      if (_format == AyahShareFormat.videoWithRecitation) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.ornamentFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.pageInnerBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.mic_rounded,
                                    size: 17,
                                    color: theme.ornamentPrimary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    tr(
                                      'القارئ في الفيديو:',
                                      'Video Reciter:',
                                      'ویڈیو کے قاری:',
                                    ),
                                    style: TextStyle(
                                      color: theme.glyphColor,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: QuranReciter.values.map((reciter) {
                                    final isSel = _selectedReciter == reciter;
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: _sharing
                                            ? null
                                            : () {
                                                setState(
                                                  () => _selectedReciter =
                                                      reciter,
                                                );
                                                widget.controller
                                                    .setSelectedReciter(
                                                      reciter,
                                                    );
                                              },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSel
                                                ? const Color(0xFF2B8A62)
                                                : theme.pageBackground,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: isSel
                                                  ? const Color(0xFF2B8A62)
                                                  : theme.pageInnerBorder,
                                            ),
                                          ),
                                          child: Text(
                                            reciter.shortDisplayName,
                                            style: TextStyle(
                                              color: isSel
                                                  ? Colors.white
                                                  : theme.glyphColor,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (_isVisualCardFormat) ...[
                        const SizedBox(height: 10),
                        // Quick theme selector for the decorated image/video card
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: MushafThemeData.all.map((t) {
                            final isSel = t.type == _cardThemeType;
                            final label = switch (t.type) {
                              MushafThemeType.warmPaper => tr(
                                'ورق المصحف',
                                'Warm Paper',
                                'مصحف پیپر',
                              ),
                              MushafThemeType.crispWhite => tr(
                                'أبيض ناصع',
                                'Crisp White',
                                'سفید',
                              ),
                              MushafThemeType.amoledDark => tr(
                                'داكن فخم',
                                'Royal Dark',
                                'ڈارک',
                              ),
                            };
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () =>
                                    setState(() => _cardThemeType = t.type),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: t.pageBackground,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isSel
                                          ? theme.ornamentPrimary
                                          : theme.pageInnerBorder,
                                      width: isSel ? 2.0 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isSel) ...[
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 14,
                                          color: t.ornamentPrimary,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        label,
                                        style: TextStyle(
                                          color: t.glyphColor,
                                          fontSize: 11.5,
                                          fontWeight: isSel
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // 3. Live Preview (Decorated Card or Plain Text Box)
                      if (_loadingAyahs)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_isVisualCardFormat)
                        Stack(
                          children: [
                            RepaintBoundary(
                              key: _cardBoundaryKey,
                              child: _DecoratedAyahShareCard(
                                ayahs: _ayahs,
                                surahInfo: _surahInfo,
                                surahDisplayName: _surahDisplayName,
                                ayahRangeLabel: _ayahRangeLabel,
                                juzAndPageLabel: _juzAndPageLabel,
                                theme: cardTheme,
                                isIndoPak: widget.controller.isIndoPakScript,
                                reciter:
                                    _format ==
                                        AyahShareFormat.videoWithRecitation
                                    ? _selectedReciter
                                    : null,
                              ),
                            ),
                            // Live preview of the gentle ambient golden light effect in Video mode
                            if (_format == AyahShareFormat.videoWithRecitation)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: AnimatedBuilder(
                                    animation: _ambientLightController,
                                    builder: (context, _) {
                                      final v = _ambientLightController.value;
                                      return Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          gradient: RadialGradient(
                                            center: Alignment(
                                              0.45 * math.cos(v * math.pi),
                                              0.35 * math.sin(v * math.pi),
                                            ),
                                            radius: 0.85,
                                            colors: [
                                              const Color(
                                                0xFFF5CC5C,
                                              ).withValues(
                                                alpha: 0.06 + 0.06 * v,
                                              ),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.ornamentFill,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: theme.ornamentPrimary.withValues(
                                alpha: 0.6,
                              ),
                              width: 1.3,
                            ),
                          ),
                          child: SelectableText(
                            _buildFormattedShareText(
                              withTashkeel:
                                  _format == AyahShareFormat.textWithTashkeel,
                            ),
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.glyphColor,
                              fontSize: 18,
                              height: 1.75,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      // Progress indicator card during audio download & MP4 encoding
                      if (_sharing && _shareProgressStatus != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2B8A62,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF2B8A62),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Color(0xFF2B8A62),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _shareProgressStatus!,
                                      style: TextStyle(
                                        color: theme.glyphColor,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${L10n.n((_shareProgress * 100).round())}%',
                                    style: const TextStyle(
                                      color: Color(0xFF2B8A62),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: _shareProgress.clamp(0.05, 1.0),
                                  minHeight: 6,
                                  backgroundColor: theme.pageBackground,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF2B8A62),
                                      ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: theme.bookmarkRibbon,
                                    side: BorderSide(
                                      color: theme.bookmarkRibbon,
                                      width: 1.2,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: _cancelRequested
                                      ? null
                                      : _handleCancelSharing,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    tr('إلغاء', 'Cancel', 'منسوخ کریں'),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // 4. Primary Share & Copy Action Buttons
                      Row(
                        children: [
                          if (!_isVisualCardFormat) ...[
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: theme.glyphColor,
                                  side: BorderSide(
                                    color: theme.ornamentPrimary,
                                    width: 1.4,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _sharing ? null : _handleCopyText,
                                icon: const Icon(Icons.copy_rounded, size: 19),
                                label: Text(
                                  tr('نسخ النص', 'Copy Text', 'متن کاپی کریں'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2B8A62),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _sharing ? null : _handleShareNow,
                              icon: _sharing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      _format ==
                                              AyahShareFormat
                                                  .videoWithRecitation
                                          ? Icons.movie_creation_rounded
                                          : Icons.ios_share_rounded,
                                      size: 20,
                                    ),
                              label: Text(
                                switch (_format) {
                                  AyahShareFormat.decoratedImage => tr(
                                    'مشاركة الصورة المزخرفة',
                                    'Share Decorated Image',
                                    'خوبصورت تصویر شیئر کریں',
                                  ),
                                  AyahShareFormat.videoWithRecitation => tr(
                                    'إنشاء ومشاركة الفيديو بالتلاوة',
                                    'Create & Share Recitation Video',
                                    'تلاوت والی ویڈیو بنائیں اور شیئر کریں',
                                  ),
                                  _ => tr(
                                    'مشاركة النص عبر التطبيقات',
                                    'Share Text via Apps',
                                    'متن شیئر کریں',
                                  ),
                                },
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperIconButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final MushafThemeData theme;
  final VoidCallback onTap;

  const _StepperIconButton({
    required this.icon,
    required this.enabled,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled ? theme.ornamentPrimary : theme.pageBackground,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: enabled ? theme.ornamentPrimary : theme.pageInnerBorder,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? Colors.white
              : theme.secondaryTextColor.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _FormatOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final MushafThemeData theme;
  final VoidCallback onTap;

  const _FormatOptionButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.ornamentPrimary.withValues(alpha: 0.16)
                : theme.ornamentFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? theme.ornamentPrimary : theme.pageInnerBorder,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: isSelected
                    ? theme.ornamentPrimary
                    : theme.secondaryTextColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected
                        ? theme.glyphColor
                        : theme.secondaryTextColor,
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Illuminated Mushaf-style card rendered to a high-resolution PNG image
/// (or used as the visual frame of the recitation MP4 video).
/// Displays:
/// - Ornamental double-ruled Islamic frame with corner medallions
/// - Calligraphic Surah Header Banner
/// - Surah Name, Ayah number(s), and Juz & Page details
/// - Optional Basmala
/// - Authentic Quranic verses with ornamental verse markers
/// - Optional Reciter Badge (when sharing a video with recitation)
/// - Bottom metadata cartouche
class _DecoratedAyahShareCard extends StatelessWidget {
  final List<AyahRecord> ayahs;
  final SurahInfo? surahInfo;
  final String surahDisplayName;
  final String ayahRangeLabel;
  final String juzAndPageLabel;
  final MushafThemeData theme;
  final bool isIndoPak;
  final QuranReciter? reciter;

  const _DecoratedAyahShareCard({
    required this.ayahs,
    required this.surahInfo,
    required this.surahDisplayName,
    required this.ayahRangeLabel,
    required this.juzAndPageLabel,
    required this.theme,
    required this.isIndoPak,
    this.reciter,
  });

  @override
  Widget build(BuildContext context) {
    final first = ayahs.first;
    final showBasmala =
        first.surahId != 9 && !(first.surahId == 1 && first.ayahNumber == 1);

    final double fontSize = ayahs.length <= 2
        ? 25.0
        : ayahs.length <= 5
        ? 22.0
        : ayahs.length <= 9
        ? 19.5
        : 17.5;

    final spans = <InlineSpan>[];
    for (int i = 0; i < ayahs.length; i++) {
      final a = ayahs[i];
      if (isIndoPak) {
        spans.add(
          TextSpan(
            text: '${a.textUthmani.trim()} ',
            style: TextStyle(
              fontFamily: 'IndoPak',
              fontSize: fontSize,
              height: 1.95,
              color: theme.glyphColor,
            ),
          ),
        );
        spans.add(
          TextSpan(
            text: '﴿${ArabicUtils.toArabicDigits(a.ayahNumber)}﴾ ',
            style: TextStyle(
              fontFamily: 'IndoPak',
              fontSize: fontSize * 0.90,
              height: 1.95,
              color: theme.ornamentPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      } else {
        final pageFont = QpcFontLoaderService.fontFamilyForPage(a.pageNumber);
        final hasQpc =
            QpcFontLoaderService.instance.isPageFontLoaded(a.pageNumber) &&
            a.qpcV1Glyphs.trim().isNotEmpty;
        if (hasQpc) {
          spans.add(
            TextSpan(
              text: '${a.qpcV1Glyphs.trim()} ',
              style: TextStyle(
                fontFamily: pageFont,
                fontSize: fontSize * 1.12,
                height: 1.85,
                color: theme.glyphColor,
              ),
            ),
          );
        } else {
          spans.add(
            TextSpan(
              text:
                  '${a.textUthmani.trim()} ﴿${ArabicUtils.toArabicDigits(a.ayahNumber)}﴾ ',
              style: TextStyle(
                fontSize: fontSize,
                height: 1.9,
                color: theme.glyphColor,
              ),
            ),
          );
        }
      }
    }

    return CustomPaint(
      painter: _DecoratedShareCardPainter(
        pageBackground: theme.pageBackground,
        outerBorder: theme.pageOuterBorder,
        innerBorder: theme.pageInnerBorder,
        ornamentPrimary: theme.ornamentPrimary,
        ornamentSecondary: theme.ornamentSecondary,
        ornamentFill: theme.ornamentFill,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Metadata Bar (Juz & Page on one side, Ayah Range on the other)
            Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      juzAndPageLabel,
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      ayahRangeLabel,
                      style: TextStyle(
                        color: theme.ornamentPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),

            // 2. Authentic Ornamental Surah Header Banner
            SizedBox(
              height: 52,
              child: SurahHeaderBanner(
                surahId: first.surahId,
                headerText: first.surahNameArabic,
                surahInfo: surahInfo,
                theme: theme,
                openingSpreadStyle: true,
              ),
            ),

            // 3. Calligraphic Basmala
            if (showBasmala) ...[
              const SizedBox(height: 10),
              Center(
                child: Text(
                  '\uE000',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: 'QPC1BSML',
                    fontSize: 28,
                    height: 1.05,
                    color: theme.glyphColor,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // 4. Illuminated Ayah(s) Text Body
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: RichText(
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  text: TextSpan(children: spans),
                ),
              ),
            ),

            // 5. Ornamental Reciter Badge (shown when sharing Video with Recitation)
            if (reciter != null) ...[
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B8A62).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF2B8A62),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.graphic_eq_rounded,
                        size: 16,
                        color: Color(0xFF2B8A62),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          tr(
                            'تلاوة: ${reciter!.arabicName}',
                            'Recitation: ${reciter!.displayName}',
                            'تلاوت: ${reciter!.arabicName}',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.glyphColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // 6. Ornamental Bottom Footer Cartouche with Surah, Ayah(s), Juz, and App Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.ornamentFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.ornamentPrimary.withValues(alpha: 0.65),
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${tr('سورة $surahDisplayName', 'Surah $surahDisplayName', 'سورۃ $surahDisplayName')} • $ayahRangeLabel • $juzAndPageLabel',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.glyphColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'مصحف الختمة • Khatma Mushaf',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.ornamentPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecoratedShareCardPainter extends CustomPainter {
  final Color pageBackground;
  final Color outerBorder;
  final Color innerBorder;
  final Color ornamentPrimary;
  final Color ornamentSecondary;
  final Color ornamentFill;

  const _DecoratedShareCardPainter({
    required this.pageBackground,
    required this.outerBorder,
    required this.innerBorder,
    required this.ornamentPrimary,
    required this.ornamentSecondary,
    required this.ornamentFill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;
    final bgRRect = RRect.fromRectAndRadius(
      fullRect,
      const Radius.circular(18),
    );

    // Background fill
    final bgPaint = Paint()
      ..color = pageBackground
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bgRRect, bgPaint);

    // Outer gold border
    final outerRect = fullRect.deflate(5.0);
    final outerRRect = RRect.fromRectAndRadius(
      outerRect,
      const Radius.circular(14),
    );
    final outerPaint = Paint()
      ..color = outerBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawRRect(outerRRect, outerPaint);

    // Subtle frame band fill between outer and inner border
    final midRect = outerRect.deflate(4.0);
    final midRRect = RRect.fromRectAndRadius(
      midRect,
      const Radius.circular(11),
    );
    final bandPath = Path()
      ..addRRect(outerRRect)
      ..addRRect(midRRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      bandPath,
      Paint()
        ..color = ornamentFill
        ..style = PaintingStyle.fill,
    );

    // Inner double-rule border
    final innerPaint = Paint()
      ..color = innerBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawRRect(midRRect, innerPaint);

    // 4 Corner floral rosettes
    final corners = <Offset>[
      Offset(outerRect.left + 8, outerRect.top + 8),
      Offset(outerRect.right - 8, outerRect.top + 8),
      Offset(outerRect.left + 8, outerRect.bottom - 8),
      Offset(outerRect.right - 8, outerRect.bottom - 8),
    ];
    final dotPaint = Paint()
      ..color = ornamentPrimary
      ..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..color = ornamentSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (final c in corners) {
      canvas.drawCircle(c, 4.2, Paint()..color = pageBackground);
      canvas.drawCircle(c, 4.2, ringPaint);
      canvas.drawCircle(c, 2.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DecoratedShareCardPainter oldDelegate) {
    return oldDelegate.pageBackground != pageBackground ||
        oldDelegate.outerBorder != outerBorder ||
        oldDelegate.ornamentPrimary != ornamentPrimary;
  }
}
