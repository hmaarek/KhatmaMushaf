import 'package:flutter/material.dart';

import '../state/mushaf_controller.dart';
import '../theme/mushaf_theme.dart';

class SettingsSheet extends StatelessWidget {
  final MushafController controller;

  const SettingsSheet({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final theme = controller.theme;
        final currentScaleMode = controller.fontScaleMode;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.86,
            ),
            decoration: BoxDecoration(
              color: theme.pageBackground,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
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
                              'إعدادات العرض والقراءة',
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
                          // Section 1: Font Size & Zoom Mode
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'حجم الخط وطريقة التكبير',
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
                                  color: theme.ornamentPrimary
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'التزام تام بـ ١٥ سطراً',
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
                            'جميع الخيارات تحافظ على تنسيق مصحف المدينة النبوية (١٥ سطراً في كل صفحة دون تغيير مواضع الكلمات).',
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

                          const SizedBox(height: 14),
                          // Section 2: Reading Theme
                          Text(
                            'مظهر الصفحة (الألوان)',
                            style: TextStyle(
                              color: theme.glyphColor,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: MushafThemeData.all.map((themeOption) {
                              final isSelected =
                                  themeOption.type == theme.type;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4.0,
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () =>
                                        controller.setTheme(themeOption.type),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: themeOption.pageBackground,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? theme.ornamentPrimary
                                              : theme.pageInnerBorder,
                                          width: isSelected ? 2.2 : 1.0,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: theme.ornamentPrimary
                                                      .withValues(alpha: 0.20),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
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
                                                    ? Icons.check_circle_rounded
                                                    : themeOption.icon,
                                                size: 18,
                                                color:
                                                    themeOption.ornamentPrimary,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'أ ب ج',
                                                style: TextStyle(
                                                  color: themeOption.glyphColor,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            themeOption.arabicLabel,
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
                            }).toList(growable: false),
                          ),

                          const SizedBox(height: 18),
                          // Section 3: Keep Screen Awake toggle
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
                                'إبقاء الشاشة مضاءة أثناء القراءة',
                                style: TextStyle(
                                  color: theme.glyphColor,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                'منع قفل الشاشة التلقائي أثناء تصفح المصحف',
                                style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 12,
                                ),
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
                          mode.arabicTitle,
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
                          mode.badgeText,
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
                    mode.arabicSubtitle,
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
