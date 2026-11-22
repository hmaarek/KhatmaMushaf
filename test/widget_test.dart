import 'package:flutter_test/flutter_test.dart';
import 'package:mushaf_app/main.dart';
import 'package:mushaf_app/services/font_loader_service.dart';
import 'package:mushaf_app/state/mushaf_controller.dart';
import 'package:mushaf_app/theme/mushaf_theme.dart';
import 'package:mushaf_app/utils/arabic_utils.dart';

void main() {
  test('ArabicUtils converts digits and normalizes Uthmani Arabic text', () {
    expect(ArabicUtils.toArabicDigits(1), '١');
    expect(ArabicUtils.toArabicDigits(604), '٦٠٤');

    const uthmani = 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ';
    expect(ArabicUtils.normalizeForSearch(uthmani), 'الحمد لله رب العلمين');

    expect(QpcFontLoaderService.fontFamilyForPage(1), 'QCF4_Hafs_01');
    expect(QpcFontLoaderService.fontFamilyForPage(604), 'QCF4_Hafs_47');
  });

  test('MushafThemeData provides all 3 reading themes', () {
    expect(MushafThemeData.all.length, 3);
    expect(
      MushafThemeData.fromType(MushafThemeType.warmPaper).name,
      'Warm Paper',
    );
    expect(
      MushafThemeData.fromType(MushafThemeType.crispWhite).name,
      'Crisp White',
    );
    expect(
      MushafThemeData.fromType(
        MushafThemeType.amoledDark,
      ).pageBackground.toARGB32(),
      0xFF000000,
    );
  });

  testWidgets('MushafApp renders loading state cleanly', (
    WidgetTester tester,
  ) async {
    final controller = MushafController();
    await tester.pumpWidget(MushafApp(controller: controller));
    expect(find.text('جاري فتح المصحف الشريف...'), findsOneWidget);
  });
}
