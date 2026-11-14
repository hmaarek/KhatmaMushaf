import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/mushaf_controller.dart';
import '../utils/arabic_utils.dart';
import '../widgets/mushaf_page_widget.dart';
import '../widgets/reader_hud_overlay.dart';
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final theme = widget.controller.theme;

        if (!widget.controller.isInitialized) {
          return Scaffold(
            backgroundColor: theme.scaffoldBackground,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: theme.ornamentPrimary),
                  const SizedBox(height: 16),
                  Text(
                    'جاري فتح المصحف الشريف...',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: theme.glyphColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
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
                          onZoomChanged: (zoomed) {
                            if (_isCurrentPageZoomed != zoomed) {
                              setState(() => _isCurrentPageZoomed = zoomed);
                            }
                          },
                          onAyahLongPress: (verseKey) =>
                              _showAyahActionSheet(context, verseKey),
                          onCompleteKhatmaTap: () =>
                              _handleCompleteKhatmaFromLastPage(context),
                        );
                      },
                    ),
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

  Future<void> _handleCompleteKhatmaFromLastPage(BuildContext context) async {
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

  Future<void> _showAyahActionSheet(
    BuildContext context,
    String verseKey,
  ) async {
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
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
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
                      const SizedBox(height: 14),

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
