import 'package:flutter/material.dart';

import '../models/mushaf_models.dart';
import '../state/mushaf_controller.dart';
import '../theme/mushaf_theme.dart';
import '../utils/arabic_utils.dart';

class BookmarksSheet extends StatefulWidget {
  final MushafController controller;

  const BookmarksSheet({
    super.key,
    required this.controller,
  });

  @override
  State<BookmarksSheet> createState() => _BookmarksSheetState();
}

class _BookmarksSheetState extends State<BookmarksSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final theme = widget.controller.theme;
        final pageBookmarks = widget.controller.pageBookmarks;
        final ayahBookmarks = widget.controller.ayahBookmarks;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.80,
            decoration: BoxDecoration(
              color: theme.pageBackground,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border.all(color: theme.pageOuterBorder, width: 1.4),
            ),
            child: Column(
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'العلامات المرجعية',
                        style: TextStyle(
                          color: theme.glyphColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: theme.glyphColor),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.ornamentFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.pageInnerBorder),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: theme.ornamentPrimary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: theme.glyphColor,
                    labelStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                    tabs: [
                      Tab(
                        text:
                            'الصفحات (${ArabicUtils.toArabicDigits(pageBookmarks.length)})',
                      ),
                      Tab(
                        text:
                            'الآيات (${ArabicUtils.toArabicDigits(ayahBookmarks.length)})',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBookmarkList(
                        items: pageBookmarks,
                        emptyText:
                            'لا توجد صفحات محفوظة بعد.\nاضغط على أيقونة الشريط في الأعلى لحفظ الصفحة الحالية.',
                        theme: theme,
                      ),
                      _buildBookmarkList(
                        items: ayahBookmarks,
                        emptyText:
                            'لا توجد آيات محفوظة بعد.\nاضغط مطولاً على أي آية في الصفحة لحفظها أو نسخها.',
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookmarkList({
    required List<BookmarkItem> items,
    required String emptyText,
    required MushafThemeData theme,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            emptyText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 14.5,
              height: 1.6,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: items.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: theme.pageInnerBorder.withValues(alpha: 0.45),
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          onTap: () {
            Navigator.of(context).pop();
            widget.controller.goToPage(
              item.pageNumber,
              highlightVerseKey: item.verseKey,
            );
          },
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.bookmarkRibbon.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.isPageBookmark
                  ? Icons.bookmark_rounded
                  : Icons.auto_awesome_rounded,
              color: theme.bookmarkRibbon,
              size: 20,
            ),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.glyphColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.ornamentFill,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.pageInnerBorder),
                ),
                child: Text(
                  'ص ${ArabicUtils.toArabicDigits(item.pageNumber)}',
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          subtitle: item.snippet != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    item.snippet!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                )
              : null,
          trailing: IconButton(
            tooltip: 'حذف',
            icon: Icon(
              Icons.delete_outline_rounded,
              color: theme.secondaryTextColor,
            ),
            onPressed: () {
              if (item.id != null) {
                widget.controller.deleteBookmark(item.id!);
              }
            },
          ),
        );
      },
    );
  }
}
