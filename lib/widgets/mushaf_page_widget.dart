import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/mushaf_models.dart';
import '../services/font_loader_service.dart';
import '../services/qcf4_page_metrics.dart';
import '../state/mushaf_controller.dart';
import '../theme/mushaf_theme.dart';
import '../utils/arabic_utils.dart';
import 'surah_header_banner.dart';

class MushafPageWidget extends StatefulWidget {
  final int pageNumber;
  final MushafController controller;
  final VoidCallback onCenterTap;
  final void Function(String verseKey, LineWord? tappedWord) onAyahLongPress;
  final ValueChanged<LineWord>? onWordTap;
  final ValueChanged<LineWord>? onVerseMarkerTap;
  final ValueChanged<bool>? onZoomChanged;
  final VoidCallback? onCompleteKhatmaTap;

  /// True when the page lives inside the continuous vertical-scroll list,
  /// which already gives it its full height (so no inner scroll view).
  final bool scrollEmbedded;

  /// Height/width ratio of a Mushaf page, used in landscape layout.
  static const double landscapePageAspect = 1.5;

  /// Font multiplier so a full-width landscape page uses larger glyphs.
  static double landscapeFontBoost(double width) =>
      (width / 400.0).clamp(1.0, 2.6);

  const MushafPageWidget({
    super.key,
    required this.pageNumber,
    required this.controller,
    required this.onCenterTap,
    required this.onAyahLongPress,
    this.onWordTap,
    this.onVerseMarkerTap,
    this.onZoomChanged,
    this.onCompleteKhatmaTap,
    this.scrollEmbedded = false,
  });

  @override
  State<MushafPageWidget> createState() => _MushafPageWidgetState();
}

class _MushafPageWidgetState extends State<MushafPageWidget> {
  static const Duration _doubleTapWindow = Duration(milliseconds: 340);
  static const Duration _singleTapHudDelay = Duration(milliseconds: 260);

