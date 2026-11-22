import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/mushaf_models.dart';
import '../services/quran_audio_service.dart';
import '../state/mushaf_controller.dart';
import '../widgets/mushaf_page_widget.dart';
import '../widgets/reader_hud_overlay.dart';
import '../widgets/surah_header_banner.dart';
import 'ayah_explanation_sheet.dart';
import 'bookmarks_sheet.dart';
import 'index_sheet.dart';
import 'khatma_sheet.dart';
import 'onboarding_screen.dart';
import 'search_sheet.dart';
import 'settings_sheet.dart';
import 'share_ayah_sheet.dart';

class ReaderScreen extends StatefulWidget {
  final MushafController controller;

  const ReaderScreen({super.key, required this.controller});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  bool _isCurrentPageZoomed = false;
  bool _showIstiadhahBanner = false;
  Timer? _istiadhahTimer;

  @override
  void dispose() {
    _istiadhahTimer?.cancel();
    super.dispose();
  }

  Future<void> _startStartupSequence() async {
    if (!mounted) return;
    if (!widget.controller.languageChosen) {
      await _showLanguageChoiceDialog();
      if (!mounted) return;
    }
    if (!widget.controller.hasCompletedOnboarding) {
      await showOnboardingIntro(context, controller: widget.controller);
      if (!mounted) return;
    }
    setState(() {
      _showIstiadhahBanner = true;
    });
    _istiadhahTimer?.cancel();
    _istiadhahTimer = Timer(const Duration(seconds: 3), () {
      _dismissIstiadhahAndShowKhatmaPrompt();
    });
  }

