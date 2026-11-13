import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/mushaf_models.dart';
import '../theme/mushaf_theme.dart';
import '../utils/arabic_utils.dart';

class SurahHeaderBanner extends StatelessWidget {
  final int surahId;
  final String headerText;
  final SurahInfo? surahInfo;
  final MushafThemeData theme;
  final bool compact;

  const SurahHeaderBanner({
    super.key,
    required this.surahId,
    required this.headerText,
    required this.theme,
    this.surahInfo,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final surahCode = surahId.toString().padLeft(3, '0');
    final ayahCount = surahInfo?.ayahCount;
    final revelationAr = surahInfo?.revelationArabic ?? '';

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 2.0 : 4.0,
        vertical: compact ? 1.0 : 2.0,
      ),
      child: CustomPaint(
        painter: _SurahBannerOrnamentPainter(
          primaryColor: theme.ornamentPrimary,
          secondaryColor: theme.ornamentSecondary,
          fillColor: theme.ornamentFill,
          pageBackground: theme.pageBackground,
        ),
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left rosette: Ayah count
                _SideBadge(
                  text: ayahCount != null
                      ? 'آياتها ${ArabicUtils.toArabicDigits(ayahCount)}'
                      : 'سورة',
                  theme: theme,
                ),
                // Center cartouche: Calligraphic Surah title rendered with Surahs.ttf
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.0,
                        ),
                        child: Text(
                          surahCode,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontFamily: 'Surahs',
                            fontSize: compact ? 24 : 28,
                            height: 1.05,
                            color: theme.glyphColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Right rosette: Surah order & revelation place
                _SideBadge(
                  text: revelationAr.isNotEmpty
                      ? '$revelationAr • ${ArabicUtils.toArabicDigits(surahId)}'
                      : 'رقم ${ArabicUtils.toArabicDigits(surahId)}',
                  theme: theme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SideBadge extends StatelessWidget {
  final String text;
  final MushafThemeData theme;

  const _SideBadge({
    required this.text,
    required this.theme,
  });

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
              fontWeight: FontWeight.w600,
              color: theme.secondaryTextColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _SurahBannerOrnamentPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final Color fillColor;
  final Color pageBackground;

  const _SurahBannerOrnamentPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.fillColor,
    required this.pageBackground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (rect.isEmpty) return;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final outerStroke = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final innerStroke = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1.0),
      const Radius.circular(6.0),
    );
    canvas.drawRRect(rrect, fillPaint);
    canvas.drawRRect(rrect, outerStroke);

    final innerRRect = RRect.fromRectAndRadius(
      rect.deflate(3.5),
      const Radius.circular(4.0),
    );
    canvas.drawRRect(innerRRect, innerStroke);

    // Draw side geometric medallions and center cartouche arches
    final cy = size.height / 2;
    final leftCx = 52.0;
    final rightCx = size.width - 52.0;

    for (final cx in [leftCx, rightCx]) {
      if (cx > 16 && cx < size.width - 16) {
        final badgeRect = Rect.fromCenter(
          center: Offset(cx, cy),
          width: 76,
          height: (size.height - 8).clamp(10.0, 32.0),
        );
        final badgeRRect = RRect.fromRectAndRadius(
          badgeRect,
          Radius.circular(badgeRect.height / 2),
        );
        canvas.drawRRect(
          badgeRRect,
          Paint()..color = pageBackground.withValues(alpha: 0.7),
        );
        canvas.drawRRect(badgeRRect, innerStroke);
      }
    }

    // Subtle eight-point star accents near left and right edges
    _drawStar(canvas, Offset(10, cy), 4.5, primaryColor);
    _drawStar(canvas, Offset(size.width - 10, cy), 4.5, primaryColor);
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final path = Path();
    const points = 8;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.45;
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
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SurahBannerOrnamentPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.pageBackground != pageBackground;
  }
}
