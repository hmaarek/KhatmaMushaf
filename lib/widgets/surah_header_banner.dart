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

  /// When true (used on Pages 1 & 2), renders the classic floral rosette & arabesque
  /// wings with a wide central calligraphic cartouche matching the traditional Mushaf opening.
  final bool openingSpreadStyle;

  const SurahHeaderBanner({
    super.key,
    required this.surahId,
    required this.headerText,
    required this.theme,
    this.surahInfo,
    this.compact = false,
    this.openingSpreadStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final surahCode = surahId.toString().padLeft(3, '0');
    final ayahCount = surahInfo?.ayahCount;
    final revelationAr = surahInfo?.revelationArabic ?? '';

    if (openingSpreadStyle) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        child: CustomPaint(
          painter: _OpeningSurahBannerPainter(
            primaryColor: theme.ornamentPrimary,
            secondaryColor: theme.ornamentSecondary,
            fillColor: theme.ornamentFill,
            pageBackground: theme.pageBackground,
          ),
          child: SizedBox.expand(
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.44,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6.0,
                      vertical: 3.0,
                    ),
                    child: Text(
                      surahCode,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontFamily: 'Surahs',
                        fontSize: 34,
                        height: 1.0,
                        color: theme.glyphColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

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

/// Ornate floral rosette & arabesque banner painter for Pages 1 & 2,
/// modeled after the classic Mushaf Surah Al-Fatihah header banner.
class _OpeningSurahBannerPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final Color fillColor;
  final Color pageBackground;

  const _OpeningSurahBannerPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.fillColor,
    required this.pageBackground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (rect.isEmpty) return;

    final outerStroke = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final innerStroke = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final wingFill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    // 1. Outer double-bordered frame
    final outerRRect = RRect.fromRectAndRadius(
      rect.deflate(1.0),
      const Radius.circular(6.0),
    );
    final innerRect = rect.deflate(4.0);
    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      const Radius.circular(4.0),
    );

    canvas.drawRRect(outerRRect, Paint()..color = pageBackground);
    canvas.drawRRect(innerRRect, wingFill);
    canvas.drawRRect(outerRRect, outerStroke);
    canvas.drawRRect(innerRRect, innerStroke);

    // 2. Central scalloped calligraphic cartouche (الجامة الوسطى لاسم السورة)
    final cartoucheWidth = size.width * 0.44;
    final leftX = (size.width - cartoucheWidth) / 2;
    final rightX = leftX + cartoucheWidth;
    final topY = innerRect.top;
    final bottomY = innerRect.bottom;
    final cy = size.height / 2;
    final notch = (innerRect.height * 0.22).clamp(6.0, 12.0);

    final cartouchePath = Path()
      ..moveTo(leftX + notch, topY)
      ..lineTo(rightX - notch, topY)
      ..quadraticBezierTo(rightX - notch * 0.2, topY + notch * 0.8, rightX, topY + notch)
      ..lineTo(rightX, bottomY - notch)
      ..quadraticBezierTo(rightX - notch * 0.2, bottomY - notch * 0.8, rightX - notch, bottomY)
      ..lineTo(leftX + notch, bottomY)
      ..quadraticBezierTo(leftX + notch * 0.2, bottomY - notch * 0.8, leftX, bottomY - notch)
      ..lineTo(leftX, topY + notch)
      ..quadraticBezierTo(leftX + notch * 0.2, topY + notch * 0.8, leftX + notch, topY)
      ..close();

    canvas.drawPath(cartouchePath, Paint()..color = pageBackground);
    canvas.drawPath(cartouchePath, outerStroke);

    // 3. Draw 12-petal floral rosette & symmetric arabesque scrolls in Left & Right wings
    final leftWingCenter = Offset(innerRect.left + (leftX - innerRect.left) / 2, cy);
    final rightWingCenter = Offset(rightX + (innerRect.right - rightX) / 2, cy);
    final rosetteRadius = (innerRect.height * 0.36).clamp(8.0, 16.0);

    for (final wingCenter in [leftWingCenter, rightWingCenter]) {
      _drawArabesqueScrolls(
        canvas,
        wingCenter,
        (leftX - innerRect.left) * 0.44,
        innerRect.height * 0.38,
        primaryColor,
        secondaryColor,
      );
      _drawFloralRosette(
        canvas,
        wingCenter,
        rosetteRadius,
        primaryColor,
        secondaryColor,
        pageBackground,
      );
    }
  }

  void _drawFloralRosette(
    Canvas canvas,
    Offset center,
    double radius,
    Color primary,
    Color secondary,
    Color bg,
  ) {
    const petals = 12;
    final petalFill = Paint()
      ..color = bg.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    final petalStroke = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < petals; i++) {
      final angle = (i * 2 * math.pi) / petals;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      final petalRect = Rect.fromCenter(
        center: Offset(radius * 0.55, 0),
        width: radius * 0.85,
        height: radius * 0.36,
      );
      final rrect = RRect.fromRectAndRadius(
        petalRect,
        Radius.circular(radius * 0.2),
      );
      canvas.drawRRect(rrect, petalFill);
      canvas.drawRRect(rrect, petalStroke);
      canvas.restore();
    }

    canvas.drawCircle(
      center,
      radius * 0.26,
      Paint()..color = secondary.withValues(alpha: 0.55),
    );
    canvas.drawCircle(center, radius * 0.26, petalStroke);
  }

  void _drawArabesqueScrolls(
    Canvas canvas,
    Offset center,
    double halfSpanX,
    double halfSpanY,
    Color primary,
    Color secondary,
  ) {
    final scrollStroke = Paint()
      ..color = primary.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;

    final leafFill = Paint()
      ..color = secondary.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;

    for (final dirX in [-1.0, 1.0]) {
      for (final dirY in [-1.0, 1.0]) {
        final p = Path()
          ..moveTo(center.dx + dirX * 4, center.dy)
          ..cubicTo(
            center.dx + dirX * (halfSpanX * 0.45),
            center.dy + dirY * (halfSpanY * 0.95),
            center.dx + dirX * (halfSpanX * 0.80),
            center.dy + dirY * (halfSpanY * 0.85),
            center.dx + dirX * (halfSpanX * 0.96),
            center.dy + dirY * (halfSpanY * 0.20),
          );
        canvas.drawPath(p, scrollStroke);

        // Secondary inner tendril
        final p2 = Path()
          ..moveTo(center.dx + dirX * (halfSpanX * 0.35), center.dy)
          ..quadraticBezierTo(
            center.dx + dirX * (halfSpanX * 0.65),
            center.dy + dirY * (halfSpanY * 0.55),
            center.dx + dirX * (halfSpanX * 0.92),
            center.dy + dirY * (halfSpanY * 0.72),
          );
        canvas.drawPath(p2, scrollStroke);

        // Small ornamental leaf bud near outer edge
        canvas.drawCircle(
          Offset(
            center.dx + dirX * (halfSpanX * 0.85),
            center.dy + dirY * (halfSpanY * 0.48),
          ),
          2.2,
          leafFill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OpeningSurahBannerPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.pageBackground != pageBackground;
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
    const leftCx = 52.0;
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
