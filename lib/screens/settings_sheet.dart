import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/quran_audio_service.dart';
import '../state/mushaf_controller.dart';
import '../theme/mushaf_theme.dart';
import 'onboarding_screen.dart';

class SettingsSheet extends StatelessWidget {
  final MushafController controller;

  const SettingsSheet({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final theme = controller.theme;
        final currentScaleMode = controller.fontScaleMode;

        return Directionality(
          textDirection: L10n.dir,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.86,
            ),
            decoration: BoxDecoration(
              color: theme.pageBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(color: theme.pageOuterBorder, width: 1.4),
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
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              color: theme.ornamentPrimary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tr(
                                'إعدادات العرض والقراءة',
                                'Display & Reading Settings',
                              ),
                              style: TextStyle(
                                color: theme.glyphColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.glyphColor,
                          ),
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
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Section 0: App Language (Arabic / English)
                          Row(
                            children: [
                              Icon(
                                Icons.language_rounded,
                                color: theme.ornamentPrimary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tr('لغة التطبيق', 'App Language'),
                                style: TextStyle(
                                  color: theme.glyphColor,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              for (final lang in [
                                (
                                  val: AppLanguage.arabic,
                                  label: 'العربية',
                                  sub: 'Arabic',
                                ),
                                (
                                  val: AppLanguage.english,
                                  label: 'English',
                                  sub: 'الإنجليزية',
                                ),
                                (
                                  val: AppLanguage.urdu,
                                  label: 'اردو',
                                  sub: 'Urdu',
                                ),
                              ])
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () =>
                                          controller.setLanguage(lang.val),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: controller.language == lang.val
                                              ? theme.ornamentPrimary
                                                    .withValues(alpha: 0.16)
                                              : theme.ornamentFill,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color:
                                                controller.language == lang.val
                                                ? theme.ornamentPrimary
                                                : theme.pageInnerBorder,
                                            width:
                                                controller.language == lang.val
                                                ? 2.0
                                                : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              controller.language == lang.val
                                                  ? Icons.check_circle_rounded
                                                  : Icons
                                                        .radio_button_off_rounded,
                                              size: 19,
                                              color:
                                                  controller.language ==
                                                      lang.val
                                                  ? theme.ornamentPrimary
                                                  : theme.secondaryTextColor,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              lang.label,
                                              style: TextStyle(
                                                color: theme.glyphColor,
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          // Mushaf Script Style (Madinah Uthmani vs Indo-Pak Nastaleeq)
                          Row(
                            children: [
                              Icon(
                                Icons.menu_book_rounded,
                                color: theme.ornamentPrimary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tr('خط المصحف', 'Mushaf Script', 'رسم الخط'),
                                style: TextStyle(
                                  color: theme.glyphColor,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              for (final scr in [
                                (
                                  val: MushafScript.uthmani,
                                  label: tr(
                                    'رسم المدينة',
                                    'Madinah Uthmani',
                                    'عثمانی رسم الخط',
                                  ),
                                ),
                                (
                                  val: MushafScript.indoPak,
                                  label: tr(
                                    'نستعلیق (برصغیر)',
                                    'Indo-Pak',
                                    'نستعلیق (برصغیر)',
                                  ),
                                ),
                              ])
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () =>
                                          controller.setMushafScript(scr.val),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              controller.mushafScript == scr.val
                                              ? theme.ornamentPrimary
                                                    .withValues(alpha: 0.16)
                                              : theme.ornamentFill,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color:
                                                controller.mushafScript ==
                                                    scr.val
                                                ? theme.ornamentPrimary
                                                : theme.pageInnerBorder,
                                            width:
                                                controller.mushafScript ==
                                                    scr.val
                                                ? 2.0
                                                : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              controller.mushafScript == scr.val
                                                  ? Icons.check_circle_rounded
                                                  : Icons
                                                        .radio_button_off_rounded,
                                              size: 18,
                                              color:
                                                  controller.mushafScript ==
                                                      scr.val
                                                  ? theme.ornamentPrimary
                                                  : theme.secondaryTextColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                scr.label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: theme.glyphColor,
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          // Section 1: Font Size & Zoom Mode
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                tr(
                                  'حجم الخط وطريقة التكبير',
                                  'Font Size & Zoom Mode',
                                ),
                                style: TextStyle(
                                  color: theme.glyphColor,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.ornamentPrimary.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tr(
                                    'التزام تام بـ ١٥ سطراً',
                                    'Strict 15-line layout',
                                  ),
                                  style: TextStyle(
                                    color: theme.ornamentPrimary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tr(
                              'جميع الخيارات تحافظ على تنسيق مصحف المدينة النبوية (١٥ سطراً في كل صفحة دون تغيير مواضع الكلمات).',
                              'All options preserve the exact 15-line Madinah Mushaf page and line layout.',
                            ),
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...MushafFontScaleMode.values.map((mode) {
                            final isSelected = mode == currentScaleMode;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: _FontScaleOptionCard(
                                mode: mode,
                                isSelected: isSelected,
                                theme: theme,
                                onTap: () => controller.setFontScaleMode(mode),
                              ),
                            );
                          }),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.ornamentFill,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: theme.pageInnerBorder),
                            ),
                            child: SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              activeThumbColor: theme.ornamentPrimary,
                              secondary: Icon(
                                Icons.format_bold_rounded,
                                color: theme.ornamentPrimary,
                              ),
                              value: controller.boldQuranFont,
                              onChanged: controller.setBoldQuranFont,
                              title: Text(
                                tr(
                                  'خط المصحف عريض',
                                  'Bold Mushaf font',
                                  'مصحف کا موٹا خط',
                                ),
                                style: TextStyle(
                                  color: theme.glyphColor,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                tr(
                                  'جعل حروف المصحف أكثر سُمكاً ووضوحاً أثناء القراءة',
                                  'Make Quranic calligraphy bolder for easier reading',
                                  'آسان قراءت کے لیے قرآن کے حروف کو زیادہ موٹا اور واضح بنائیں',
                                ),
                                style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.ornamentFill,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: theme.pageInnerBorder),
                            ),
                            child: SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              activeThumbColor: theme.ornamentPrimary,
                              secondary: Icon(
                                Icons.crop_portrait_rounded,
                                color: theme.ornamentPrimary,
                              ),
                              value: controller.showPageBorder,
                              onChanged: controller.setShowPageBorder,
                              title: Text(
                                tr(
                                  'إطار رفيع حول الصفحة',
                                  'Thin border around page',
                                  'صفحے کے گرد باریک حاشیہ',
                                ),
                                style: TextStyle(
                                  color: theme.glyphColor,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                tr(
                                  'إظهار إطار مزخرف رفيع حول صفحات المصحف',
                                  'Show a thin ornamental border around Mushaf pages',
                                  'مصحف کے صفحات کے گرد باریک مزین حاشیہ دکھائیں',
                                ),
                                style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),
                          // Section 2: Reading Theme
                          Text(
                            tr('مظهر الصفحة (الألوان)', 'Page Theme (Colors)'),
                            style: TextStyle(
                              color: theme.glyphColor,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: MushafThemeData.all
                                .map((themeOption) {
                                  final isSelected =
                                      themeOption.type == theme.type;
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4.0,
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () => controller.setTheme(
                                          themeOption.type,
                                        ),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: themeOption.pageBackground,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? theme.ornamentPrimary
                                                  : theme.pageInnerBorder,
                                              width: isSelected ? 2.2 : 1.0,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: theme
                                                          .ornamentPrimary
                                                          .withValues(
                                                            alpha: 0.20,
                                                          ),
                                                      blurRadius: 8,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    isSelected
                                                        ? Icons
                                                              .check_circle_rounded
                                                        : themeOption.icon,
                                                    size: 18,
                                                    color: themeOption
                                                        .ornamentPrimary,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    'أ ب ج',
                                                    style: TextStyle(
                                                      color: themeOption
                                                          .glyphColor,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                tr(
                                                  themeOption.arabicLabel,
                                                  themeOption.name,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: themeOption.glyphColor,
                                                  fontSize: 12.5,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                })
                                .toList(growable: false),
                          ),

                          const SizedBox(height: 18),
                          // Section 3: Word Pronunciation & Ayah Recitation Settings
                          Row(
                            children: [
                              Icon(
                                Icons.record_voice_over_rounded,
                                color: theme.ornamentPrimary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tr(
                                  'نطق الكلمات وتلاوة الآيات',
                                  'Word Pronunciation & Ayah Recitation',
                                ),
                                style: TextStyle(
                                  color: theme.glyphColor,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.ornamentFill,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: theme.pageInnerBorder),
                            ),
                            child: Column(
                              children: [
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  activeThumbColor: theme.ornamentPrimary,
                                  value: controller
                                      .enableSingleTapWordPronunciation,
                                  onChanged: controller
                                      .setEnableSingleTapWordPronunciation,
                                  title: Text(
                                    tr(
                                      'نطق الكلمة عند النقر المزدوج',
                                      'Pronounce word on double-tap',
                                      'ڈبل ٹیپ پر لفظ کا تلفظ',
                                    ),
                                    style: TextStyle(
                                      color: theme.glyphColor,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    tr(
                                      'النقر مرتين على أي كلمة في المصحف ينطقها فوراً (واللمسة الواحدة تُظهر/تُخفي القوائم، والضغط المطوّل لخيارات الآية)',
                                      'Double-tap any word to hear it immediately (single tap toggles menus; long-press opens ayah options)',
                                      'کسی بھی لفظ پر دو بار ٹیپ کرنے سے فوراً تلفظ سنائی دے گا (ایک ٹیپ سے مینو کھلے/بند ہو گا، اور دبا کر رکھنے سے آیت کے اختیارات کھلیں گے)',
                                    ),
                                    style: TextStyle(
                                      color: theme.secondaryTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  color: theme.pageInnerBorder.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  activeThumbColor: const Color(0xFF2B8A62),
                                  value: controller.autoPlayAyahAfterWord,
                                  onChanged:
                                      controller.setAutoPlayAyahAfterWord,
                                  title: Text(
                                    tr(
                                      'تلاوة الآية كاملة بعد نطق الكلمة',
                                      'Auto-recite full ayah after word',
                                    ),
                                    style: TextStyle(
                                      color: theme.glyphColor,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    tr(
                                      'تشغيل تلاوة الآية الكاملة تلقائياً فور انتهاء نطق الكلمة (أو عند لمس رقم الآية ﴿١﴾)',
                                      'Automatically play the full ayah after pronouncing a word (or tap the ayah number)',
                                    ),
                                    style: TextStyle(
                                      color: theme.secondaryTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            decoration: BoxDecoration(
                              color: theme.ornamentFill,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: theme.pageInnerBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr(
                                    'قارئ تلاوة الآية الكاملة:',
                                    'Full Ayah Reciter:',
                                  ),
                                  style: TextStyle(
                                    color: theme.glyphColor,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: QuranReciter.values
                                      .map((reciter) {
                                        final isSelected =
                                            controller.selectedReciter ==
                                            reciter;
                                        return ChoiceChip(
                                          label: Text(
                                            reciter.shortDisplayName,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : theme.glyphColor,
                                              fontSize: 12.5,
                                              fontWeight: isSelected
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                            ),
                                          ),
                                          selected: isSelected,
                                          selectedColor: theme.ornamentPrimary,
                                          backgroundColor: theme.pageBackground,
                                          checkmarkColor: Colors.white,
                                          side: BorderSide(
                                            color: isSelected
                                                ? theme.ornamentPrimary
                                                : theme.pageInnerBorder,
                                          ),
                                          onSelected: (_) => controller
                                              .setSelectedReciter(reciter),
                                        );
                                      })
                                      .toList(growable: false),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),
                          // Saved Ayah Highlight Color Picker
                          Row(
                            children: [
                              Icon(
                                Icons.palette_outlined,
                                color: theme.ornamentPrimary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tr(
                                  'لون تمييز الآيات المحفوظة',
                                  'Saved Ayah Highlight Color',
                                ),
                                style: TextStyle(
                                  color: theme.glyphColor,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.ornamentFill,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: theme.pageInnerBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: List.generate(
                                    MushafController
                                        .savedHighlightPalette
                                        .length,
                                    (idx) {
                                      final item = MushafController
                                          .savedHighlightPalette[idx];
                                      final isSel =
                                          controller.savedHighlightIndex == idx;
                                      return GestureDetector(
                                        onTap: () => controller
                                            .setSavedHighlightIndex(idx),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 160,
                                              ),
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: item.color,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isSel
                                                      ? theme.glyphColor
                                                      : Colors.white.withValues(
                                                          alpha: 0.7,
                                                        ),
                                                  width: isSel ? 2.6 : 1.4,
                                                ),
                                              ),
                                              child: isSel
                                                  ? const Icon(
                                                      Icons.check_rounded,
                                                      color: Colors.white,
                                                      size: 20,
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              tr(item.ar, item.en),
                                              style: TextStyle(
                                                color: isSel
                                                    ? theme.glyphColor
                                                    : theme.secondaryTextColor,
                                                fontSize: 11,
                                                fontWeight: isSel
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: controller.savedAyahHighlightColor
                                        .withValues(alpha: 0.28),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    tr(
                                      'معاينة: هكذا سيظهر تمييز الآية المحفوظة في الصفحة',
                                      'Preview: Saved ayah highlight on the Mushaf page',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: theme.glyphColor,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Section 4: Keep Screen Awake toggle
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.ornamentFill,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: theme.pageInnerBorder),
                            ),
                            child: SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              activeThumbColor: theme.ornamentPrimary,
                              value: controller.keepScreenAwake,
                              onChanged: controller.setKeepScreenAwake,
                              title: Text(
                                tr(
                                  'إبقاء الشاشة مضاءة أثناء القراءة',
                                  'Keep screen awake while reading',
                                ),
                                style: TextStyle(
                                  color: theme.glyphColor,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                tr(
                                  'منع قفل الشاشة التلقائي أثناء تصفح المصحف',
                                  'Prevent auto-lock while reading the Mushaf',
                                ),
                                style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Section 5: Vertical page scrolling (snap always on) & landscape orientation
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.ornamentFill,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: theme.pageInnerBorder),
                            ),
                            child: Column(
                              children: [
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  activeThumbColor: theme.ornamentPrimary,
                                  secondary: Icon(
                                    Icons.swap_vert_rounded,
                                    color: theme.ornamentPrimary,
                                  ),
                                  value: controller.verticalScroll,
                                  onChanged: controller.setVerticalScroll,
                                  title: Text(
                                    tr(
                                      'التمرير العمودي للصفحات',
                                      'Vertical page scrolling',
                                      'صفحات کی عمودی اسکرولنگ',
                                    ),
                                    style: TextStyle(
                                      color: theme.glyphColor,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    tr(
                                      'تمرير عمودي سلس بدلاً من قلب الصفحات جانبياً',
                                      'Smooth vertical scrolling instead of flipping pages sideways',
                                      'صفحات پلٹنے کے بجائے ہموار عمودی اسکرولنگ',
                                    ),
                                    style: TextStyle(
                                      color: theme.secondaryTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  color: theme.pageInnerBorder,
                                ),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  activeThumbColor: theme.ornamentPrimary,
                                  secondary: Icon(
                                    Icons.screen_rotation_rounded,
                                    color: theme.ornamentPrimary,
                                  ),
                                  value: controller.allowLandscape,
                                  onChanged: controller.setAllowLandscape,
                                  title: Text(
                                    tr(
                                      'العرض الأفقي عند تدوير الهاتف',
                                      'Landscape view when rotated',
                                      'فون گھمانے پر افقی منظر',
                                    ),
                                    style: TextStyle(
                                      color: theme.glyphColor,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    tr(
                                      'عرض الصفحة بكامل عرض الشاشة عند إمالة الهاتف',
                                      'Show the page across the full screen width when the phone is turned sideways',
                                      'فون کو ترچھا کرنے پر صفحہ پوری چوڑائی میں دکھائیں',
                                    ),
                                    style: TextStyle(
                                      color: theme.secondaryTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Section 6: Video Help Button (YouTube)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.ornamentPrimary,
                              backgroundColor: theme.ornamentPrimary.withValues(
                                alpha: 0.08,
                              ),
                              side: BorderSide(
                                color: theme.ornamentPrimary,
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => controller.openHelpVideo(),
                            icon: const Icon(
                              Icons.play_circle_fill_rounded,
                              size: 22,
                            ),
                            label: Text(
                              tr(
                                'مساعدة وشرح استخدام التطبيق (فيديو يوتيوب)',
                                'Help & App Tutorial (YouTube Video)',
                                'مدد اور ایپ کے استعمال کی ویڈیو (یوٹیوب)',
                              ),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.secondaryTextColor,
                              backgroundColor: theme.ornamentFill,
                              side: BorderSide(
                                color: theme.pageInnerBorder,
                                width: 1.2,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              showOnboardingIntro(
                                context,
                                controller: controller,
                              );
                            },
                            icon: Icon(
                              Icons.auto_stories_rounded,
                              size: 20,
                              color: theme.ornamentPrimary,
                            ),
                            label: Text(
                              tr(
                                'عرض المقدمة التعريفية للتطبيق',
                                'View App Welcome Introduction',
                                'ایپ کا تعارفی پیغام دوبارہ دیکھیں',
                              ),
                              style: TextStyle(
                                color: theme.glyphColor,
                                fontSize: 13.5,
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
          ),
        );
      },
    );
  }
}

class _FontScaleOptionCard extends StatelessWidget {
  final MushafFontScaleMode mode;
  final bool isSelected;
  final MushafThemeData theme;
  final VoidCallback onTap;

  const _FontScaleOptionCard({
    required this.mode,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.ornamentPrimary.withValues(alpha: 0.14)
              : theme.ornamentFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? theme.ornamentPrimary : theme.pageInnerBorder,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.ornamentPrimary
                    : theme.pageBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? theme.ornamentPrimary
                      : theme.pageInnerBorder,
                ),
              ),
              child: Icon(
                mode.icon,
                color: isSelected ? Colors.white : theme.ornamentPrimary,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          mode.title,
                          style: TextStyle(
                            color: theme.glyphColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.pageBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: theme.pageInnerBorder),
                        ),
                        child: Text(
                          mode.badge,
                          style: TextStyle(
                            color: theme.ornamentPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    mode.subtitle,
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? theme.ornamentPrimary
                  : theme.secondaryTextColor.withValues(alpha: 0.5),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
