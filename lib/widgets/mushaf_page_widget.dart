import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/mushaf_models.dart';
import '../services/font_loader_service.dart';
import '../state/mushaf_controller.dart';
import '../theme/mushaf_theme.dart';
import '../utils/arabic_utils.dart';
import 'surah_header_banner.dart';

class MushafPageWidget extends StatefulWidget {
  final int pageNumber;
  final MushafController controller;
  final VoidCallback onCenterTap;
  final ValueChanged<String> onAyahLongPress;

  const MushafPageWidget({
    super.key,
    required this.pageNumber,
    required this.controller,
    required this.onCenterTap,
    required this.onAyahLongPress,
  });

  @override
  State<MushafPageWidget> createState() => _MushafPageWidgetState();
}

class _MushafPageWidgetState extends State<MushafPageWidget> {
  Future<MushafPageData>? _loadFuture;
  final List<LongPressGestureRecognizer> _recognizers =
      <LongPressGestureRecognizer>[];

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.controller.loadPageAndFont(widget.pageNumber);
  }

  @override
  void didUpdateWidget(covariant MushafPageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageNumber != widget.pageNumber) {
      _disposeRecognizers();
      _loadFuture = widget.controller.loadPageAndFont(widget.pageNumber);
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
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.controller.theme;
    final cached = widget.controller.currentPage == widget.pageNumber
        ? widget.controller.currentPageData
        : null;
    final fontLoaded =
        QpcFontLoaderService.instance.isPageFontLoaded(widget.pageNumber);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onCenterTap,
      child: Container(
        color: theme.scaffoldBackground,
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
        child: FutureBuilder<MushafPageData>(
          initialData: (cached != null && fontLoaded) ? cached : null,
          future: _loadFuture,
          builder: (context, snapshot) {
            final pageData = snapshot.data;
            if (pageData == null) {
              return _buildLoadingSkeleton(theme);
            }
            return _buildPageFrame(context, pageData, theme);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(MushafThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.pageBackground,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: theme.pageOuterBorder, width: 1.5),
      ),
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
    MushafThemeData theme,
  ) {
    final info = pageData.info;
    final isBookmarked = widget.controller.isPageBookmarked(widget.pageNumber);

    return Stack(
      children: [
        CustomPaint(
          painter: _MushafFramePainter(
            pageBackground: theme.pageBackground,
            outerBorder: theme.pageOuterBorder,
            innerBorder: theme.pageInnerBorder,
            ornamentFill: theme.ornamentFill,
            isCenteredPage: info.isCentered,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14.0, 10.0, 14.0, 8.0),
            child: Column(
              children: [
                // Top running header inside Mushaf margin
                _buildRunningHeader(info, theme),
                const SizedBox(height: 4.0),
                // Main Mushaf body: centered layout for Pages 1 & 2, 15-line layout for Pages 3-604
                Expanded(
                  child: info.isCentered
                      ? _buildCenteredSpecialPage(pageData, theme)
                      : _buildStandard15LineBody(pageData, theme),
                ),
                const SizedBox(height: 4.0),
                // Bottom page number in ornamental cartouche
                _buildFooterPageNumber(info.pageNumber, theme),
              ],
            ),
          ),
        ),
        // Subtle bookmark ribbon at top-left of page when page is bookmarked
        if (isBookmarked)
          Positioned(
            top: 0,
            left: 24,
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
      height: 22,
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

  /// Pages 1 & 2 (Al-Fatihah & opening of Al-Baqarah) centered ornamental layout.
  Widget _buildCenteredSpecialPage(
    MushafPageData pageData,
    MushafThemeData theme,
  ) {
    _disposeRecognizers();
    final fontFamily = QpcFontLoaderService.fontFamilyForPage(widget.pageNumber);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: constraints.maxHeight * 0.78,
              maxWidth: constraints.maxWidth * 0.94,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 16.0,
            ),
            decoration: BoxDecoration(
              color: theme.pageBackground,
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(
                color: theme.ornamentPrimary,
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.ornamentPrimary.withValues(alpha: 0.08),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: pageData.lines.map((line) {
                if (line.isSurahHeader) {
                  return SizedBox(
                    height: 46,
                    child: SurahHeaderBanner(
                      surahId: line.surahId ?? 1,
                      headerText: line.headerText ?? '',
                      surahInfo:
                          widget.controller.getSurahById(line.surahId ?? 1),
                      theme: theme,
                    ),
                  );
                } else if (line.isBasmala) {
                  return SizedBox(
                    height: 36,
                    child: _buildBasmalaLine(theme, fontSize: 26),
                  );
                } else {
                  return Expanded(
                    child: Center(
                      child: _buildTextLine(
                        line: line,
                        fontFamily: fontFamily,
                        theme: theme,
                        centered: true,
                        baseFontSize: 27.0,
                      ),
                    ),
                  );
                }
              }).toList(growable: false),
            ),
          ),
        );
      },
    );
  }

  /// Pages 3–604 authentic 15-line Madinah Mushaf layout.
  Widget _buildStandard15LineBody(
    MushafPageData pageData,
    MushafThemeData theme,
  ) {
    _disposeRecognizers();
    final fontFamily = QpcFontLoaderService.fontFamilyForPage(widget.pageNumber);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      child: Column(
        children: pageData.lines.map((line) {
          return Expanded(
            child: _buildStandardLineSlot(line, fontFamily, theme),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildStandardLineSlot(
    MushafPageLine line,
    String fontFamily,
    MushafThemeData theme,
  ) {
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
      return _buildBasmalaLine(theme, fontSize: 23.0);
    }
    return _buildTextLine(
      line: line,
      fontFamily: fontFamily,
      theme: theme,
      centered: false,
      baseFontSize: 25.5,
    );
  }

  Widget _buildBasmalaLine(MushafThemeData theme, {required double fontSize}) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'ﭑﭒﭓ',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'QPC1BSML',
            fontSize: fontSize,
            height: 1.0,
            color: theme.glyphColor,
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
    final selectedVerse = widget.controller.selectedVerseKey;
    final spans = <InlineSpan>[];

    for (int i = 0; i < line.words.length; i++) {
      final word = line.words[i];
      final isSelected = selectedVerse == word.verseKey;
      final isBookmarkedAyah =
          widget.controller.isAyahBookmarked(word.verseKey);

      final recognizer = LongPressGestureRecognizer()
        ..onLongPress = () {
          widget.controller.selectVerse(word.verseKey);
          widget.onAyahLongPress(word.verseKey);
        };
      _recognizers.add(recognizer);

      Color? bgColor;
      if (isSelected) {
        bgColor = theme.ayahHighlightFill;
      } else if (isBookmarkedAyah) {
        bgColor = theme.ayahHighlightFill.withValues(alpha: 0.14);
      }

      spans.add(
        TextSpan(
          text: i < line.words.length - 1 ? '${word.qpcV1} ' : word.qpcV1,
          recognizer: recognizer,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: baseFontSize,
            height: 1.15,
            color: isSelected ? theme.ornamentPrimary : theme.glyphColor,
            backgroundColor: bgColor,
          ),
        ),
      );
    }

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

  Widget _buildFooterPageNumber(int pageNumber, MushafThemeData theme) {
    return SizedBox(
      height: 22,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 1.5),
          decoration: BoxDecoration(
            color: theme.ornamentFill,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: theme.pageInnerBorder,
              width: 1.0,
            ),
          ),
          child: Text(
            ArabicUtils.toArabicDigits(pageNumber),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: theme.secondaryTextColor,
              height: 1.1,
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
      ..strokeWidth = 1.8;

    final innerStroke = Paint()
      ..color = innerBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    final outerRRect = RRect.fromRectAndRadius(
      rect.deflate(2.0),
      const Radius.circular(8.0),
    );
    canvas.drawRRect(outerRRect, bgPaint);
    canvas.drawRRect(outerRRect, outerStroke);

    final innerRRect = RRect.fromRectAndRadius(
      rect.deflate(6.0),
      const Radius.circular(5.0),
    );
    canvas.drawRRect(innerRRect, innerStroke);

    // Subtle corner floral/geometric accents
    const cornerOffset = 10.0;
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
      canvas.drawCircle(c, 2.2, dotPaint);
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
