import 'package:flutter/material.dart';

import '../state/mushaf_controller.dart';
import '../theme/mushaf_theme.dart';
import '../utils/arabic_utils.dart';

class ReaderHudOverlay extends StatefulWidget {
  final MushafController controller;
  final VoidCallback onOpenIndex;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenBookmarks;
  final VoidCallback onOpenSettings;

  const ReaderHudOverlay({
    super.key,
    required this.controller,
    required this.onOpenIndex,
    required this.onOpenSearch,
    required this.onOpenBookmarks,
    required this.onOpenSettings,
  });

  @override
  State<ReaderHudOverlay> createState() => _ReaderHudOverlayState();
}

class _ReaderHudOverlayState extends State<ReaderHudOverlay> {
  double? _scrubPage;

  @override
  Widget build(BuildContext context) {
    final visible = widget.controller.isHudVisible;
    final theme = widget.controller.theme;
    final pageData = widget.controller.currentPageData;
    final currentPage = widget.controller.currentPage;
    final activeSliderPage = (_scrubPage ?? currentPage.toDouble()).round();

    return IgnorePointer(
      ignoring: !visible,
      child: Stack(
        children: [
          // Top translucent bar
          AnimatedSlide(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            offset: visible ? Offset.zero : const Offset(0, -1.1),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: visible ? 1.0 : 0.0,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.hudBackground,
                  border: Border(
                    bottom: BorderSide(
                      color: theme.ornamentPrimary.withValues(alpha: 0.35),
                      width: 1.0,
                    ),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: SafeArea(
                  bottom: false,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      children: [
                        // Quick Index button (Surahs / Juzs / Page Jump)
                        _HudIconButton(
                          icon: Icons.menu_book_rounded,
                          tooltip: 'الفهرس (Index)',
                          label: 'الفهرس',
                          theme: theme,
                          onTap: widget.onOpenIndex,
                        ),
                        const SizedBox(width: 8),
                        // Surah & Juz Info in center-right
                        Expanded(
                          child: GestureDetector(
                            onTap: widget.onOpenIndex,
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  pageData?.info.surahNamesArabic ??
                                      'المصحف الشريف',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.hudText,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  pageData != null
                                      ? 'الجزء ${ArabicUtils.toArabicDigits(pageData.info.juzNumber)} • الحزب ${ArabicUtils.toArabicDigits(pageData.info.hizbNumber)} • ص ${ArabicUtils.toArabicDigits(currentPage)}'
                                      : 'صفحة ${ArabicUtils.toArabicDigits(currentPage)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        theme.hudText.withValues(alpha: 0.75),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Offline Arabic Search button
                        _HudIconButton(
                          icon: Icons.search_rounded,
                          tooltip: 'بحث في القرآن (Search)',
                          theme: theme,
                          onTap: widget.onOpenSearch,
                        ),
                        const SizedBox(width: 5),
                        // Bookmarks list button
                        _HudIconButton(
                          icon: Icons.collections_bookmark_outlined,
                          fallbackIcon: Icons.bookmarks_outlined,
                          tooltip: 'العلامات المرجعية (Bookmarks)',
                          badgeCount: widget.controller.bookmarks.length,
                          theme: theme,
                          onTap: widget.onOpenBookmarks,
                        ),
                        const SizedBox(width: 5),
                        // Settings button (Font Size, Pinch-to-Zoom, Themes)
                        _HudIconButton(
                          icon: Icons.tune_rounded,
                          tooltip: 'إعدادات الخط والعرض (Settings)',
                          theme: theme,
                          onTap: widget.onOpenSettings,
                        ),
                        const SizedBox(width: 5),
                        // Quick Page Bookmark Ribbon toggle
                        _QuickBookmarkRibbonButton(
                          isBookmarked:
                              widget.controller.isCurrentPageBookmarked,
                          theme: theme,
                          onTap: () async {
                            final added = await widget.controller
                                .toggleCurrentPageBookmark();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  duration: const Duration(milliseconds: 1400),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: theme.hudSurface,
                                  content: Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: Text(
                                      added
                                          ? 'تم حفظ علامة الصفحة ${ArabicUtils.toArabicDigits(currentPage)}'
                                          : 'تم إزالة علامة الصفحة ${ArabicUtils.toArabicDigits(currentPage)}',
                                      style: TextStyle(color: theme.hudText),
                                    ),
                                  ),
                                ),
                              );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom translucent bar with Theme Selector & 1-604 RTL Page Scrubber
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              offset: visible ? Offset.zero : const Offset(0, 1.1),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: visible ? 1.0 : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.hudBackground,
                    border: Border(
                      top: BorderSide(
                        color: theme.ornamentPrimary.withValues(alpha: 0.35),
                        width: 1.0,
                      ),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 12,
                        offset: Offset(0, -3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 3 Reading Themes selector row
                        _buildThemeSelectorRow(theme),
                        const SizedBox(height: 10),
                        // Scrubber header info + quick Font Size / Zoom pill
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'صفحة ${ArabicUtils.toArabicDigits(activeSliderPage)} من ٦٠٤',
                                style: TextStyle(
                                  color: theme.hudText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: widget.onOpenSettings,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.hudSurface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: theme.ornamentSecondary
                                          .withValues(alpha: 0.45),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        widget.controller.fontScaleMode.icon,
                                        size: 14,
                                        color: theme.ornamentSecondary,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'الخط: ${widget.controller.fontScaleMode.arabicTitle}',
                                        style: TextStyle(
                                          color: theme.hudText,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  _surahNameForPage(activeSliderPage),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.ornamentSecondary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // RTL 1–604 Page Scrubber Slider
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Row(
                            children: [
                              Text(
                                '١',
                                style: TextStyle(
                                  color: theme.hudText.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: theme.ornamentPrimary,
                                    inactiveTrackColor:
                                        theme.hudText.withValues(alpha: 0.2),
                                    thumbColor: theme.ornamentSecondary,
                                    overlayColor: theme.ornamentPrimary
                                        .withValues(alpha: 0.25),
                                    trackHeight: 4.0,
                                  ),
                                  child: Slider(
                                    min: 1,
                                    max: 604,
                                    divisions: 603,
                                    value: (_scrubPage ??
                                            currentPage.toDouble())
                                        .clamp(1.0, 604.0),
                                    onChanged: (value) {
                                      setState(() {
                                        _scrubPage = value;
                                      });
                                    },
                                    onChangeEnd: (value) {
                                      final target = value.round().clamp(1, 604);
                                      setState(() {
                                        _scrubPage = null;
                                      });
                                      widget.controller.goToPage(
                                        target,
                                        hideHud: false,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Text(
                                '٦٠٤',
                                style: TextStyle(
                                  color: theme.hudText.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _surahNameForPage(int page) {
    final surahs = widget.controller.surahs;
    if (surahs.isEmpty) return '';
    for (int i = surahs.length - 1; i >= 0; i--) {
      if (page >= surahs[i].startPage) {
        return 'سورة ${surahs[i].nameArabic}';
      }
    }
    return 'سورة ${surahs.first.nameArabic}';
  }

  Widget _buildThemeSelectorRow(MushafThemeData activeTheme) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: MushafThemeData.all.map((themeOption) {
          final isSelected = themeOption.type == activeTheme.type;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(10.0),
                onTap: () => widget.controller.setTheme(themeOption.type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 7.0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeTheme.ornamentPrimary.withValues(alpha: 0.28)
                        : activeTheme.hudSurface,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(
                      color: isSelected
                          ? activeTheme.ornamentSecondary
                          : activeTheme.hudText.withValues(alpha: 0.14),
                      width: isSelected ? 1.4 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: themeOption.pageBackground,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: themeOption.ornamentPrimary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          themeOption.arabicLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: activeTheme.hudText,
                            fontSize: 11.5,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
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
    );
  }
}

class _HudIconButton extends StatelessWidget {
  final IconData? icon;
  final IconData? fallbackIcon;
  final String tooltip;
  final String? label;
  final int badgeCount;
  final MushafThemeData theme;
  final VoidCallback onTap;

  const _HudIconButton({
    this.icon,
    this.fallbackIcon,
    required this.tooltip,
    this.label,
    this.badgeCount = 0,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIcon = fallbackIcon ?? icon ?? Icons.circle;
    return Material(
      color: theme.hudSurface,
      borderRadius: BorderRadius.circular(10.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(10.0),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: label != null ? 9.0 : 8.0,
            vertical: 8.0,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    effectiveIcon,
                    size: 19,
                    color: theme.hudText,
                  ),
                  if (label != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      label!,
                      style: TextStyle(
                        color: theme.hudText,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -5,
                  left: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4.5,
                      vertical: 1.0,
                    ),
                    decoration: BoxDecoration(
                      color: theme.bookmarkRibbon,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      ArabicUtils.toArabicDigits(badgeCount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickBookmarkRibbonButton extends StatelessWidget {
  final bool isBookmarked;
  final MushafThemeData theme;
  final VoidCallback onTap;

  const _QuickBookmarkRibbonButton({
    required this.isBookmarked,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isBookmarked
          ? theme.bookmarkRibbon.withValues(alpha: 0.22)
          : theme.hudSurface,
      borderRadius: BorderRadius.circular(10.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(10.0),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(
              color: isBookmarked ? theme.bookmarkRibbon : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Icon(
            isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            size: 19,
            color: isBookmarked ? theme.bookmarkRibbon : theme.hudText,
          ),
        ),
      ),
    );
  }
}
