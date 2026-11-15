import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/mushaf_models.dart';
import '../state/mushaf_controller.dart';
import '../utils/arabic_utils.dart';
import '../widgets/mushaf_page_widget.dart';
import '../widgets/reader_hud_overlay.dart';
import '../widgets/surah_header_banner.dart';
import 'ayah_explanation_sheet.dart';
import 'bookmarks_sheet.dart';
import 'index_sheet.dart';
import 'khatma_sheet.dart';
import 'search_sheet.dart';
import 'settings_sheet.dart';

class ReaderScreen extends StatefulWidget {
  final MushafController controller;

  const ReaderScreen({
    super.key,
    required this.controller,
  });

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

  void _startStartupSequence() {
    if (!mounted) return;
    setState(() {
      _showIstiadhahBanner = true;
    });
    _istiadhahTimer?.cancel();
    _istiadhahTimer = Timer(const Duration(seconds: 3), () {
      _dismissIstiadhahAndShowKhatmaPrompt();
    });
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
        showStartupKhatmaPromptDialog(
          context,
          controller: widget.controller,
        );
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
                    const CircularProgressIndicator(
                      color: Color(0xFFD4AF37),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'جاري فتح المصحف الشريف...',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
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
                // 604-page Right-to-Left (RTL) PageView navigation
                SafeArea(
                  child: Directionality(
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
                      itemBuilder: (context, index) {
                        final pageNum = index + 1;
                        return MushafPageWidget(
                          pageNumber: pageNum,
                          controller: widget.controller,
                          onCenterTap: widget.controller.toggleHud,
                          onWordTap: (word) =>
                              _handleWordSingleTap(context, word),
                          onVerseMarkerTap: (word) =>
                              _handleVerseMarkerTap(word),
                          onZoomChanged: (zoomed) {
                            if (_isCurrentPageZoomed != zoomed) {
                              setState(() => _isCurrentPageZoomed = zoomed);
                            }
                          },
                          onAyahLongPress: (verseKey, tappedWord) =>
                              _showAyahActionSheet(
                                context,
                                verseKey,
                                tappedWord: tappedWord,
                              ),
                          onCompleteKhatmaTap: () =>
                              _handleCompleteKhatmaFromLastPage(context),
                        );
                      },
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

  void _openModalSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
  }

  Future<void> _handleWordSingleTap(
    BuildContext context,
    LineWord word,
  ) async {
    final isFirstTime = !widget.controller.hasShownSingleTapIntroDialog;
    unawaited(widget.controller.pronounceWord(word));

    if (isFirstTime && context.mounted) {
      widget.controller.markSingleTapIntroShown();
      await _showFirstTimeSingleTapDialog(context);
    }
  }

  Future<void> _handleVerseMarkerTap(LineWord word) async {
    await widget.controller.playAyahAudio(
      word.surahId,
      word.ayahNumber,
    );
  }

  Future<void> _showFirstTimeSingleTapDialog(BuildContext context) async {
    final theme = widget.controller.theme;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
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
                    'ميزة نطق الكلمات باللمس',
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
              'عند لمس أي كلمة في المصحف الشريف لمسة واحدة، سيقوم التطبيق بنطق الكلمة فوراً لمساعدتك على معرفة نطقها الصحيح أثناء القراءة.\n\n'
              '• كما يمكنك لمس رقم الآية المزخرف ﴿١﴾ للاستماع إلى تلاوة الآية كاملة.\n'
              '• يمكنك في أي وقت تعديل هذه الميزة أو إيقاف اللمس الفردي أو تفعيل تلاوة الآية تلقائياً بعد الكلمة من خلال «الإعدادات».',
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
                  'فتح الإعدادات',
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
                child: const Text(
                  'حسناً، فهمت',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingPronunciationBar(BuildContext context) {
    final theme = widget.controller.theme;
    final audio = widget.controller.audioService;
    final activeWord = audio.activeWord;
    final surahId = audio.activeSurahId ?? activeWord?.surahId ?? 1;
    final ayahNum = audio.activeAyahNumber ?? activeWord?.ayahNumber ?? 1;
    final surahInfo = widget.controller.getSurahById(surahId);
    final surahName = surahInfo?.nameArabic ?? '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: theme.pageBackground.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.ornamentPrimary,
              width: 1.6,
            ),
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
                          : 'الآية ${ArabicUtils.toArabicDigits(ayahNum)}',
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
                              ? 'سورة $surahName • آية ${ArabicUtils.toArabicDigits(ayahNum)} (كلمة ${ArabicUtils.toArabicDigits(activeWord.wordNumberInAyah)})'
                              : 'سورة $surahName • تلاوة الآية ${ArabicUtils.toArabicDigits(ayahNum)}',
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
                              child: Text(
                                audio.statusMessage ??
                                    (activeWord != null
                                        ? 'اضغط لإعادة نطق الكلمة أو سماع الآية كاملة'
                                        : 'القارئ: ${widget.controller.selectedReciter.shortArabicName}'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
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
                        label: const Text(
                          'إعادة الكلمة',
                          style: TextStyle(
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
                            ? 'إيقاف التلاوة'
                            : 'تلاوة الآية كاملة',
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
                    label: const Text(
                      'المعنى والتفسير',
                      style: TextStyle(
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
                  InkWell(
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
                            'تشغيل تلاوة الآية كاملة تلقائياً بعد نطق الكلمة (${widget.controller.selectedReciter.shortArabicName})',
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
          textDirection: TextDirection.rtl,
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
                    'لم يتم بدء ختمة جديدة',
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
              'لا توجد ختمة جارية حالياً، ولا يمكن إتمام ختمة لم يتم بدؤها مسبقاً.\n\nهل تؤكد إضافة ختمة جديدة الآن وإتمامها فوراً؟',
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
                  'إلغاء',
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
                label: const Text(
                  'إضافة ختمة وإتمامها الآن',
                  style: TextStyle(fontWeight: FontWeight.w800),
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
            final isBookmarked =
                widget.controller.isAyahBookmarked(ayah.verseKey);
            final activeKhatma = widget.controller.activeKhatma;
            final isCurrentKhatmaMark =
                widget.controller.isKhatmaCurrentVerse(ayah.verseKey);

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: theme.pageBackground,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border.all(
                    color: theme.pageOuterBorder,
                    width: 1.5,
                  ),
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
                            color: theme.secondaryTextColor
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'سورة ${ayah.surahNameArabic} • الآية ${ArabicUtils.toArabicDigits(ayah.ayahNumber)}',
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
                              'ص ${ArabicUtils.toArabicDigits(ayah.pageNumber)} • جزء ${ArabicUtils.toArabicDigits(ayah.juzNumber)}',
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

                      // Word Pronunciation & Full Ayah Recitation Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.ornamentFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.ornamentPrimary.withValues(alpha: 0.55),
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
                                        'الكلمة المحددة (رقم ${ArabicUtils.toArabicDigits(tappedWord.wordNumberInAyah)}):',
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
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: () {
                                        widget.controller
                                            .pronounceWord(tappedWord);
                                      },
                                      icon: const Icon(
                                        Icons.volume_up_rounded,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'نطق الكلمة',
                                        style: TextStyle(
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
                                      backgroundColor: audio.isPlayingAyah &&
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
                                          ? 'إيقاف الآية'
                                          : 'تلاوة الآية كاملة',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () =>
                                  widget.controller.setAutoPlayAyahAfterWord(
                                !widget.controller.autoPlayAyahAfterWord,
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Icon(
                                      widget.controller.autoPlayAyahAfterWord
                                          ? Icons.check_box_rounded
                                          : Icons
                                              .check_box_outline_blank_rounded,
                                      size: 18,
                                      color: widget
                                              .controller.autoPlayAyahAfterWord
                                          ? const Color(0xFF2B8A62)
                                          : theme.secondaryTextColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'تشغيل تلاوة الآية كاملة تلقائياً بعد انتهاء نطق الكلمة (${widget.controller.selectedReciter.shortArabicName})',
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
                            '${ayah.textUthmani} ﴿${ArabicUtils.toArabicDigits(ayah.ayahNumber)}﴾',
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
                          backgroundColor:
                              theme.ornamentPrimary.withValues(alpha: 0.08),
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
                            initialTabIndex: tappedWord != null &&
                                    !tappedWord.isStandaloneVerseMarker
                                ? 0
                                : 1,
                          );
                        },
                        icon: const Icon(Icons.menu_book_rounded, size: 20),
                        label: const Text(
                          'معاني الكلمات وتفسير الآية (المختصر والتفصيلي)',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Khatma Progress Mark Button (Set or Delete/Rollback)
                      if (isCurrentKhatmaMark)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.bookmarkRibbon,
                            side: BorderSide(
                              color: theme.bookmarkRibbon,
                              width: 1.4,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                                  duration:
                                      const Duration(milliseconds: 1800),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: theme.hudSurface,
                                  content: Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: Text(
                                      prev != null
                                          ? 'تم حذف علامة الختمة والعودة للموضع السابق: سورة ${prev.surahNameArabic} آية ${ArabicUtils.toArabicDigits(prev.ayahNumber)}'
                                          : 'تم حذف علامة الختمة الحالية',
                                      style: TextStyle(color: theme.hudText),
                                    ),
                                  ),
                                ),
                              );
                          },
                          icon: const Icon(Icons.undo_rounded, size: 20),
                          label: const Text(
                            'حذف علامة الختمة (العودة للموضع السابق)',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2B8A62),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final isLastAyah = ayah.id >= 6236 ||
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

                            final res =
                                await widget.controller.markKhatmaAyah(ayah);
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
                                    duration:
                                        const Duration(milliseconds: 1600),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: theme.hudSurface,
                                    content: Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: Text(
                                        'تم تحديث علامة ${res.khatma.title} عند سورة ${ayah.surahNameArabic} آية ${ArabicUtils.toArabicDigits(ayah.ayahNumber)}',
                                        style: TextStyle(color: theme.hudText),
                                      ),
                                    ),
                                  ),
                                );
                            }
                          },
                          icon: const Icon(Icons.flag_rounded, size: 20),
                          label: Text(
                            activeKhatma != null
                                ? 'تحديد كعلامة الختمة الحالية (#${ArabicUtils.toArabicDigits(activeKhatma.serialNumber)})'
                                : 'بدء ختمة جديدة وتحديد هذه الآية كعلامة',
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
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
                                      duration:
                                          const Duration(milliseconds: 1400),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: theme.hudSurface,
                                      content: Directionality(
                                        textDirection: TextDirection.rtl,
                                        child: Text(
                                          added
                                              ? 'تم حفظ الآية في العلامات المرجعية'
                                              : 'تم إزالة الآية من العلامات المرجعية',
                                          style:
                                              TextStyle(color: theme.hudText),
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
                                isBookmarked ? 'محفوظة' : 'حفظ الآية',
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                final formatted =
                                    '﴿ ${ayah.textUthmani} ﴾ [سورة ${ayah.surahNameArabic}: ${ArabicUtils.toArabicDigits(ayah.ayahNumber)}]';
                                await Clipboard.setData(
                                  ClipboardData(text: formatted),
                                );
                                if (!sheetCtx.mounted) return;
                                Navigator.of(sheetCtx).pop();
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      duration:
                                          const Duration(milliseconds: 1500),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: theme.hudSurface,
                                      content: Directionality(
                                        textDirection: TextDirection.rtl,
                                        child: Text(
                                          'تم نسخ الآية الكريمة إلى الحافظة',
                                          style:
                                              TextStyle(color: theme.hudText),
                                        ),
                                      ),
                                    ),
                                  );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 19),
                              label: const Text(
                                'نسخ الآية',
                                style: TextStyle(
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
