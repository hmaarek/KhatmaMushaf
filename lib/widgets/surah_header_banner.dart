import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/mushaf_models.dart';
import '../theme/mushaf_theme.dart';

class SurahHeaderBanner extends StatelessWidget {
  final int surahId;
  final String headerText;
  final SurahInfo? surahInfo;
  final MushafThemeData theme;
  final bool compact;
  final bool openingSpreadStyle;

  const SurahHeaderBanner({
    super.key,
    required this.surahId,
    required this.headerText,
    required this.theme,
    this.surahInfo,
    this.compact = false,
    this.openingSpreadStyle = true,
  });

  @override
  Widget build(BuildContext context) {
    final clampedId = surahId.clamp(1, 114);
    // Direct PUA codepoint (0xE001..0xE072) mapped in assets/fonts/Surahs.ttf
    // to the normalized full-height calligraphic "سُورَةُ ..." glyph.
    final surahCalligraphyChar = String.fromCharCode(0xE000 + clampedId);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 2.0 : 4.0,
        vertical: compact ? 0.5 : 1.5,
      ),
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
              widthFactor: 0.46,
              heightFactor: 0.86,
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: Text(
                  surahCalligraphyChar,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: 'Surahs',
                    fontSize: 64,
                    height: 1.0,
                    color: theme.glyphColor,
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

/// Decorative illuminated calligraphy artwork displaying "أعوذ بالله من الشيطان الرجيم"
/// at app startup for 2 seconds or until touched by the user.
class IstiadhahStartupBanner extends StatelessWidget {
  final MushafThemeData theme;
  final VoidCallback? onTap;

  const IstiadhahStartupBanner({
    super.key,
    required this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cardWidth = (screenSize.width * 0.78).clamp(240.0, 360.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.ornamentPrimary,
            width: 2.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 1116 / 2000,
            child: Image.asset(
              'assets/images/istiadhah_banner.jpg',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ornate floral rosette & arabesque banner painter for all 114 Surah headers,
/// modeled after the classic Mushaf Surah header banner.
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
    final innerRect = rect.deflate(3.5);
    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      const Radius.circular(4.0),
    );

    canvas.drawRRect(outerRRect, Paint()..color = pageBackground);
    canvas.drawRRect(innerRRect, wingFill);
    canvas.drawRRect(outerRRect, outerStroke);
    canvas.drawRRect(innerRRect, innerStroke);

    // 2. Central scalloped calligraphic cartouche (الجامة الوسطى لاسم السورة)
    final cartoucheWidth = size.width * 0.50;
    final leftX = (size.width - cartoucheWidth) / 2;
    final rightX = leftX + cartoucheWidth;
    final topY = innerRect.top;
    final bottomY = innerRect.bottom;
    final cy = size.height / 2;
    final notch = (innerRect.height * 0.22).clamp(5.0, 11.0);

    final cartouchePath = Path()
      ..moveTo(leftX + notch, topY)
      ..lineTo(rightX - notch, topY)
      ..quadraticBezierTo(
        rightX - notch * 0.2,
        topY + notch * 0.8,
        rightX,
        topY + notch,
      )
      ..lineTo(rightX, bottomY - notch)
      ..quadraticBezierTo(
        rightX - notch * 0.2,
        bottomY - notch * 0.8,
        rightX - notch,
        bottomY,
      )
      ..lineTo(leftX + notch, bottomY)
      ..quadraticBezierTo(
        leftX + notch * 0.2,
        bottomY - notch * 0.8,
        leftX,
        bottomY - notch,
      )
      ..lineTo(leftX, topY + notch)
      ..quadraticBezierTo(
        leftX + notch * 0.2,
        topY + notch * 0.8,
        leftX + notch,
        topY,
      )
      ..close();

    canvas.drawPath(cartouchePath, Paint()..color = pageBackground);
    canvas.drawPath(cartouchePath, outerStroke);

    // 3. Draw 12-petal floral rosette & symmetric arabesque scrolls in Left & Right wings
    final leftWingCenter = Offset(
      innerRect.left + (leftX - innerRect.left) / 2,
      cy,
    );
    final rightWingCenter = Offset(
      rightX + (innerRect.right - rightX) / 2,
      cy,
    );
    final rosetteRadius = (innerRect.height * 0.36).clamp(7.0, 15.0);

    for (final wingCenter in [leftWingCenter, rightWingCenter]) {
      _drawArabesqueScrolls(
        canvas,
        wingCenter,
        (leftX - innerRect.left) * 0.45,
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
      ..color = bg.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    final petalStroke = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.95;

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
      ..color = primary.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final leafFill = Paint()
      ..color = secondary.withValues(alpha: 0.32)
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
          2.0,
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