  Future<void> _showLanguageChoiceDialog() async {
    final theme = widget.controller.theme;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        Widget langButton(String label, AppLanguage lang, IconData icon) {
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.ornamentPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                widget.controller.setLanguage(lang);
                Navigator.of(dialogCtx).pop();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return PopScope(
          canPop: false,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AlertDialog(
              backgroundColor: theme.pageBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: theme.pageOuterBorder, width: 1.5),
              ),
              title: Column(
                children: [
                  Icon(
                    Icons.language_rounded,
                    color: theme.ornamentPrimary,
                    size: 36,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'اختر اللغة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.glyphColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Choose your language',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'زبان منتخب کریں',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  langButton(
                    'العربية',
                    AppLanguage.arabic,
                    Icons.translate_rounded,
                  ),
                  const SizedBox(height: 12),
                  langButton('English', AppLanguage.english, Icons.abc_rounded),
                  const SizedBox(height: 12),
                  langButton('اردو', AppLanguage.urdu, Icons.translate_rounded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _dismissIstiadhahAndShowKhatmaPrompt() {
    _istiadhahTimer?.cancel();
    _istiadhahTimer = null;
    if (!mounted) return;
    if (_showIstiadhahBanner) {
      setState(() {
        _showIstiadhahBanner = false;
      });
    }
    if (widget.controller.askKhatmaOnStartup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showStartupKhatmaPromptDialog(context, controller: widget.controller);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final theme = widget.controller.theme;

        if (!widget.controller.isInitialized) {
          return Scaffold(
            backgroundColor: const Color(0xFF0B2C35),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 280,
                          maxHeight: 280,
                        ),
                        child: Image.asset(
                          'assets/images/intro_cover.jpg',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(color: Color(0xFFD4AF37)),
                    const SizedBox(height: 16),
                    Text(
                      tr(
                        tr(
                          'جاري فتح المصحف الشريف...',
                          'Opening the Holy Quran...',
                        ),
                        'Opening the Holy Quran...',
                      ),
                      textDirection: L10n.dir,
                      style: const TextStyle(
                        color: Color(0xFFF3E5AB),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (!widget.controller.hasShownStartupSessionPrompt) {
          widget.controller.markStartupSessionPromptShown();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startStartupSequence();
          });
        }

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: theme.isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: theme.scaffoldBackground,
            body: Stack(
              children: [
                // 604-page navigation: RTL side-flipping PageView, or a
                // continuous smooth vertical scroll (configurable in settings)
                SafeArea(
                  child: widget.controller.verticalScroll
                      ? _VerticalMushafScroller(
                          controller: widget.controller,
                          locked: _isCurrentPageZoomed,
                          pageBuilder: (context, pageNum) => _buildMushafPage(
                            context,
                            pageNum,
                            embedded: true,
                          ),
                        )
                      : Directionality(
                          textDirection: TextDirection.rtl,
                          child: PageView.builder(
                            controller: widget.controller.pageController,
                            physics: _isCurrentPageZoomed
                                ? const NeverScrollableScrollPhysics()
                                : const PageScrollPhysics(),
                            itemCount: 604,
                            onPageChanged: (idx) {
                              if (_isCurrentPageZoomed) {
                                setState(() => _isCurrentPageZoomed = false);
                              }
                              widget.controller.onPageChanged(idx);
                            },
                            itemBuilder: (context, index) =>
                                _buildMushafPage(context, index + 1),
                          ),
                        ),
                ),

                // Floating Word Pronunciation & Full Ayah Audio Bar
                if (widget.controller.audioService.hasActivePanel)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 16,
                    child: SafeArea(
                      top: false,
                      child: _buildFloatingPronunciationBar(context),
                    ),
                  ),

                // Minimal translucent HUD (top & bottom bars)
                ReaderHudOverlay(
                  controller: widget.controller,
                  onOpenIndex: () => _openModalSheet(
                    context,
                    IndexSheet(controller: widget.controller),
                  ),
                  onOpenSearch: () => _openModalSheet(
                    context,
                    SearchSheet(controller: widget.controller),
                  ),
                  onOpenBookmarks: () => _openModalSheet(
                    context,
                    BookmarksSheet(controller: widget.controller),
                  ),
                  onOpenKhatma: () => _openModalSheet(
                    context,
                    KhatmaSheet(controller: widget.controller),
                  ),
                  onOpenSettings: () => _openModalSheet(
                    context,
                    SettingsSheet(controller: widget.controller),
                  ),
                ),

                // Decorative Startup "أعوذ بالله من الشيطان الرجيم" Artwork (2 seconds or until touched)
                if (_showIstiadhahBanner)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _dismissIstiadhahAndShowKhatmaPrompt,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.50),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 32,
                        ),
                        child: SafeArea(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.90, end: 1.0),
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: child,
                              );
                            },
                            child: IstiadhahStartupBanner(
                              theme: theme,
                              onTap: _dismissIstiadhahAndShowKhatmaPrompt,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMushafPage(
    BuildContext context,
    int pageNum, {
    bool embedded = false,
  }) {
    return MushafPageWidget(
      pageNumber: pageNum,
      controller: widget.controller,
      scrollEmbedded: embedded,
      onCenterTap: widget.controller.toggleHud,
      onWordTap: (word) => _handleWordSingleTap(context, word),
      onVerseMarkerTap: (word) => _handleVerseMarkerTap(word),
      onZoomChanged: (zoomed) {
        if (_isCurrentPageZoomed != zoomed) {
          setState(() => _isCurrentPageZoomed = zoomed);
        }
      },
      onAyahLongPress: (verseKey, tappedWord) =>
          _showAyahActionSheet(context, verseKey, tappedWord: tappedWord),
      onCompleteKhatmaTap: () => _handleCompleteKhatmaFromLastPage(context),
    );
  }

  void _openModalSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
  }

  String _enSurah(int id, String fallback) {
    final info = widget.controller.getSurahById(id);
    return info == null ? fallback : L10n.surahName(info);
  }

  Future<void> _handleWordSingleTap(BuildContext context, LineWord word) async {
    final isFirstTime = !widget.controller.hasShownSingleTapIntroDialog;
    unawaited(widget.controller.pronounceWord(word));

    if (isFirstTime && context.mounted) {
      widget.controller.markSingleTapIntroShown();
      await _showFirstTimeSingleTapDialog(context);
    }
  }

  Future<void> _handleVerseMarkerTap(LineWord word) async {
    await widget.controller.playAyahAudio(word.surahId, word.ayahNumber);
  }

  Future<void> _showFirstTimeSingleTapDialog(BuildContext context) async {
    final theme = widget.controller.theme;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return Directionality(
          textDirection: L10n.dir,
          child: AlertDialog(
            backgroundColor: theme.pageBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: theme.pageOuterBorder, width: 1.5),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.record_voice_over_rounded,
                  color: theme.ornamentPrimary,
                  size: 26,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr(
                      'ميزة نطق الكلمات بالنقر المزدوج',
                      'Double-Tap Word Pronunciation',
                      'ڈبل ٹیپ پر لفظ کا تلفظ',
                    ),
                    style: TextStyle(
                      color: theme.glyphColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              tr(
                'عند النقر مرتين (نقر مزدوج) على أي كلمة في المصحف الشريف، سيقوم التطبيق بنطق الكلمة فوراً لمساعدتك على معرفة نطقها الصحيح أثناء القراءة.\n\n'
                    '• كما يمكنك لمس رقم الآية المزخرف ﴿١﴾ للاستماع إلى تلاوة الآية كاملة.\n'
                    '• يمكنك في أي وقت تعديل هذه الميزة أو إيقاف النقر المزدوج أو تفعيل تلاوة الآية تلقائياً بعد الكلمة من خلال «الإعدادات».',
                'Double-tap any word in the Holy Quran and the app will pronounce it right away, helping you learn the correct pronunciation as you read.\n\n'
                    '• You can also tap the decorated ayah number ﴿1﴾ to hear the whole ayah recited.\n'
                    '• At any time you can turn off double-tap pronunciation, or enable automatic ayah recitation after the word, from "Settings".',
                'قرآن کریم کے کسی بھی لفظ پر دو بار ٹیپ کرنے سے ایپ فوراً اس کا صحیح تلفظ سنائے گی۔\n\n'
                    '• پوری آیت کی تلاوت سننے کے لیے آیت کے مزین نمبر ﴿١﴾ پر ٹیپ کریں۔\n'
                    '• آپ کسی بھی وقت «ترتیبات» سے ڈبل ٹیپ تلفظ بند کر سکتے ہیں یا لفظ کے بعد خودکار تلاوت فعال کر سکتے ہیں۔',
              ),
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 14,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            actions: [
              TextButton.icon(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  _openModalSheet(
                    context,
                    SettingsSheet(controller: widget.controller),
                  );
                },
                icon: Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: theme.ornamentPrimary,
                ),
                label: Text(
                  tr(tr('فتح الإعدادات', 'Open Settings'), 'Open settings'),
                  style: TextStyle(
                    color: theme.ornamentPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.ornamentPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(
                  tr(tr('حسناً، فهمت', 'Got it'), 'Got it'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showQuickReciterPicker(
    BuildContext context, {
    int? replaySurahId,
    int? replayAyahNumber,
    bool keepActiveWord = false,
  }) async {
    final theme = widget.controller.theme;
    final selected = await showModalBottomSheet<QuranReciter>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final current = widget.controller.selectedReciter;
        return Directionality(
          textDirection: L10n.dir,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: theme.pageBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border.all(color: theme.pageOuterBorder, width: 1.5),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.secondaryTextColor.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons.headphones_rounded,
                        color: theme.ornamentPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tr(
                          'اختر قارئ تلاوة الآية',
                          'Select Ayah Reciter',
                          'آیت کے قاری کا انتخاب کریں',
                        ),
                        style: TextStyle(
                          color: theme.glyphColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final reciter in QuranReciter.values) ...[
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(sheetCtx).pop(reciter),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: reciter == current
                              ? theme.ornamentPrimary.withValues(alpha: 0.14)
                              : theme.ornamentFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: reciter == current
                                ? theme.ornamentPrimary
                                : theme.pageInnerBorder,
                            width: reciter == current ? 1.6 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              reciter == current
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_off_rounded,
                              size: 20,
                              color: reciter == current
                                  ? theme.ornamentPrimary
                                  : theme.secondaryTextColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                reciter.displayName,
                                style: TextStyle(
                                  color: theme.glyphColor,
                                  fontSize: 14,
                                  fontWeight: reciter == current
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (reciter != QuranReciter.values.last)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected == null || selected == widget.controller.selectedReciter) {
      return;
    }
    widget.controller.setSelectedReciter(selected);
    if (replaySurahId != null &&
        replayAyahNumber != null &&
        widget.controller.audioService.isPlayingAyah) {
      unawaited(
        widget.controller.playAyahAudio(
          replaySurahId,
          replayAyahNumber,
          keepActiveWord: keepActiveWord,
        ),
      );
    }
  }

  Widget _buildFloatingPronunciationBar(BuildContext context) {
    final theme = widget.controller.theme;
    final audio = widget.controller.audioService;
    final activeWord = audio.activeWord;
    final surahId = audio.activeSurahId ?? activeWord?.surahId ?? 1;
    final ayahNum = audio.activeAyahNumber ?? activeWord?.ayahNumber ?? 1;
    final surahInfo = widget.controller.getSurahById(surahId);
    final surahName = surahInfo == null ? '' : L10n.surahName(surahInfo);

    return Directionality(
      textDirection: L10n.dir,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: theme.pageBackground.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.ornamentPrimary, width: 1.6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.ornamentFill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.pageInnerBorder),
                    ),
                    child: Text(
                      activeWord != null
                          ? activeWord.cleanWordUthmani
                          : tr(
                              'الآية ${L10n.n(ayahNum)}',
                              'Ayah ${L10n.n(ayahNum)}',
                            ),
                      style: TextStyle(
                        color: theme.glyphColor,
                        fontSize: activeWord != null ? 22 : 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          activeWord != null
                              ? tr(
                                  'سورة $surahName • آية ${L10n.n(ayahNum)} (كلمة ${L10n.n(activeWord.wordNumberInAyah)})',
                                  'Surah $surahName • Ayah ${L10n.n(ayahNum)} (word ${L10n.n(activeWord.wordNumberInAyah)})',
                                )
                              : tr(
                                  'سورة $surahName • تلاوة الآية ${L10n.n(ayahNum)}',
                                  'Surah $surahName • Reciting ayah ${L10n.n(ayahNum)}',
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.ornamentPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (audio.isBusy) ...[
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  color: theme.ornamentPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ] else if (audio.isPlaying) ...[
                              const Icon(
                                Icons.volume_up_rounded,
                                size: 15,
                                color: Color(0xFF2B8A62),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => _showQuickReciterPicker(
                                  context,
                                  replaySurahId: surahId,
                                  replayAyahNumber: ayahNum,
                                  keepActiveWord: activeWord != null,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          audio.statusMessage ??
                                              tr(
                                                'القارئ: ${widget.controller.selectedReciter.shortDisplayName}',
                                                'Reciter: ${widget.controller.selectedReciter.shortDisplayName}',
                                                'قاری: ${widget.controller.selectedReciter.shortDisplayName}',
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: theme.secondaryTextColor,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.arrow_drop_down_rounded,
                                        size: 16,
                                        color: theme.ornamentPrimary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.close_rounded,
                      color: theme.secondaryTextColor,
                      size: 20,
                    ),
                    onPressed: () =>
                        widget.controller.stopAudio(clearSelection: true),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (activeWord != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.glyphColor,
                          side: BorderSide(color: theme.ornamentPrimary),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () =>
                            widget.controller.pronounceWord(activeWord),
                        icon: Icon(
                          Icons.replay_rounded,
                          size: 17,
                          color: theme.ornamentPrimary,
                        ),
                        label: Text(
                          tr(tr('إعادة الكلمة', 'Replay Word'), 'Replay word'),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: audio.isPlayingAyah
                            ? const Color(0xFFB54434)
                            : const Color(0xFF2B8A62),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        if (audio.isPlayingAyah) {
                          widget.controller.stopAudio(clearSelection: false);
                        } else {
                          widget.controller.playAyahAudio(
                            surahId,
                            ayahNum,
                            keepActiveWord: activeWord != null,
                          );
                        }
                      },
                      icon: Icon(
                        audio.isPlayingAyah
                            ? Icons.stop_rounded
                            : Icons.play_circle_fill_rounded,
                        size: 18,
                      ),
                      label: Text(
                        audio.isPlayingAyah
                            ? tr(tr('إيقاف التلاوة', 'Stop'), 'Stop recitation')
                            : tr(
                                tr('تلاوة الآية كاملة', 'Play Full Ayah'),
                                'Recite full ayah',
                              ),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.ornamentPrimary,
                      side: BorderSide(color: theme.ornamentPrimary),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      showAyahExplanationSheet(
                        context,
                        controller: widget.controller,
                        verseKey: '$surahId:$ayahNum',
                        initialWord: activeWord,
                        initialTabIndex: activeWord != null ? 0 : 1,
                      );
                    },
                    icon: const Icon(Icons.menu_book_rounded, size: 17),
                    label: Text(
                      tr(
                        tr('المعنى والتفسير', 'Meaning & Tafsir'),
                        'Meaning & Tafsir',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => widget.controller.setAutoPlayAyahAfterWord(
                        !widget.controller.autoPlayAyahAfterWord,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: widget.controller.autoPlayAyahAfterWord
                              ? const Color(0xFF2B8A62).withValues(alpha: 0.15)
                              : theme.ornamentFill,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: widget.controller.autoPlayAyahAfterWord
                                ? const Color(0xFF2B8A62)
                                : theme.pageInnerBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.controller.autoPlayAyahAfterWord
                                  ? Icons.check_circle_rounded
                                  : Icons.playlist_play_rounded,
                              size: 15,
                              color: widget.controller.autoPlayAyahAfterWord
                                  ? const Color(0xFF2B8A62)
                                  : theme.secondaryTextColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tr(
                                'تشغيل تلاوة الآية كاملة تلقائياً بعد نطق الكلمة (${widget.controller.selectedReciter.shortDisplayName})',
                                'Auto-play full ayah after the word (${widget.controller.selectedReciter.shortDisplayName})',
                              ),
                              style: TextStyle(
                                color: widget.controller.autoPlayAyahAfterWord
                                    ? const Color(0xFF2B8A62)
                                    : theme.secondaryTextColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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
    );
  }

  Future<void> _handleCompleteKhatmaFromLastPage(BuildContext context) async {
    if (widget.controller.activeKhatma == null) {
      final confirmed = await _showNoActiveKhatmaConfirmationDialog(context);
      if (!context.mounted || !confirmed) return;
    }

    final completed = await widget.controller.completeActiveKhatma(
      createIfNone: true,
    );
    if (!context.mounted || completed == null) return;
    await showKhatmaReportModal(
      context,
      controller: widget.controller,
      khatma: completed,
      isJustCompletedCelebration: true,
    );
  }

  Future<bool> _showNoActiveKhatmaConfirmationDialog(
    BuildContext context,
  ) async {
    final theme = widget.controller.theme;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return Directionality(
          textDirection: L10n.dir,
          child: AlertDialog(
            backgroundColor: theme.pageBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: theme.pageOuterBorder, width: 1.5),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.ornamentPrimary,
                  size: 26,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr(
                      tr('لم يتم بدء ختمة جديدة', 'No Active Khatma'),
                      'No khatma started',
                    ),
                    style: TextStyle(
                      color: theme.glyphColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              tr(
                tr(
                  'لا توجد ختمة جارية حالياً، ولا يمكن إتمام ختمة لم يتم بدؤها مسبقاً.\n\nهل تؤكد إضافة ختمة جديدة الآن وإتمامها فوراً؟',
                  'There is no active Khatma. Do you want to create a new Khatma and mark it completed now?',
                ),
                'There is no active khatma, and a khatma cannot be completed before it is started.\n\nDo you want to add a new khatma now and complete it immediately?',
              ),
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 14.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: Text(
                  tr(tr('إلغاء', 'Cancel'), 'Cancel'),
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B8A62),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text(
                  tr(
                    tr('إضافة ختمة وإتمامها الآن', 'Add & Complete Now'),
                    'Add khatma & complete now',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      },
    );
    return result ?? false;
  }

  Future<void> _showAyahActionSheet(
    BuildContext context,
    String verseKey, {
    LineWord? tappedWord,
  }) async {
    final ayah = await widget.controller.getAyahRecord(verseKey);
    if (!context.mounted || ayah == null) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final theme = widget.controller.theme;
            final audio = widget.controller.audioService;
            final isBookmarked = widget.controller.isAyahBookmarked(
              ayah.verseKey,
            );
            final activeKhatma = widget.controller.activeKhatma;
            final isCurrentKhatmaMark = widget.controller.isKhatmaCurrentVerse(
              ayah.verseKey,
            );

            final surahInfo = widget.controller.getSurahById(ayah.surahId);
            final ayahSurahName = surahInfo != null
                ? L10n.surahName(surahInfo)
                : ayah.surahNameArabic;
            return Directionality(
              textDirection: L10n.dir,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: theme.pageBackground,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  border: Border.all(color: theme.pageOuterBorder, width: 1.5),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.secondaryTextColor.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr(
                              'سورة $ayahSurahName • الآية ${L10n.n(ayah.ayahNumber)}',
                              'Surah $ayahSurahName • Ayah ${L10n.n(ayah.ayahNumber)}',
                            ),
                            style: TextStyle(
                              color: theme.ornamentPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.ornamentFill,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.pageInnerBorder),
                            ),
                            child: Text(
                              tr(
                                'ص ${L10n.n(ayah.pageNumber)} • جزء ${L10n.n(ayah.juzNumber)}',
                                'p. ${L10n.n(ayah.pageNumber)} • Juz ${L10n.n(ayah.juzNumber)}',
                              ),
                              style: TextStyle(
                                color: theme.secondaryTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 1. Khatma Progress Mark Button at the TOP of the pop-up menu
                      if (isCurrentKhatmaMark)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.bookmarkRibbon,
                            side: BorderSide(
                              color: theme.bookmarkRibbon,
                              width: 1.4,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final updated = await widget.controller
                                .deleteCurrentKhatmaMark();
                            if (!sheetCtx.mounted) return;
                            Navigator.of(sheetCtx).pop();
                            if (!context.mounted) return;
                            final prev = updated?.currentMark;
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  duration: const Duration(milliseconds: 1800),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: theme.hudSurface,
                                  content: Directionality(
                                    textDirection: L10n.dir,
                                    child: Text(
                                      prev != null
                                          ? tr(
                                              'تم حذف علامة الختمة والعودة للموضع السابق: سورة ${prev.surahNameArabic} آية ${L10n.n(prev.ayahNumber)}',
                                              'Khatma mark removed and returned to the previous position: Surah ${_enSurah(prev.surahId, prev.surahNameArabic)} ayah ${L10n.n(prev.ayahNumber)}',
                                            )
                                          : tr(
                                              'تم حذف علامة الختمة الحالية',
                                              'Current khatma mark removed',
                                            ),
                                      style: TextStyle(color: theme.hudText),
                                    ),
                                  ),
                                ),
                              );
                          },
                          icon: const Icon(Icons.undo_rounded, size: 20),
                          label: Text(
                            tr(
                              'حذف علامة الختمة (العودة للموضع السابق)',
                              'Remove khatma mark (return to previous)',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2B8A62),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final isLastAyah =
                                ayah.id >= 6236 ||
                                (ayah.surahId == 114 && ayah.ayahNumber == 6);
                            if (activeKhatma == null && isLastAyah) {
                              Navigator.of(sheetCtx).pop();
                              if (!context.mounted) return;
                              final confirmed =
                                  await _showNoActiveKhatmaConfirmationDialog(
                                    context,
                                  );
                              if (!context.mounted || !confirmed) return;
                              final completed = await widget.controller
                                  .completeActiveKhatma(createIfNone: true);
                              if (!context.mounted || completed == null) return;
                              await showKhatmaReportModal(
                                context,
                                controller: widget.controller,
                                khatma: completed,
                                isJustCompletedCelebration: true,
                              );
                              return;
                            }

                            final res = await widget.controller.markKhatmaAyah(
                              ayah,
                            );
                            if (!sheetCtx.mounted) return;
                            Navigator.of(sheetCtx).pop();
                            if (!context.mounted) return;

                            if (res.justCompleted) {
                              await showKhatmaReportModal(
                                context,
                                controller: widget.controller,
                                khatma: res.khatma,
                                isJustCompletedCelebration: true,
                              );
                            } else {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    duration: const Duration(
                                      milliseconds: 1600,
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: theme.hudSurface,
                                    content: Directionality(
                                      textDirection: L10n.dir,
                                      child: Text(
                                        tr(
                                          'تم تحديث علامة ${res.khatma.displayTitle} عند سورة ${ayah.surahNameArabic} آية ${L10n.n(ayah.ayahNumber)}',
                                          '${res.khatma.displayTitle} mark updated at Surah $ayahSurahName ayah ${L10n.n(ayah.ayahNumber)}',
                                        ),
                                        style: TextStyle(color: theme.hudText),
                                      ),
                                    ),
                                  ),
                                );
                            }
                          },
                          icon: const Icon(Icons.flag_rounded, size: 22),
                          label: Text(
                            activeKhatma != null
                                ? tr(
                                    'تحديد كعلامة الختمة الحالية (#${L10n.n(activeKhatma.serialNumber)})',
                                    'Set as current khatma mark (#${L10n.n(activeKhatma.serialNumber)})',
                                  )
                                : tr(
                                    'بدء ختمة جديدة وتحديد هذه الآية كعلامة',
                                    'Start a new khatma and mark this ayah',
                                  ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),

                      // 2. Word Pronunciation & Full Ayah Recitation Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.ornamentFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.ornamentPrimary.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (tappedWord != null &&
                                !tappedWord.isStandaloneVerseMarker) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.record_voice_over_rounded,
                                        color: theme.ornamentPrimary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        tr(
                                          'الكلمة المحددة (رقم ${L10n.n(tappedWord.wordNumberInAyah)}):',
                                          'Selected word (#${L10n.n(tappedWord.wordNumberInAyah)}):',
                                        ),
                                        style: TextStyle(
                                          color: theme.secondaryTextColor,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.pageBackground,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: theme.ornamentPrimary,
                                      ),
                                    ),
                                    child: Text(
                                      tappedWord.cleanWordUthmani,
                                      style: TextStyle(
                                        color: theme.glyphColor,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                            ],
                            Row(
                              children: [
                                if (tappedWord != null &&
                                    !tappedWord.isStandaloneVerseMarker) ...[
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.ornamentPrimary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        widget.controller.pronounceWord(
                                          tappedWord,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.volume_up_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        tr(
                                          tr('نطق الكلمة', 'Pronounce Word'),
                                          'Pronounce word',
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          audio.isPlayingAyah &&
                                              audio.activeVerseKey ==
                                                  ayah.verseKey
                                          ? const Color(0xFFB54434)
                                          : const Color(0xFF2B8A62),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () {
                                      if (audio.isPlayingAyah &&
                                          audio.activeVerseKey ==
                                              ayah.verseKey) {
                                        widget.controller.stopAudio(
                                          clearSelection: false,
                                        );
                                      } else {
                                        widget.controller.playAyahAudio(
                                          ayah.surahId,
                                          ayah.ayahNumber,
                                          keepActiveWord: tappedWord != null,
                                        );
                                      }
                                    },
                                    icon: Icon(
                                      audio.isPlayingAyah &&
                                              audio.activeVerseKey ==
                                                  ayah.verseKey
                                          ? Icons.stop_rounded
                                          : Icons.play_circle_fill_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      audio.isPlayingAyah &&
                                              audio.activeVerseKey ==
                                                  ayah.verseKey
                                          ? tr('إيقاف الآية', 'Stop ayah')
                                          : tr(
                                              tr(
                                                'تلاوة الآية كاملة',
                                                'Play Full Ayah',
                                              ),
                                              'Recite full ayah',
                                            ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Quick Reciter Switcher right inside the Full Ayah menu
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _showQuickReciterPicker(
                                sheetCtx,
                                replaySurahId: ayah.surahId,
                                replayAyahNumber: ayah.ayahNumber,
                                keepActiveWord: tappedWord != null,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.pageBackground.withValues(
                                    alpha: 0.72,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: theme.pageInnerBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.headphones_rounded,
                                      size: 17,
                                      color: theme.ornamentPrimary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        tr(
                                          'القارئ: ${widget.controller.selectedReciter.shortDisplayName}',
                                          'Reciter: ${widget.controller.selectedReciter.shortDisplayName}',
                                          'قاری: ${widget.controller.selectedReciter.shortDisplayName}',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: theme.glyphColor,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.ornamentPrimary.withValues(
                                          alpha: 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            tr('تغيير', 'Change', 'تبدیل'),
                                            style: TextStyle(
                                              color: theme.ornamentPrimary,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: 16,
                                            color: theme.ornamentPrimary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () =>
                                  widget.controller.setAutoPlayAyahAfterWord(
                                    !widget.controller.autoPlayAyahAfterWord,
                                  ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      widget.controller.autoPlayAyahAfterWord
                                          ? Icons.check_box_rounded
                                          : Icons
                                                .check_box_outline_blank_rounded,
                                      size: 18,
                                      color:
                                          widget
                                              .controller
                                              .autoPlayAyahAfterWord
                                          ? const Color(0xFF2B8A62)
                                          : theme.secondaryTextColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        tr(
                                          'تشغيل تلاوة الآية كاملة تلقائياً بعد انتهاء نطق الكلمة (${widget.controller.selectedReciter.shortDisplayName})',
                                          'Auto-play the full ayah after the word finishes (${widget.controller.selectedReciter.shortDisplayName})',
                                        ),
                                        style: TextStyle(
                                          color: theme.secondaryTextColor,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 130),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.ornamentFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.pageInnerBorder),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            '${ayah.textUthmani} ﴿${L10n.n(ayah.ayahNumber)}﴾',
                            textDirection: L10n.dir,
                            style: TextStyle(
                              color: theme.glyphColor,
                              fontSize: 18,
                              height: 1.7,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Ayah Explanation Button (Word Meanings + Summary + Detailed Tafsir)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.ornamentPrimary,
                          backgroundColor: theme.ornamentPrimary.withValues(
                            alpha: 0.08,
                          ),
                          side: BorderSide(
                            color: theme.ornamentPrimary,
                            width: 1.4,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(sheetCtx).pop();
                          showAyahExplanationSheet(
                            context,
                            controller: widget.controller,
                            verseKey: ayah.verseKey,
                            initialWord: tappedWord,
                            initialTabIndex:
                                tappedWord != null &&
                                    !tappedWord.isStandaloneVerseMarker
                                ? 0
                                : 1,
                          );
                        },
                        icon: const Icon(Icons.menu_book_rounded, size: 20),
                        label: Text(
                          tr(
                            'معاني الكلمات وتفسير الآية (المختصر والتفصيلي)',
                            'Word meanings & ayah tafsir (brief and detailed)',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Share Ayah / Ayat Button (Decorated Image or Text with/without Tashkeel)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.ornamentPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(sheetCtx).pop();
                          showShareAyahsSheet(
                            context,
                            controller: widget.controller,
                            initialAyah: ayah,
                          );
                        },
                        icon: const Icon(Icons.ios_share_rounded, size: 20),
                        label: Text(
                          tr(
                            'مشاركة الآية أو عدة آيات (صورة مزخرفة أو نص)',
                            'Share Ayah / Ayat (Decorated Image or Text)',
                            'آیت یا آیات شیئر کریں (خوبصورت تصویر یا متن)',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isBookmarked
                                    ? theme.bookmarkRibbon
                                    : theme.glyphColor,
                                side: BorderSide(
                                  color: isBookmarked
                                      ? theme.bookmarkRibbon
                                      : theme.ornamentPrimary,
                                  width: 1.3,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                final added = await widget.controller
                                    .toggleAyahBookmark(ayah);
                                if (!sheetCtx.mounted) return;
                                Navigator.of(sheetCtx).pop();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      duration: const Duration(
                                        milliseconds: 1400,
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: theme.hudSurface,
                                      content: Directionality(
                                        textDirection: L10n.dir,
                                        child: Text(
                                          added
                                              ? tr(
                                                  tr(
                                                    'تم حفظ الآية في العلامات المرجعية',
                                                    'Ayah bookmarked',
                                                  ),
                                                  'Ayah saved to bookmarks',
                                                )
                                              : tr(
                                                  tr(
                                                    'تم إزالة الآية من العلامات المرجعية',
                                                    'Ayah removed from bookmarks',
                                                  ),
                                                  'Ayah removed from bookmarks',
                                                ),
                                          style: TextStyle(
                                            color: theme.hudText,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                              },
                              icon: Icon(
                                isBookmarked
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_add_outlined,
                                size: 20,
                              ),
                              label: Text(
                                isBookmarked
                                    ? tr('محفوظة', 'Saved')
                                    : tr('حفظ الآية', 'Save ayah'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.ornamentPrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                final formatted = tr(
                                  '﴿ ${ayah.textUthmani} ﴾ [سورة ${ayah.surahNameArabic}: ${L10n.n(ayah.ayahNumber)}]',
                                  '﴿ ${ayah.textUthmani} ﴾ [Surah $ayahSurahName: ${L10n.n(ayah.ayahNumber)}]',
                                );
                                await Clipboard.setData(
                                  ClipboardData(text: formatted),
                                );
                                if (!sheetCtx.mounted) return;
                                Navigator.of(sheetCtx).pop();
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      duration: const Duration(
                                        milliseconds: 1500,
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: theme.hudSurface,
                                      content: Directionality(
                                        textDirection: L10n.dir,
                                        child: Text(
                                          tr(
                                            'تم نسخ الآية الكريمة إلى الحافظة',
                                            'Ayah copied to clipboard',
                                          ),
                                          style: TextStyle(
                                            color: theme.hudText,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 19),
                              label: Text(
                                tr('نسخ الآية', 'Copy ayah'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
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
            );
          },
        );
      },
    );

    if (mounted && widget.controller.selectedVerseKey == verseKey) {
      widget.controller.selectVerse(null);
    }
  }
}

/// Continuous, smooth vertical scrolling through all 604 Mushaf pages.
/// Every page keeps its full 15-line layout; pages flow one after another.
class _VerticalMushafScroller extends StatefulWidget {
  final MushafController controller;
  final bool locked;
  final Widget Function(BuildContext context, int pageNumber) pageBuilder;

  const _VerticalMushafScroller({
    required this.controller,
    required this.locked,
    required this.pageBuilder,
  });

  @override
  State<_VerticalMushafScroller> createState() =>
      _VerticalMushafScrollerState();
}

class _VerticalMushafScrollerState extends State<_VerticalMushafScroller> {
  ScrollController? _scroll;
  double _extent = 0;
  bool _syncing = false;
  bool _showSnapGlow = false;
  Timer? _snapGlowTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.verticalJumpHandler = _jumpToPage;
  }

  @override
  void dispose() {
    _snapGlowTimer?.cancel();
    if (widget.controller.verticalJumpHandler == _jumpToPage) {
      widget.controller.verticalJumpHandler = null;
    }
    _scroll?.removeListener(_onScroll);
    _scroll?.dispose();
    super.dispose();
  }

  void _onSnapTriggered() {
    widget.controller.triggerSnapHaptic();
    if (!mounted) return;
    _snapGlowTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _showSnapGlow = true);
      _snapGlowTimer = Timer(const Duration(milliseconds: 260), () {
        if (mounted) {
          setState(() => _showSnapGlow = false);
        }
      });
    });
  }

  void _jumpToPage(int page) {
    final scroll = _scroll;
    if (scroll == null || !scroll.hasClients || _extent <= 0) return;
    _syncing = true;
    scroll.jumpTo((page - 1) * _extent);
    _syncing = false;
  }

  void _onScroll() {
    if (_syncing || _extent <= 0) return;
    final scroll = _scroll!;
    final idx = ((scroll.offset + _extent * 0.5) / _extent).floor().clamp(
      0,
      603,
    );
    widget.controller.onPageChanged(idx);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final mode = widget.controller.fontScaleMode;
        final heightFactor = mode == MushafFontScaleMode.pinchToZoom
            ? 1.0
            : mode.heightMultiplier;
        final extent = w > h
            ? w * MushafPageWidget.landscapePageAspect * heightFactor
            : h * heightFactor;

        final page = widget.controller.currentPage;
        if (_scroll == null) {
          _scroll = ScrollController(initialScrollOffset: (page - 1) * extent)
            ..addListener(_onScroll);
        } else if ((extent - _extent).abs() > 0.5) {
          // Rotation or zoom change: keep the same page in view.
          _syncing = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_scroll!.hasClients) _scroll!.jumpTo((page - 1) * extent);
            _syncing = false;
          });
        }
        _extent = extent;

        final ScrollPhysics activePhysics = widget.locked
            ? const NeverScrollableScrollPhysics()
            : widget.controller.verticalSnap
            ? _MushafEdgeSnapScrollPhysics(
                pageExtent: extent,
                onSnapTriggered: _onSnapTriggered,
                parent: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
              )
            : const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              );

        final theme = widget.controller.theme;
        return Stack(
          children: [
            ListView.builder(
              controller: _scroll,
              itemExtent: extent,
              itemCount: 604,
              physics: activePhysics,
              itemBuilder: (context, index) =>
                  widget.pageBuilder(context, index + 1),
            ),
            // Lightweight top-edge alignment glow pulse when a page snaps into place
            Positioned(
              top: 0,
              left: 16,
              right: 16,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _showSnapGlow ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    height: 3.0,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [
                          theme.ornamentPrimary.withValues(alpha: 0.0),
                          theme.ornamentPrimary.withValues(alpha: 0.85),
                          theme.ornamentPrimary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Custom [ScrollPhysics] for "Vertical Scroll with snap to edge":
///
/// 1. Preserves 100% natural [BouncingScrollPhysics] friction when the user
///    scrolls or flings fast across pages.
/// 2. Allows the user to deliberately stop anywhere in the middle of a page
///    (lines 2–14) without any forced snap.
/// 3. When the scroll stops (either right when the finger lifts at low/zero
///    velocity, or right when a fast friction glide finishes decelerating)
///    with less than ~1 line remaining from the top page edge, smoothly glides
///    the page edge flush to the top of the screen with a lightweight ease-out
///    animation and triggers [onSnapTriggered] (subtle haptic + edge glow).
class _MushafEdgeSnapScrollPhysics extends ScrollPhysics {
  final double pageExtent;
  final VoidCallback? onSnapTriggered;

  const _MushafEdgeSnapScrollPhysics({
    required this.pageExtent,
    this.onSnapTriggered,
    super.parent,
  });

  @override
  _MushafEdgeSnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _MushafEdgeSnapScrollPhysics(
      pageExtent: pageExtent,
      onSnapTriggered: onSnapTriggered,
      parent: buildParent(ancestor),
    );
  }

  /// Distance threshold from a page top boundary (`k * pageExtent`) within
  /// which the edge snap activates: equals the page header/footer frame
  /// margin (~42 px) plus ~1.45 Quran line slots (so as soon as Line 14 scrolls
  /// off and only 1 line + footer remains at the top edge, the snap kicks in).
  double get _snapZone {
    final double oneLineHeight = ((pageExtent - 70.0) / 15.0).clamp(
      28.0,
      110.0,
    );
    return 42.0 + (oneLineHeight * 1.45);
  }

  /// Finds the duration (in seconds) until [sim] comes to a stop.
  double _findStopTime(Simulation sim) {
    if (sim.isDone(0.0)) return 0.0;
    double low = 0.0;
    double high = 0.5;
    while (!sim.isDone(high) && high < 12.0) {
      low = high;
      high *= 2.0;
    }
    for (int i = 0; i < 20; i++) {
      final mid = (low + high) * 0.5;
      if (sim.isDone(mid)) {
        high = mid;
      } else {
        low = mid;
      }
    }
    return high;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (pageExtent <= 0 || position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }

    final Tolerance tolerance = toleranceFor(position);
    final double zone = _snapZone;

    final double currentNearestEdge =
        ((position.pixels / pageExtent).roundToDouble() * pageExtent).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    final double currentDist = (currentNearestEdge - position.pixels).abs();

    // Case 1: Finger lifted after stopping or slow dragging (velocity <= 420 px/s).
    // On a real touchscreen, lifting a stationary finger often reports 50-350 px/s.
    // If the page is already within the 1-line snap zone of the top edge, snap immediately.
    if (velocity.abs() <= 420.0) {
      if (currentDist > tolerance.distance && currentDist <= zone) {
        return _SmoothEdgeSnapSimulation(
          start: position.pixels,
          end: currentNearestEdge,
          durationSeconds: 0.26,
          onSnapStart: onSnapTriggered,
          tolerance: tolerance,
        );
      }
      if (velocity.abs() <= tolerance.velocity) {
        return null;
      }
    }

    // Case 2: Fast scroll / fling — run natural BouncingScrollPhysics friction first.
    final Simulation? frictionSim = super.createBallisticSimulation(
      position,
      velocity,
    );
    if (frictionSim == null) return null;

    final double stopTime = _findStopTime(frictionSim);
    final double stopPixels = frictionSim.x(stopTime);

    // If the fling overshoots Page 1 or Page 604, let BouncingScrollPhysics handle the bounce.
    if (stopPixels <= position.minScrollExtent ||
        stopPixels >= position.maxScrollExtent) {
      return frictionSim;
    }

    final double nearestTopEdge =
        ((stopPixels / pageExtent).roundToDouble() * pageExtent).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    final double dist = (nearestTopEdge - stopPixels).abs();

    // If the friction glide stops in the middle of a page, do not snap.
    if (dist <= tolerance.distance || dist > zone) {
      return frictionSim;
    }

    // The friction glide stops within ~1 line of a page top edge: let the full
    // friction deceleration play out until [stopTime], then smoothly ease to [nearestTopEdge].
    final Simulation snapSim = _SmoothEdgeSnapSimulation(
      start: stopPixels,
      end: nearestTopEdge,
      durationSeconds: 0.26,
      onSnapStart: onSnapTriggered,
      tolerance: tolerance,
    );
    return _FrictionThenEdgeSnapSimulation(
      frictionSim: frictionSim,
      frictionEndTime: stopTime,
      snapSim: snapSim,
    );
  }
}

/// Lightweight cubic ease-out simulation that smoothly glides from [start]
/// to [end] over [durationSeconds] and fires [onSnapStart] once when started.
class _SmoothEdgeSnapSimulation extends Simulation {
  final double start;
  final double end;
  final double durationSeconds;
  final VoidCallback? onSnapStart;
  bool _notified = false;

  _SmoothEdgeSnapSimulation({
    required this.start,
    required this.end,
    this.durationSeconds = 0.26,
    this.onSnapStart,
    super.tolerance,
  });

  void _ensureNotified() {
    if (!_notified) {
      _notified = true;
      onSnapStart?.call();
    }
  }

  @override
  double x(double time) {
    _ensureNotified();
    if (time <= 0.0) return start;
    if (time >= durationSeconds) return end;
    final double t = (time / durationSeconds).clamp(0.0, 1.0);
    final double eased = Curves.easeOutCubic.transform(t);
    return start + (end - start) * eased;
  }

  @override
  double dx(double time) {
    if (time <= 0.0 || time >= durationSeconds) return 0.0;
    final double t = (time / durationSeconds).clamp(0.0, 1.0);
    final double oneMinusT = 1.0 - t;
    // Derivative of easeOutCubic (1 - (1 - t)^3) is 3 * (1 - t)^2
    return (end - start) * (3.0 * oneMinusT * oneMinusT) / durationSeconds;
  }

  @override
  bool isDone(double time) {
    return time >= durationSeconds;
  }
}

/// Plays [frictionSim] until it naturally stops at [frictionEndTime], and then
/// seamlessly plays [snapSim] to align the nearby page edge.
class _FrictionThenEdgeSnapSimulation extends Simulation {
  final Simulation frictionSim;
  final double frictionEndTime;
  final Simulation snapSim;

  _FrictionThenEdgeSnapSimulation({
    required this.frictionSim,
    required this.frictionEndTime,
    required this.snapSim,
  });

  @override
  double x(double time) {
    if (time <= frictionEndTime) {
      return frictionSim.x(time);
    }
    return snapSim.x(time - frictionEndTime);
  }

  @override
  double dx(double time) {
    if (time <= frictionEndTime) {
      return frictionSim.dx(time);
    }
    return snapSim.dx(time - frictionEndTime);
  }

  @override
  bool isDone(double time) {
    if (time <= frictionEndTime) {
      return false;
    }
    return snapSim.isDone(time - frictionEndTime);
  }
}