  Future<MushafPageData>? _loadFuture;
  final List<GestureRecognizer> _recognizers = <GestureRecognizer>[];
  final TransformationController _zoomController = TransformationController();
  bool _isPinchZoomed = false;
  Timer? _pendingHudToggleTimer;
  String? _lastTappedWordLocation;
  DateTime? _lastWordTapAt;

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.controller.loadPageAndFont(widget.pageNumber);
    _zoomController.addListener(_onZoomMatrixChanged);
  }

  void _cancelPendingWordTap() {
    _pendingHudToggleTimer?.cancel();
    _pendingHudToggleTimer = null;
    _lastTappedWordLocation = null;
    _lastWordTapAt = null;
  }

  void _handleWordTapCandidate(LineWord word) {
    final now = DateTime.now();
    final isDoubleTap =
        _lastTappedWordLocation == word.location &&
        _lastWordTapAt != null &&
        now.difference(_lastWordTapAt!) <= _doubleTapWindow;

    _pendingHudToggleTimer?.cancel();
    _pendingHudToggleTimer = null;

    if (isDoubleTap) {
      _lastTappedWordLocation = null;
      _lastWordTapAt = null;
      widget.onWordTap?.call(word);
      return;
    }

    _lastTappedWordLocation = word.location;
    _lastWordTapAt = now;
    _pendingHudToggleTimer = Timer(_singleTapHudDelay, () {
      _pendingHudToggleTimer = null;
      if (!mounted) return;
      widget.controller.toggleHud();
    });
  }

  void _onZoomMatrixChanged() {
    final scale = _zoomController.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.03;
    if (zoomed != _isPinchZoomed) {
      _isPinchZoomed = zoomed;
      widget.onZoomChanged?.call(zoomed);
    }
  }

  @override
  void didUpdateWidget(covariant MushafPageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageNumber != widget.pageNumber) {
      _cancelPendingWordTap();
      _disposeRecognizers();
      _zoomController.value = Matrix4.identity();
      _loadFuture = widget.controller.loadPageAndFont(widget.pageNumber);
    }
    if (widget.controller.fontScaleMode != MushafFontScaleMode.pinchToZoom &&
        _isPinchZoomed) {
      _zoomController.value = Matrix4.identity();
      _isPinchZoomed = false;
      widget.onZoomChanged?.call(false);
    }
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _cancelPendingWordTap();
    _zoomController.removeListener(_onZoomMatrixChanged);
    _zoomController.dispose();
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final theme = widget.controller.theme;
        final scaleMode = widget.controller.fontScaleMode;
        final cached = widget.controller.currentPage == widget.pageNumber
            ? widget.controller.currentPageData
            : null;
        final fontLoaded = QpcFontLoaderService.instance.isPageFontLoaded(
          widget.pageNumber,
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _cancelPendingWordTap();
            widget.controller.toggleHud();
          },
          onDoubleTap: scaleMode == MushafFontScaleMode.pinchToZoom
              ? () {
                  _cancelPendingWordTap();
                  final currentScale = _zoomController.value
                      .getMaxScaleOnAxis();
                  if (currentScale > 1.05) {
                    _zoomController.value = Matrix4.identity();
                  } else {
                    _zoomController.value = Matrix4.diagonal3Values(
                      1.5,
                      1.5,
                      1.0,
                    );
                  }
                }
              : null,
          child: Container(
            color: theme.scaffoldBackground,
            padding: EdgeInsets.zero,
            child: FutureBuilder<MushafPageData>(
              initialData: (cached != null && fontLoaded) ? cached : null,
              future: _loadFuture,
              builder: (context, snapshot) {
                final pageData = snapshot.data;
                if (pageData == null) {
                  return _buildLoadingSkeleton(theme);
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isLandscape =
                        constraints.maxWidth > constraints.maxHeight;
                    // In the vertical list the page box is taller than wide
                    // even in landscape, so check the device orientation.
                    final screenLandscape =
                        MediaQuery.orientationOf(context) ==
                        Orientation.landscape;
                    final boost = (isLandscape || screenLandscape)
                        ? MushafPageWidget.landscapeFontBoost(
                            constraints.maxWidth,
                          )
                        : 1.0;
                    final isPinch =
                        scaleMode == MushafFontScaleMode.pinchToZoom;
                    final factor = isPinch ? 1.0 : scaleMode.scaleFactor;
                    final heightFactor = isPinch
                        ? 1.0
                        : scaleMode.heightMultiplier;

                    // Inside the vertical list the parent already sized us.
                    if (widget.scrollEmbedded) {
                      final frame = _buildPageFrame(
                        context,
                        pageData,
                        theme,
                        fontScale: factor * boost,
                        userFontScale: factor,
                      );
                      if (!isPinch) return frame;
                      return InteractiveViewer(
                        transformationController: _zoomController,
                        minScale: 1.0,
                        maxScale: 2.6,
                        panEnabled: _isPinchZoomed,
                        child: frame,
                      );
                    }

                    if (isLandscape) {
                      // Full-width page; scroll vertically within it.
                      final pageHeight =
                          constraints.maxWidth *
                          MushafPageWidget.landscapePageAspect *
                          heightFactor;
                      Widget page = factor > 1.01 && !pageData.info.isCentered
                          ? ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth,
                                maxWidth: constraints.maxWidth,
                                minHeight: pageHeight,
                              ),
                              child: _buildPageFrame(
                                context,
                                pageData,
                                theme,
                                fontScale: factor * boost,
                                userFontScale: factor,
                                shrinkWrapHeight: true,
                              ),
                            )
                          : SizedBox(
                              width: constraints.maxWidth,
                              height: pageHeight,
                              child: _buildPageFrame(
                                context,
                                pageData,
                                theme,
                                fontScale: factor * boost,
                                userFontScale: factor,
                              ),
                            );
                      if (isPinch) {
                        page = InteractiveViewer(
                          transformationController: _zoomController,
                          minScale: 1.0,
                          maxScale: 2.6,
                          panEnabled: _isPinchZoomed,
                          child: page,
                        );
                      }
                      return SingleChildScrollView(
                        physics: _isPinchZoomed
                            ? const NeverScrollableScrollPhysics()
                            : const BouncingScrollPhysics(),
                        child: page,
                      );
                    }

                    if (isPinch) {
                      return InteractiveViewer(
                        transformationController: _zoomController,
                        minScale: 1.0,
                        maxScale: 2.6,
                        panEnabled: _isPinchZoomed,
                        scaleEnabled: true,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          child: _buildPageFrame(
                            context,
                            pageData,
                            theme,
                            fontScale: 1.0,
                            userFontScale: 1.0,
                          ),
                        ),
                      );
                    }

                    if (factor <= 1.01) {
                      return _buildPageFrame(
                        context,
                        pageData,
                        theme,
                        fontScale: 1.0,
                        userFontScale: 1.0,
                      );
                    }

                    // Large / Extra-Large in portrait side-flip mode: reflow
                    // verses at the genuinely enlarged font size inside a
                    // smoothly scrollable page frame.
                    if (!pageData.info.isCentered) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                            maxWidth: constraints.maxWidth,
                            minHeight: constraints.maxHeight,
                          ),
                          child: _buildPageFrame(
                            context,
                            pageData,
                            theme,
                            fontScale: factor,
                            userFontScale: factor,
                            shrinkWrapHeight: true,
                          ),
                        ),
                      );
                    }

                    final enlargedHeight = constraints.maxHeight * heightFactor;
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: enlargedHeight,
                        child: _buildPageFrame(
                          context,
                          pageData,
                          theme,
                          fontScale: factor,
                          userFontScale: factor,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingSkeleton(MushafThemeData theme) {
    return Container(
      color: theme.pageBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: theme.ornamentPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'صفحة ${ArabicUtils.toArabicDigits(widget.pageNumber)}',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageFrame(
    BuildContext context,
    MushafPageData pageData,
    MushafThemeData theme, {
    required double fontScale,
    required double userFontScale,
    bool shrinkWrapHeight = false,
  }) {
    final info = pageData.info;
    final isBookmarked = widget.controller.isPageBookmarked(widget.pageNumber);
    final useReflowEnlarged = userFontScale > 1.01 && !info.isCentered;

    final Widget bodyWidget = info.isCentered
        ? _buildCenteredSpecialPage(pageData, theme, fontScale: fontScale)
        : useReflowEnlarged
        ? _buildEnlargedReflowBody(
            pageData,
            theme,
            userFontScale: userFontScale,
            shrinkWrapHeight: shrinkWrapHeight,
          )
        : _buildStandard15LineBody(pageData, theme, fontScale: userFontScale);

    final bool showBorder = info.isCentered || widget.controller.showPageBorder;

    final Widget pageContent = Padding(
      padding: info.isCentered
          ? const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0)
          : showBorder
          ? const EdgeInsets.fromLTRB(10.0, 6.0, 10.0, 6.0)
          : const EdgeInsets.fromLTRB(10.0, 4.0, 10.0, 4.0),
      child: Column(
        mainAxisSize: shrinkWrapHeight ? MainAxisSize.min : MainAxisSize.max,
        children: [
          // Top running header inside Mushaf margin
          _buildRunningHeader(info, theme),
          const SizedBox(height: 2.0),
          // Main Mushaf body
          if (shrinkWrapHeight) bodyWidget else Expanded(child: bodyWidget),
          // Special Khatma Completion button on the very last page of the Mushaf
          // (Page 604, after Surah An-Nas Ayah 6) — shown ONLY when an active Khatma exists
          if (info.pageNumber == 604 &&
              widget.controller.activeKhatma != null) ...[
            const SizedBox(height: 4.0),
            _buildLastPageKhatmaCompletionButton(theme),
          ],
          const SizedBox(height: 2.0),
          // Bottom page number in ornamental cartouche
          _buildFooterPageNumber(info.pageNumber, theme),
        ],
      ),
    );

    final Widget framedOrBorderless = showBorder
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
            child: CustomPaint(
              painter: _MushafFramePainter(
                pageBackground: theme.pageBackground,
                outerBorder: theme.pageOuterBorder,
                innerBorder: theme.pageInnerBorder,
                ornamentFill: theme.ornamentFill,
                isCenteredPage: info.isCentered,
              ),
              child: pageContent,
            ),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: theme.pageBackground,
              border: widget.scrollEmbedded
                  ? Border(
                      bottom: BorderSide(
                        color: theme.pageInnerBorder.withValues(alpha: 0.40),
                        width: 0.8,
                      ),
                    )
                  : null,
            ),
            child: pageContent,
          );

    return Stack(
      children: [
        framedOrBorderless,
        // Subtle bookmark ribbon at top-left of page when page is bookmarked
        if (isBookmarked)
          Positioned(
            top: 0,
            left: 20,
            child: IgnorePointer(
              child: CustomPaint(
                size: const Size(22, 34),
                painter: _BookmarkRibbonPainter(color: theme.bookmarkRibbon),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRunningHeader(MushafPageInfo info, MushafThemeData theme) {
    return SizedBox(
      height: 20,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Right side in RTL: Juz & Hizb
              Text(
                'الجزء ${ArabicUtils.toArabicDigits(info.juzNumber)} • الحزب ${ArabicUtils.toArabicDigits(info.hizbNumber)}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: theme.secondaryTextColor,
                ),
              ),
              // Left side in RTL: Surah name(s)
              Flexible(
                child: Text(
                  info.surahNamesArabic,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w700,
                    color: theme.secondaryTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pages 1 & 2 (Al-Fatihah & opening of Al-Baqarah) circular text form & illuminated layout.
  Widget _buildCenteredSpecialPage(
    MushafPageData pageData,
    MushafThemeData theme, {
    required double fontScale,
  }) {
    _disposeRecognizers();
    final fontFamily = QpcFontLoaderService.fontFamilyForPage(
      widget.pageNumber,
    );

    final surahId = pageData.info.firstSurahId;
    final surahInfo = widget.controller.getSurahById(surahId);
    final headerLine = pageData.lines.where((l) => l.isSurahHeader).firstOrNull;
    final contentLines = pageData.lines
        .where((l) => !l.isSurahHeader)
        .toList(growable: false);

    // Circular chord width profile for the 7 lines of Page 1 (Al-Fatihah)
    // and Page 2 (opening of Al-Baqarah), forming the classic circular/oval silhouette.
    const page1ChordFactors = <double>[
      0.52,
      0.74,
      0.94,
      1.00,
      0.91,
      0.70,
      0.42,
    ];
    const page2ChordFactors = <double>[
      0.54,
      0.76,
      0.94,
      1.00,
      0.93,
      0.76,
      0.52,
    ];
    final chordProfile = widget.pageNumber == 1
        ? page1ChordFactors
        : page2ChordFactors;

    final surahTitleAr = surahInfo != null
        ? 'سُورَةُ ${surahInfo.nameArabic}'
        : (widget.pageNumber == 1
              ? 'سُورَةُ الفَاتِحَةِ'
              : 'سُورَةُ البَقَرَةِ');
    final revelationAr =
        surahInfo?.revelationArabic ??
        (widget.pageNumber == 1 ? 'مكية' : 'مدنية');
    final ayahCountAr = ArabicUtils.toArabicDigits(
      surahInfo?.ayahCount ?? (widget.pageNumber == 1 ? 7 : 286),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableInnerWidth = (constraints.maxWidth - 48.0).clamp(
          180.0,
          600.0,
        );
        final circleMaxWidth = availableInnerWidth * 0.94;

        return CustomPaint(
          painter: _OpeningSpreadIlluminatedPainter(
            primaryColor: theme.ornamentPrimary,
            secondaryColor: theme.ornamentSecondary,
            fillColor: theme.ornamentFill,
            pageBackground: theme.pageBackground,
            innerBorderColor: theme.pageInnerBorder,
            isDark: theme.isDark,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 18.0, 20.0, 18.0),
            child: Column(
              children: [
                // 1. Top Ornamental Surah Header Banner (with floral rosettes & arabesque scrolls)
                const SizedBox(height: 6.0),
                SizedBox(
                  height: 58 * fontScale.clamp(1.0, 1.22),
                  child: SurahHeaderBanner(
                    surahId: headerLine?.surahId ?? surahId,
                    headerText: headerLine?.headerText ?? '',
                    surahInfo: surahInfo,
                    theme: theme,
                    openingSpreadStyle: true,
                  ),
                ),

                // 2. Vertically centered Circular Verse Block (النص القرآني بالتنسيق الدائري)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List<Widget>.generate(contentLines.length, (
                          idx,
                        ) {
                          final line = contentLines[idx];
                          final factor = idx < chordProfile.length
                              ? chordProfile[idx]
                              : 0.75;
                          final targetLineWidth = circleMaxWidth * factor;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.5),
                            child: Center(
                              child: SizedBox(
                                width: targetLineWidth,
                                child: line.isBasmala
                                    ? _buildCircularBasmalaLine(theme)
                                    : _buildCircularTextLine(
                                        line: line,
                                        fontFamily: fontFamily,
                                        theme: theme,
                                      ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),

                // 3. Subtle Bottom Ornamental Surah Info Cartouche
                _buildOpeningBottomCartouche(
                  theme: theme,
                  surahTitleAr: surahTitleAr,
                  revelationAr: revelationAr,
                  ayahCountAr: ayahCountAr,
                  juzAr: ArabicUtils.toArabicDigits(pageData.info.juzNumber),
                ),
                const SizedBox(height: 4.0),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCircularBasmalaLine(MushafThemeData theme) {
    final quranWeight = widget.controller.boldQuranFont
        ? FontWeight.w700
        : FontWeight.w400;
    return FittedBox(
      fit: BoxFit.fitWidth,
      alignment: Alignment.center,
      child: RichText(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: '\uE000',
          style: TextStyle(
            fontFamily: 'QPC1BSML',
            fontSize: 40.0,
            fontWeight: quranWeight,
            height: 1.05,
            color: theme.glyphColor,
          ),
        ),
      ),
    );
  }

  Widget _buildAyahMarkerWidget({
    required LineWord word,
    required MushafThemeData theme,
    required double fontSize,
    required bool isSelectedAyah,
    required bool isKhatmaMark,
    required Color? baseBgColor,
    required LineWord? longPressWord,
  }) {
    final Color ornamentColor = isKhatmaMark
        ? const Color(0xFF1F7A53)
        : theme.ornamentPrimary;
    final Color secondaryOrnamentColor = isKhatmaMark
        ? const Color(0xFF2B8A62)
        : theme.ornamentSecondary;
    final Color digitColor = isKhatmaMark
        ? const Color(0xFF1F7A53)
        : isSelectedAyah
        ? theme.ornamentPrimary
        : theme.glyphColor;

    final ayahDigits = _toEasternArabicDigits(word.ayahNumber);
    final isThreeDigits = word.ayahNumber >= 100;
    final double markerWidth = fontSize * (isThreeDigits ? 1.24 : 1.12);
    final double markerHeight = fontSize * 1.28;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onVerseMarkerTap != null
          ? () {
              _cancelPendingWordTap();
              widget.onVerseMarkerTap!(word);
            }
          : null,
      onLongPress: () {
        _cancelPendingWordTap();
        widget.controller.selectVerse(word.verseKey);
        widget.onAyahLongPress(word.verseKey, longPressWord);
      },
      child: Container(
        color: baseBgColor,
        padding: EdgeInsets.symmetric(horizontal: fontSize * 0.035),
        child: _AyahNumberOrnament(
          digits: ayahDigits,
          width: markerWidth,
          height: markerHeight,
          digitFontSize: fontSize * (isThreeDigits ? 0.37 : 0.44),
          ornamentColor: ornamentColor,
          secondaryOrnamentColor: secondaryOrnamentColor,
          digitColor: digitColor,
          isSelected: isSelectedAyah,
          isDark: theme.isDark,
        ),
      ),
    );
  }

  List<InlineSpan> _buildWordSpans({
    required MushafPageLine line,
    required String fontFamily,
    required MushafThemeData theme,
    required double fontSize,
    required double lineHeight,
    required double wordSpacing,
    bool allowLineBreakBetweenWords = false,
  }) {
    final selectedVerse = widget.controller.selectedVerseKey;
    final playingAyahKey = widget.controller.playingAyahVerseKey;
    final selectedWordLoc = widget.controller.selectedWordLocation;
    final doubleTapWordEnabled =
        widget.controller.enableSingleTapWordPronunciation;
    final isIndoPak = widget.controller.isIndoPakScript;
    final effectiveFont = isIndoPak ? 'IndoPak' : fontFamily;
    final effectiveWordSpacing = isIndoPak ? 1.0 : wordSpacing;
    final quranWeight = widget.controller.boldQuranFont
        ? FontWeight.w700
        : FontWeight.w400;

    final spans = <InlineSpan>[];

    void addQcfBreakOpportunity() {
      if (!isIndoPak && allowLineBreakBetweenWords) {
        spans.add(
          const TextSpan(text: '\u200B', style: TextStyle(fontSize: 1.0)),
        );
      }
    }

    for (int i = 0; i < line.words.length; i++) {
      final word = line.words[i];
      final isLastInLine = i == line.words.length - 1;
      final isSelectedAyah =
          selectedVerse == word.verseKey || playingAyahKey == word.verseKey;
      final isSelectedWord = selectedWordLoc == word.location;
      final isKhatmaMark = widget.controller.isKhatmaCurrentVerse(
        word.verseKey,
      );
      final isBookmarkedAyah = widget.controller.isAyahBookmarked(
        word.verseKey,
      );

      Color? baseBgColor;
      if (isSelectedAyah) {
        baseBgColor = theme.ayahHighlightFill;
      } else if (isKhatmaMark) {
        baseBgColor = const Color(0x3D2B8A62);
      } else if (isBookmarkedAyah) {
        baseBgColor = widget.controller.savedAyahHighlightColor.withValues(
          alpha: 0.28,
        );
      }

      final Color wordBgColor = isSelectedWord
          ? theme.ornamentPrimary.withValues(alpha: 0.30)
          : (baseBgColor ?? Colors.transparent);

      final Color wordTextColor = isSelectedWord
          ? theme.ornamentPrimary
          : isSelectedAyah
          ? theme.ornamentPrimary
          : isKhatmaMark
          ? const Color(0xFF1F7A53)
          : theme.glyphColor;

      if (word.isStandaloneVerseMarker) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _buildAyahMarkerWidget(
              word: word,
              theme: theme,
              fontSize: fontSize,
              isSelectedAyah: isSelectedAyah,
              isKhatmaMark: isKhatmaMark,
              baseBgColor: baseBgColor,
              longPressWord: null,
            ),
          ),
        );
        if (!isLastInLine) {
          if (isIndoPak) {
            spans.add(
              TextSpan(
                text: ' ',
                style: TextStyle(
                  fontFamily: effectiveFont,
                  fontSize: fontSize * 0.65,
                  height: lineHeight,
                  wordSpacing: effectiveWordSpacing,
                  backgroundColor: baseBgColor,
                ),
              ),
            );
          } else {
            addQcfBreakOpportunity();
          }
        }
      } else if (word.isOrnamentMark) {
        final markRecognizer = _WordTapAndLongPressRecognizer(
          onTap: null,
          onLongPress: () {
            _cancelPendingWordTap();
            widget.controller.selectVerse(word.verseKey);
            widget.onAyahLongPress(word.verseKey, null);
          },
        );
        _recognizers.add(markRecognizer);
        final markText = isIndoPak ? word.wordUthmani.trim() : word.qpcV1;
        spans.add(
          TextSpan(
            text: (isIndoPak && !isLastInLine) ? '$markText ' : markText,
            recognizer: markRecognizer,
            style: TextStyle(
              fontFamily: effectiveFont,
              fontSize: fontSize,
              height: lineHeight,
              leadingDistribution: TextLeadingDistribution.even,
              wordSpacing: effectiveWordSpacing,
              color: isKhatmaMark
                  ? const Color(0xFF1F7A53)
                  : theme.ornamentPrimary,
              backgroundColor: baseBgColor,
            ),
          ),
        );
        if (!isLastInLine) {
          addQcfBreakOpportunity();
        }
      } else if (word.hasTrailingVerseMarker) {
        final wordPart = isIndoPak
            ? _toIndoPakWord(word.cleanWordUthmani)
            : word.wordOnlyQpcV1;

        final wordRecognizer = _WordTapAndLongPressRecognizer(
          onTap: doubleTapWordEnabled && widget.onWordTap != null
              ? () => _handleWordTapCandidate(word)
              : null,
          onLongPress: () {
            _cancelPendingWordTap();
            widget.controller.selectVerse(word.verseKey);
            widget.onAyahLongPress(word.verseKey, word);
          },
        );
        _recognizers.add(wordRecognizer);

        spans.add(
          TextSpan(
            text: wordPart,
            recognizer: wordRecognizer,
            style: TextStyle(
              fontFamily: effectiveFont,
              fontSize: fontSize,
              fontWeight: quranWeight,
              height: lineHeight,
              leadingDistribution: TextLeadingDistribution.even,
              wordSpacing: effectiveWordSpacing,
              color: wordTextColor,
              backgroundColor: isSelectedWord ? wordBgColor : baseBgColor,
            ),
          ),
        );

        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _buildAyahMarkerWidget(
              word: word,
              theme: theme,
              fontSize: fontSize,
              isSelectedAyah: isSelectedAyah,
              isKhatmaMark: isKhatmaMark,
              baseBgColor: baseBgColor,
              longPressWord: word,
            ),
          ),
        );

        if (!isLastInLine) {
          if (isIndoPak) {
            spans.add(
              TextSpan(
                text: ' ',
                style: TextStyle(
                  fontFamily: effectiveFont,
                  fontSize: fontSize * 0.65,
                  height: lineHeight,
                  wordSpacing: effectiveWordSpacing,
                  backgroundColor: baseBgColor,
                ),
              ),
            );
          } else {
            addQcfBreakOpportunity();
          }
        }
      } else {
        final wordRecognizer = _WordTapAndLongPressRecognizer(
          onTap: doubleTapWordEnabled && widget.onWordTap != null
              ? () => _handleWordTapCandidate(word)
              : null,
          onLongPress: () {
            _cancelPendingWordTap();
            widget.controller.selectVerse(word.verseKey);
            widget.onAyahLongPress(word.verseKey, word);
          },
        );
        _recognizers.add(wordRecognizer);
        final wText = isIndoPak
            ? _toIndoPakWord(word.cleanWordUthmani)
            : word.qpcV1;

        spans.add(
          TextSpan(
            text: (isIndoPak && !isLastInLine) ? '$wText ' : wText,
            recognizer: wordRecognizer,
            style: TextStyle(
              fontFamily: effectiveFont,
              fontSize: fontSize,
              fontWeight: quranWeight,
              height: lineHeight,
              leadingDistribution: TextLeadingDistribution.even,
              wordSpacing: effectiveWordSpacing,
              color: wordTextColor,
              backgroundColor: isSelectedWord ? wordBgColor : baseBgColor,
            ),
          ),
        );
        if (!isLastInLine) {
          addQcfBreakOpportunity();
        }
      }
    }

    return spans;
  }

  /// Builds per-word widgets for QCF4 (1441H) pages so Flutter lays out
  /// Private-Use-Area glyphs strictly Right-to-Left via RTL [Row] / [Wrap]
  /// (avoiding Unicode BiDi treating PUA codepoints as LTR runs).
  List<Widget> _buildQcf4WordWidgets({
    required MushafPageLine line,
    required String fontFamily,
    required MushafThemeData theme,
    required double fontSize,
    required double lineHeight,
  }) {
    final selectedVerse = widget.controller.selectedVerseKey;
    final playingAyahKey = widget.controller.playingAyahVerseKey;
    final selectedWordLoc = widget.controller.selectedWordLocation;
    final doubleTapWordEnabled =
        widget.controller.enableSingleTapWordPronunciation;
    final quranWeight = widget.controller.boldQuranFont
        ? FontWeight.w700
        : FontWeight.w400;

    final widgets = <Widget>[];

    for (final word in line.words) {
      final isSelectedAyah =
          selectedVerse == word.verseKey || playingAyahKey == word.verseKey;
      final isSelectedWord = selectedWordLoc == word.location;
      final isKhatmaMark = widget.controller.isKhatmaCurrentVerse(
        word.verseKey,
      );
      final isBookmarkedAyah = widget.controller.isAyahBookmarked(
        word.verseKey,
      );

      Color? baseBgColor;
      if (isSelectedAyah) {
        baseBgColor = theme.ayahHighlightFill;
      } else if (isKhatmaMark) {
        baseBgColor = const Color(0x3D2B8A62);
      } else if (isBookmarkedAyah) {
        baseBgColor = widget.controller.savedAyahHighlightColor.withValues(
          alpha: 0.28,
        );
      }

      final Color? wordBgColor = isSelectedWord
          ? theme.ornamentPrimary.withValues(alpha: 0.30)
          : baseBgColor;

      final Color wordTextColor = isSelectedWord
          ? theme.ornamentPrimary
          : isSelectedAyah
          ? theme.ornamentPrimary
          : isKhatmaMark
          ? const Color(0xFF1F7A53)
          : theme.glyphColor;

      if (word.isStandaloneVerseMarker) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: fontSize * 0.05),
            child: _buildAyahMarkerWidget(
              word: word,
              theme: theme,
              fontSize: fontSize,
              isSelectedAyah: isSelectedAyah,
              isKhatmaMark: isKhatmaMark,
              baseBgColor: baseBgColor,
              longPressWord: null,
            ),
          ),
        );
      } else if (word.isOrnamentMark) {
        widgets.add(
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () {
              _cancelPendingWordTap();
              widget.controller.selectVerse(word.verseKey);
              widget.onAyahLongPress(word.verseKey, null);
            },
            child: ColoredBox(
              color: baseBgColor ?? Colors.transparent,
              child: RichText(
                textDirection: TextDirection.ltr,
                maxLines: 1,
                softWrap: false,
                text: TextSpan(
                  text: word.qpcV1,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: fontSize,
                    fontWeight: quranWeight,
                    height: lineHeight,
                    leadingDistribution: TextLeadingDistribution.even,
                    color: isKhatmaMark
                        ? const Color(0xFF1F7A53)
                        : theme.ornamentPrimary,
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        widgets.add(
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: doubleTapWordEnabled && widget.onWordTap != null
                ? () => _handleWordTapCandidate(word)
                : null,
            onLongPress: () {
              _cancelPendingWordTap();
              widget.controller.selectVerse(word.verseKey);
              widget.onAyahLongPress(word.verseKey, word);
            },
            child: ColoredBox(
              color: wordBgColor ?? Colors.transparent,
              child: RichText(
                textDirection: TextDirection.ltr,
                maxLines: 1,
                softWrap: false,
                text: TextSpan(
                  text: word.qpcV1,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: fontSize,
                    fontWeight: quranWeight,
                    height: lineHeight,
                    leadingDistribution: TextLeadingDistribution.even,
                    color: wordTextColor,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildCircularTextLine({
    required MushafPageLine line,
    required String fontFamily,
    required MushafThemeData theme,
  }) {
    final isIndoPak = widget.controller.isIndoPakScript;

    if (!isIndoPak) {
      final wordWidgets = _buildQcf4WordWidgets(
        line: line,
        fontFamily: fontFamily,
        theme: theme,
        fontSize: 34.0,
        lineHeight: 1.55,
      );
      return FittedBox(
        fit: BoxFit.fitWidth,
        alignment: Alignment.center,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: wordWidgets,
          ),
        ),
      );
    }

    final spans = _buildWordSpans(
      line: line,
      fontFamily: fontFamily,
      theme: theme,
      fontSize: 34.0,
      lineHeight: 1.55,
      wordSpacing: 0.0,
    );

    return FittedBox(
      fit: BoxFit.fitWidth,
      alignment: Alignment.center,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: RichText(
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          maxLines: 1,
          text: TextSpan(children: spans),
        ),
      ),
    );
  }

  Widget _buildOpeningBottomCartouche({
    required MushafThemeData theme,
    required String surahTitleAr,
    required String revelationAr,
    required String ayahCountAr,
    required String juzAr,
  }) {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: CustomPaint(
        painter: _SurahFooterCartouchePainter(
          primaryColor: theme.ornamentPrimary,
          secondaryColor: theme.ornamentSecondary,
          fillColor: theme.ornamentFill,
          pageBackground: theme.pageBackground,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _OpeningCartoucheBadge(text: revelationAr, theme: theme),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          '$surahTitleAr  •  آيَاتُهَا $ayahCountAr',
                          style: TextStyle(
                            color: theme.glyphColor,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _OpeningCartoucheBadge(text: 'الجُزْءُ $juzAr', theme: theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Enlarged reflow body used when the user selects Large (125%) or Extra Large (150%).
  /// Instead of forcing every line onto 1 line inside `FittedBox` (which would shrink the
  /// font back down to screen width and only add gaps between lines), this renders the
  /// page's verses in flowing wrapped blocks at a genuinely enlarged glyph size while
  /// preserving exact page boundaries, Surah headers, Basmalas, word-tap audio, and highlights.
  Widget _buildEnlargedReflowBody(
    MushafPageData pageData,
    MushafThemeData theme, {
    required double userFontScale,
    required bool shrinkWrapHeight,
  }) {
    _disposeRecognizers();
    final fontFamily = QpcFontLoaderService.fontFamilyForPage(
      widget.pageNumber,
    );
    final isIndoPak = widget.controller.isIndoPakScript;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availWidth = (constraints.maxWidth - 8.0).clamp(180.0, 1400.0);
        // Baseline visual glyph size matching Standard (100%) on this screen width
        final double baseVisualSize = isIndoPak
            ? (availWidth / 15.0).clamp(18.0, 52.0)
            : (availWidth / 16.30).clamp(18.0, 56.0);
        final double targetFontSize = baseVisualSize * userFontScale;
        final double lineHeight = isIndoPak ? 1.85 : 1.82;

        final blocks = <Widget>[];
        final pendingSpans = <InlineSpan>[];
        final pendingQcfWidgets = <Widget>[];

        void flushPendingText() {
          if (!isIndoPak) {
            if (pendingQcfWidgets.isEmpty) return;
            final widgetsCopy = List<Widget>.from(pendingQcfWidgets);
            pendingQcfWidgets.clear();
            blocks.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Wrap(
                    direction: Axis.horizontal,
                    textDirection: TextDirection.rtl,
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 0.0,
                    runSpacing: 2.0,
                    children: widgetsCopy,
                  ),
                ),
              ),
            );
            return;
          }
          if (pendingSpans.isEmpty) return;
          final spansCopy = List<InlineSpan>.from(pendingSpans);
          pendingSpans.clear();
          blocks.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: RichText(
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.justify,
                  softWrap: true,
                  text: TextSpan(children: spansCopy),
                ),
              ),
            ),
          );
        }

        for (final line in pageData.lines) {
          if (line.isSurahHeader) {
            flushPendingText();
            final sId = line.surahId ?? 1;
            blocks.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: SizedBox(
                  height: (46.0 * userFontScale).clamp(46.0, 74.0),
                  child: SurahHeaderBanner(
                    surahId: sId,
                    headerText: line.headerText ?? '',
                    surahInfo: widget.controller.getSurahById(sId),
                    theme: theme,
                    compact: true,
                  ),
                ),
              ),
            );
          } else if (line.isBasmala) {
            flushPendingText();
            blocks.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: SizedBox(
                  height: (36.0 * userFontScale).clamp(36.0, 58.0),
                  child: _buildBasmalaLine(
                    theme,
                    fontSize: (28.0 * userFontScale).clamp(28.0, 52.0),
                  ),
                ),
              ),
            );
          } else if (line.words.isNotEmpty) {
            if (!isIndoPak) {
              pendingQcfWidgets.addAll(
                _buildQcf4WordWidgets(
                  line: line,
                  fontFamily: fontFamily,
                  theme: theme,
                  fontSize: targetFontSize,
                  lineHeight: lineHeight,
                ),
              );
            } else {
              if (pendingSpans.isNotEmpty) {
                pendingSpans.add(
                  TextSpan(
                    text: ' ',
                    style: TextStyle(
                      fontFamily: 'IndoPak',
                      fontSize: targetFontSize,
                      height: lineHeight,
                    ),
                  ),
                );
              }
              pendingSpans.addAll(
                _buildWordSpans(
                  line: line,
                  fontFamily: fontFamily,
                  theme: theme,
                  fontSize: targetFontSize,
                  lineHeight: lineHeight,
                  wordSpacing: 1.5,
                  allowLineBreakBetweenWords: true,
                ),
              );
            }
          }
        }
        flushPendingText();

        final contentColumn = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: blocks,
          ),
        );

        if (shrinkWrapHeight) {
          return contentColumn;
        }

        // Embedded inside fixed-height vertical scroll list: render at true
        // enlarged font size, with a FittedBox(scaleDown) safety guard only if
        // an unusually dense page would otherwise exceed the page box height.
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(width: constraints.maxWidth, child: contentColumn),
          ),
        );
      },
    );
  }

  /// Pages 3–604 authentic 15-line Madinah Mushaf (1441H QCF4) layout with
  /// one uniform printed-book font size across all 15 lines of the page.
  Widget _buildStandard15LineBody(
    MushafPageData pageData,
    MushafThemeData theme, {
    required double fontScale,
  }) {
    _disposeRecognizers();
    final fontFamily = QpcFontLoaderService.fontFamilyForPage(
      widget.pageNumber,
    );
    final isIndoPak = widget.controller.isIndoPakScript;
    final targetEm = qcf4TargetLineEmForPage(widget.pageNumber);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availWidth = constraints.maxWidth.clamp(180.0, 1400.0);
        final availHeight = constraints.maxHeight.clamp(240.0, 3000.0);
        final totalFlex = pageData.lines.fold<int>(
          0,
          (sum, line) => sum + (line.isSurahHeader ? 13 : 10),
        );
        final slotHeight = totalFlex > 0
            ? availHeight * (10.0 / totalFlex)
            : availHeight / 15.0;

        // Compute one uniform font size for every line on this page so all 15
        // lines share identical stroke weight and visual rhythm.
        final double uniformFontSize;
        if (isIndoPak) {
          uniformFontSize = (availWidth / 14.5).clamp(18.0, 42.0) * fontScale;
        } else {
          final widthFont = availWidth / (targetEm + 0.20);
          final heightFont = slotHeight / 1.56;
          uniformFontSize = math.min(widthFont, heightFont) * fontScale;
        }

        return Column(
          children: pageData.lines
              .map((line) {
                return Expanded(
                  flex: line.isSurahHeader ? 13 : 10,
                  child: _buildStandardLineSlot(
                    line,
                    fontFamily,
                    theme,
                    uniformFontSize: uniformFontSize,
                    fontScale: fontScale,
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildStandardLineSlot(
    MushafPageLine line,
    String fontFamily,
    MushafThemeData theme, {
    required double uniformFontSize,
    required double fontScale,
  }) {
    if (line.isSurahHeader) {
      final sId = line.surahId ?? 1;
      return SurahHeaderBanner(
        surahId: sId,
        headerText: line.headerText ?? '',
        surahInfo: widget.controller.getSurahById(sId),
        theme: theme,
        compact: true,
      );
    }
    if (line.isBasmala) {
      return _buildBasmalaLine(
        theme,
        fontSize: (uniformFontSize * 1.25).clamp(24.0, 56.0),
      );
    }
    return _buildTextLine(
      line: line,
      fontFamily: fontFamily,
      theme: theme,
      centered: false,
      baseFontSize: uniformFontSize,
    );
  }

  Widget _buildBasmalaLine(MushafThemeData theme, {required double fontSize}) {
    final quranWeight = widget.controller.boldQuranFont
        ? FontWeight.w700
        : FontWeight.w400;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: RichText(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: '\uE000',
            style: TextStyle(
              fontFamily: 'QPC1BSML',
              fontSize: fontSize,
              fontWeight: quranWeight,
              height: 1.0,
              color: theme.glyphColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextLine({
    required MushafPageLine line,
    required String fontFamily,
    required MushafThemeData theme,
    required bool centered,
    required double baseFontSize,
  }) {
    final isIndoPak = widget.controller.isIndoPakScript;

    if (!isIndoPak) {
      final wordWidgets = _buildQcf4WordWidgets(
        line: line,
        fontFamily: fontFamily,
        theme: theme,
        fontSize: baseFontSize,
        lineHeight: 1.52,
      );
      return SizedBox.expand(
        child: Align(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: wordWidgets,
              ),
            ),
          ),
        ),
      );
    }

    final spans = _buildWordSpans(
      line: line,
      fontFamily: fontFamily,
      theme: theme,
      fontSize: baseFontSize,
      lineHeight: 1.15,
      wordSpacing: 0.0,
    );

    return SizedBox.expand(
      child: Align(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: RichText(
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              maxLines: 1,
              text: TextSpan(children: spans),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLastPageKhatmaCompletionButton(MushafThemeData theme) {
    final activeKhatma = widget.controller.activeKhatma;
    final serialLabel = activeKhatma != null
        ? 'الختمة #${ArabicUtils.toArabicDigits(activeKhatma.serialNumber)}'
        : 'الختمة القرآنية';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onCompleteKhatmaTap,
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F7A53), Color(0xFF2B8A62)],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: theme.ornamentPrimary, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2B8A62).withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFFFFD56B),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'إتمام $serialLabel وعرض التقرير',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'صدق الله العظيم',
                      style: TextStyle(
                        color: Color(0xFFFFF3D1),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _toEasternArabicDigits(int number) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    final s = number.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      buf.write(c >= 48 && c <= 57 ? digits[c - 48] : s[i]);
    }
    return buf.toString();
  }

  /// Converts an Uthmani word to Indo-Pak orthography for `IndoPak.ttf`.
  static String _toIndoPakWord(String uthmani) {
    return uthmani
        .replaceAll('\u0671', '\u0627') // Alef Wasla -> Alef
        .replaceAll(
          '\u0640\u0670',
          '\u0670',
        ) // Tatweel + dagger alef -> standing fatha
        .replaceAll('\u0652', '\u06E1') // Sukun -> Indo-Pak jazm
        .replaceAll('\u06DF', '') // Remove Uthmani small high rounded zero
        .replaceAll('\u06E0', '');
  }

  Widget _buildFooterPageNumber(int pageNumber, MushafThemeData theme) {
    return SizedBox(
      height: 28,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 2.0),
          decoration: BoxDecoration(
            color: theme.ornamentFill,
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(color: theme.pageInnerBorder, width: 1.2),
          ),
          child: Text(
            ArabicUtils.toArabicDigits(pageNumber),
            style: TextStyle(
              fontSize: 17.0,
              fontWeight: FontWeight.w800,
              color: theme.secondaryTextColor,
              height: 1.15,
            ),
          ),
        ),
      ),
    );
  }
}

class _MushafFramePainter extends CustomPainter {
  final Color pageBackground;
  final Color outerBorder;
  final Color innerBorder;
  final Color ornamentFill;
  final bool isCenteredPage;

  const _MushafFramePainter({
    required this.pageBackground,
    required this.outerBorder,
    required this.innerBorder,
    required this.ornamentFill,
    required this.isCenteredPage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (rect.isEmpty) return;

    final bgPaint = Paint()
      ..color = pageBackground
      ..style = PaintingStyle.fill;

    final outerStroke = Paint()
      ..color = outerBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final innerStroke = Paint()
      ..color = innerBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final outerRRect = RRect.fromRectAndRadius(
      rect.deflate(1.0),
      const Radius.circular(8.0),
    );
    canvas.drawRRect(outerRRect, bgPaint);
    canvas.drawRRect(outerRRect, outerStroke);

    final innerRRect = RRect.fromRectAndRadius(
      rect.deflate(3.5),
      const Radius.circular(5.0),
    );
    canvas.drawRRect(innerRRect, innerStroke);

    // Subtle corner floral/geometric accents
    const cornerOffset = 6.5;
    final corners = [
      const Offset(cornerOffset, cornerOffset),
      Offset(size.width - cornerOffset, cornerOffset),
      Offset(cornerOffset, size.height - cornerOffset),
      Offset(size.width - cornerOffset, size.height - cornerOffset),
    ];
    final dotPaint = Paint()
      ..color = outerBorder
      ..style = PaintingStyle.fill;
    for (final c in corners) {
      canvas.drawCircle(c, 2.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MushafFramePainter oldDelegate) {
    return oldDelegate.pageBackground != pageBackground ||
        oldDelegate.outerBorder != outerBorder ||
        oldDelegate.innerBorder != innerBorder ||
        oldDelegate.isCenteredPage != isCenteredPage;
  }
}

class _BookmarkRibbonPainter extends CustomPainter {
  final Color color;

  const _BookmarkRibbonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height - 8)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawShadow(path, Colors.black54, 3.0, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BookmarkRibbonPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _OpeningCartoucheBadge extends StatelessWidget {
  final String text;
  final MushafThemeData theme;

  const _OpeningCartoucheBadge({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: theme.secondaryTextColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Richly illuminated border and geometric lattice painter for Pages 1 & 2
/// (Al-Fatihah and the opening of Al-Baqarah).
class _OpeningSpreadIlluminatedPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final Color fillColor;
  final Color pageBackground;
  final Color innerBorderColor;
  final bool isDark;

  const _OpeningSpreadIlluminatedPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.fillColor,
    required this.pageBackground,
    required this.innerBorderColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (rect.isEmpty) return;

    // 1. Outer illuminated band fill
    final outerRect = rect.deflate(2.0);
    final innerClearRect = rect.deflate(14.0);

    final bandPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final outerRRect = RRect.fromRectAndRadius(
      outerRect,
      const Radius.circular(10.0),
    );
    final innerClearRRect = RRect.fromRectAndRadius(
      innerClearRect,
      const Radius.circular(8.0),
    );

    final borderBandPath = Path()
      ..addRRect(outerRRect)
      ..addRRect(innerClearRRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(borderBandPath, bandPaint);

    // 2. Triple stroke lines around the illuminated border band
    final thickGoldStroke = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final thinGoldStroke = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(outerRRect, thickGoldStroke);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(5.0), const Radius.circular(8.5)),
      thinGoldStroke,
    );
    canvas.drawRRect(innerClearRRect, thickGoldStroke);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(17.0), const Radius.circular(6.5)),
      thinGoldStroke,
    );

    // 3. Repeating geometric diamond/star chain along top, bottom, left, and right borders
    final dotFill = Paint()
      ..color = primaryColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    final chainStroke = Paint()
      ..color = primaryColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    const step = 22.0;
    // Top & Bottom border bands
    for (double x = 28.0; x < size.width - 28.0; x += step) {
      _drawSmallDiamond(canvas, Offset(x, 8.0), 3.6, chainStroke, dotFill);
      _drawSmallDiamond(
        canvas,
        Offset(x, size.height - 8.0),
        3.6,
        chainStroke,
        dotFill,
      );
    }

    // Left & Right border bands
    for (double y = 32.0; y < size.height - 32.0; y += step) {
      _drawSmallDiamond(canvas, Offset(8.0, y), 3.6, chainStroke, dotFill);
      _drawSmallDiamond(
        canvas,
        Offset(size.width - 8.0, y),
        3.6,
        chainStroke,
        dotFill,
      );
    }

    // 4. Four Corner Shamsa Rosettes (شمسات الأركان الأربعة)
    final corners = [
      const Offset(13.0, 13.0),
      Offset(size.width - 13.0, 13.0),
      Offset(13.0, size.height - 13.0),
      Offset(size.width - 13.0, size.height - 13.0),
    ];
    for (final c in corners) {
      _drawRosetteStar(
        canvas,
        c,
        10.5,
        primaryColor,
        secondaryColor,
        pageBackground,
      );
    }

    // 5. Mid-Side Medallions (شمسات منتصف الصفحة يميناً ويساراً)
    final midY = size.height / 2;
    _drawRosetteStar(
      canvas,
      Offset(10.0, midY),
      9.5,
      primaryColor,
      secondaryColor,
      fillColor,
    );
    _drawRosetteStar(
      canvas,
      Offset(size.width - 10.0, midY),
      9.5,
      primaryColor,
      secondaryColor,
      fillColor,
    );
  }

  void _drawSmallDiamond(
    Canvas canvas,
    Offset center,
    double r,
    Paint stroke,
    Paint fill,
  ) {
    final path = Path()
      ..moveTo(center.dx, center.dy - r)
      ..lineTo(center.dx + r, center.dy)
      ..lineTo(center.dx, center.dy + r)
      ..lineTo(center.dx - r, center.dy)
      ..close();
    canvas.drawPath(path, stroke);
    canvas.drawCircle(center, 1.2, fill);
  }

  @override
  bool shouldRepaint(covariant _OpeningSpreadIlluminatedPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.pageBackground != pageBackground;
  }
}

/// Ornamental bottom Surah info cartouche on Pages 1 & 2.
class _SurahFooterCartouchePainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final Color fillColor;
  final Color pageBackground;

  const _SurahFooterCartouchePainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.fillColor,
    required this.pageBackground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (rect.isEmpty) return;

    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1.0),
      const Radius.circular(8.0),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(3.5), const Radius.circular(5.5)),
      Paint()
        ..color = secondaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    final cy = size.height / 2;
    for (final cx in [52.0, size.width - 52.0]) {
      if (cx > 16 && cx < size.width - 16) {
        final badgeRect = Rect.fromCenter(
          center: Offset(cx, cy),
          width: 72,
          height: (size.height - 10).clamp(12.0, 28.0),
        );
        final badgeRRect = RRect.fromRectAndRadius(
          badgeRect,
          Radius.circular(badgeRect.height / 2),
        );
        canvas.drawRRect(
          badgeRRect,
          Paint()..color = pageBackground.withValues(alpha: 0.78),
        );
        canvas.drawRRect(
          badgeRRect,
          Paint()
            ..color = secondaryColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9,
        );
      }
    }

    _drawRosetteStar(
      canvas,
      Offset(11.0, cy),
      5.0,
      primaryColor,
      secondaryColor,
      pageBackground,
    );
    _drawRosetteStar(
      canvas,
      Offset(size.width - 11.0, cy),
      5.0,
      primaryColor,
      secondaryColor,
      pageBackground,
    );
  }

  @override
  bool shouldRepaint(covariant _SurahFooterCartouchePainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.fillColor != fillColor;
  }
}

void _drawRosetteStar(
  Canvas canvas,
  Offset center,
  double radius,
  Color primaryColor,
  Color secondaryColor,
  Color centerFillColor,
) {
  final path = Path();
  const points = 8;
  for (int i = 0; i < points * 2; i++) {
    final r = i.isEven ? radius : radius * 0.52;
    final angle = (i * math.pi) / points;
    final x = center.dx + r * math.cos(angle);
    final y = center.dy + r * math.sin(angle);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();

  canvas.drawPath(
    path,
    Paint()
      ..color = secondaryColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill,
  );
  canvas.drawPath(
    path,
    Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1,
  );
  canvas.drawCircle(
    center,
    radius * 0.32,
    Paint()
      ..color = centerFillColor
      ..style = PaintingStyle.fill,
  );
  canvas.drawCircle(
    center,
    radius * 0.32,
    Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9,
  );
}

/// Custom single-pointer gesture recognizer for [TextSpan] that recognizes both
/// a short tap ([onTap]) and a long press ([onLongPress]), while rejecting
/// immediately if the user drags/swipes (preserving smooth [PageView] swiping).
class _WordTapAndLongPressRecognizer extends PrimaryPointerGestureRecognizer {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  bool _longPressFired = false;

  _WordTapAndLongPressRecognizer({this.onTap, this.onLongPress})
    : super(deadline: kLongPressTimeout);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _longPressFired = false;
    super.addAllowedPointer(event);
  }

  @override
  void didExceedDeadline() {
    if (onLongPress != null) {
      _longPressFired = true;
      resolve(GestureDisposition.accepted);
      onLongPress!();
    }
  }

  @override
  void handlePrimaryPointer(PointerEvent event) {
    if (event is PointerUpEvent) {
      if (!_longPressFired) {
        if (onTap != null) {
          resolve(GestureDisposition.accepted);
          onTap!();
        } else {
          resolve(GestureDisposition.rejected);
        }
      }
    } else if (event is PointerCancelEvent) {
      resolve(GestureDisposition.rejected);
    }
  }

  @override
  String get debugDescription => 'word tap and long press';
}

/// Compact ornamental Ayah end-marker medallion whose circle and surrounding
/// Islamic rosette ornaments use the active theme's accent color while keeping
/// the Eastern Arabic ayah number crisp and readable inside.
class _AyahNumberOrnament extends StatelessWidget {
  final String digits;
  final double width;
  final double height;
  final double digitFontSize;
  final Color ornamentColor;
  final Color secondaryOrnamentColor;
  final Color digitColor;
  final bool isSelected;
  final bool isDark;

  const _AyahNumberOrnament({
    required this.digits,
    required this.width,
    required this.height,
    required this.digitFontSize,
    required this.ornamentColor,
    required this.secondaryOrnamentColor,
    required this.digitColor,
    required this.isSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Keep digits comfortably inset inside the inner double-ring medallion
    final innerW = width * 0.48;
    final innerH = height * 0.44;

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _AyahOrnamentPainter(
          primaryColor: ornamentColor,
          secondaryColor: secondaryOrnamentColor,
          isSelected: isSelected,
          isDark: isDark,
        ),
        child: Center(
          child: SizedBox(
            width: innerW,
            height: innerH,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: RichText(
                textDirection: TextDirection.ltr,
                maxLines: 1,
                text: TextSpan(
                  text: digits,
                  style: TextStyle(
                    fontSize: digitFontSize,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    color: digitColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AyahOrnamentPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final bool isSelected;
  final bool isDark;

  const _AyahOrnamentPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.isSelected,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width / 2;
    final ry = size.height / 2;
    final minDim = math.min(size.width, size.height);

    // Proportions for an authentic Madinah Mushaf 12-petal Shamsa rosette
    final innerRx = rx * 0.65;
    final innerRy = ry * 0.60;

    // 1. Delicate 12-petal scalloped lotus rosette outer silhouette
    final rosettePath = Path();
    const petals = 12;
    final petalOuterRx = rx * 0.90;
    final petalOuterRy = ry * 0.80;
    final petalValleyRx = rx * 0.77;
    final petalValleyRy = ry * 0.69;

    for (int i = 0; i < petals; i++) {
      final a0 = (i * 2 * math.pi) / petals - math.pi / 2;
      final aMid = ((i + 0.5) * 2 * math.pi) / petals - math.pi / 2;
      final a1 = ((i + 1) * 2 * math.pi) / petals - math.pi / 2;

      final sx = cx + petalValleyRx * math.cos(a0);
      final sy = cy + petalValleyRy * math.sin(a0);
      final ctrlX = cx + (petalOuterRx * 1.06) * math.cos(aMid);
      final ctrlY = cy + (petalOuterRy * 1.06) * math.sin(aMid);
      final ex = cx + petalValleyRx * math.cos(a1);
      final ey = cy + petalValleyRy * math.sin(a1);

      if (i == 0) {
        rosettePath.moveTo(sx, sy);
      }
      rosettePath.quadraticBezierTo(ctrlX, ctrlY, ex, ey);
    }
    rosettePath.close();

    // Soft radial illuminated fill inside the scalloped rosette
    final outerRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: size.width,
      height: size.height,
    );
    canvas.drawPath(
      rosettePath,
      Paint()
        ..shader = RadialGradient(
          colors: [
            primaryColor.withValues(
              alpha: isSelected ? 0.24 : (isDark ? 0.14 : 0.06),
            ),
            secondaryColor.withValues(
              alpha: isSelected ? 0.36 : (isDark ? 0.26 : 0.22),
            ),
          ],
          stops: const [0.45, 1.0],
        ).createShader(outerRect)
        ..style = PaintingStyle.fill,
    );

    // Fine scalloped lace border in theme accent color
    canvas.drawPath(
      rosettePath,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (minDim * 0.036).clamp(0.75, 1.5)
        ..strokeJoin = StrokeJoin.round,
    );

    // 2. Delicate pearl/bead dots nestled inside each of the 12 lotus petals
    final pearlRadius = (minDim * 0.025).clamp(0.55, 1.15);
    final pearlPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < petals; i++) {
      final aMid = ((i + 0.5) * 2 * math.pi) / petals - math.pi / 2;
      final px = cx + (rx * 0.77) * math.cos(aMid);
      final py = cy + (ry * 0.69) * math.sin(aMid);
      canvas.drawCircle(Offset(px, py), pearlRadius, pearlPaint);
    }

    // 3. Double-ringed inner medallion framing the Eastern Arabic Ayah number
    final innerRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: innerRx * 2,
      height: innerRy * 2,
    );
    canvas.drawOval(
      innerRect,
      Paint()
        ..color = primaryColor.withValues(
          alpha: isSelected ? 0.20 : (isDark ? 0.12 : 0.05),
        )
        ..style = PaintingStyle.fill,
    );
    // Primary inner ring
    canvas.drawOval(
      innerRect,
      Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (minDim * 0.048).clamp(0.95, 1.9),
    );
    // Delicate secondary concentric inner hairline ring
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: innerRx * 1.78,
        height: innerRy * 1.78,
      ),
      Paint()
        ..color = secondaryColor.withValues(alpha: isDark ? 0.65 : 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (minDim * 0.022).clamp(0.5, 0.9),
    );

    // 4. Graceful classical Madinah Mushaf teardrop crown finials (12 & 6 o'clock)
    final finialFill = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    final finialTipY = ry * 0.99;
    final finialNeckY = ry * 0.76;
    final finialBulgeX = rx * 0.13;

    final topCrown = Path()
      ..moveTo(cx, cy - finialTipY)
      ..quadraticBezierTo(
        cx + finialBulgeX,
        cy - ry * 0.86,
        cx + finialBulgeX * 0.55,
        cy - finialNeckY,
      )
      ..lineTo(cx - finialBulgeX * 0.55, cy - finialNeckY)
      ..quadraticBezierTo(
        cx - finialBulgeX,
        cy - ry * 0.86,
        cx,
        cy - finialTipY,
      )
      ..close();
    canvas.drawPath(topCrown, finialFill);

    final bottomCrown = Path()
      ..moveTo(cx, cy + finialTipY)
      ..quadraticBezierTo(
        cx + finialBulgeX,
        cy + ry * 0.86,
        cx + finialBulgeX * 0.55,
        cy + finialNeckY,
      )
      ..lineTo(cx - finialBulgeX * 0.55, cy + finialNeckY)
      ..quadraticBezierTo(
        cx - finialBulgeX,
        cy + ry * 0.86,
        cx,
        cy + finialTipY,
      )
      ..close();
    canvas.drawPath(bottomCrown, finialFill);

    // 5. Subtle side flourish buds at 3 & 9 o'clock
    final sideHalf = (minDim * 0.055).clamp(1.0, 2.2);
    for (final sign in const [-1.0, 1.0]) {
      final sx = cx + sign * (rx * 0.95);
      final bud = Path()
        ..moveTo(sx + sign * sideHalf * 0.75, cy)
        ..lineTo(sx - sign * sideHalf * 0.4, cy - sideHalf * 0.65)
        ..lineTo(sx - sign * sideHalf * 0.9, cy)
        ..lineTo(sx - sign * sideHalf * 0.4, cy + sideHalf * 0.65)
        ..close();
      canvas.drawPath(bud, finialFill);
    }
  }

  @override
  bool shouldRepaint(covariant _AyahOrnamentPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.isDark != isDark;
  }
}
