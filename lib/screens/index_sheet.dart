import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../state/mushaf_controller.dart';
import '../theme/mushaf_theme.dart';
import '../utils/arabic_utils.dart';

class IndexSheet extends StatefulWidget {
  final MushafController controller;

  const IndexSheet({
    super.key,
    required this.controller,
  });

  @override
  State<IndexSheet> createState() => _IndexSheetState();
}

class _IndexSheetState extends State<IndexSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _surahFilterController = TextEditingController();
  final TextEditingController _pageInputController = TextEditingController();
  String _surahQuery = '';
  String? _pageError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pageInputController.text = widget.controller.currentPage.toString();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _surahFilterController.dispose();
    _pageInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.controller.theme;

    return Directionality(
      textDirection: L10n.dir,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.86,
        decoration: BoxDecoration(
          color: theme.pageBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
                    tr(tr('فهرس المصحف الشريف', 'Quran Index'), 'Quran Index'),
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
                  Tab(text: tr(tr('السور (١١٤)', 'Surahs (114)'), 'Surahs (114)')),
                  Tab(text: tr(tr('الأجزاء (٣٠)', 'Juz (30)'), 'Juz (30)')),
                  Tab(text: tr('انتقال لصفحة', 'Go to page')),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSurahsTab(theme),
                  _buildJuzsTab(theme),
                  _buildPageJumpTab(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurahsTab(MushafThemeData theme) {
    final allSurahs = widget.controller.surahs;
    String flat(String x) => x
        .toLowerCase()
        .replaceAll(RegExp("[-'\u2019\u2018`\\s]"), '');
    final cleanFilter =
        ArabicUtils.normalizeForSearch(_surahQuery).toLowerCase();
    final enFilter = flat(_surahQuery);

    final filtered = cleanFilter.isEmpty
        ? allSurahs
        : allSurahs.where((s) {
            final arNorm = ArabicUtils.normalizeForSearch(s.nameArabic);
            final enNorm = flat(s.nameEnglish);
            final trNorm = flat(s.nameTranslation);
            final idStr = s.id.toString();
            return arNorm.contains(cleanFilter) ||
                (enFilter.isNotEmpty &&
                    (enNorm.contains(enFilter) || trNorm.contains(enFilter))) ||
                idStr == cleanFilter;
          }).toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _surahFilterController,
            onChanged: (v) => setState(() => _surahQuery = v),
            style: TextStyle(color: theme.glyphColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: tr('ابحث باسم السورة أو رقمها (١ - ١١٤)...', 'Search by Surah name or number (1 - 114)...'),
              hintStyle: TextStyle(
                color: theme.secondaryTextColor.withValues(alpha: 0.7),
                fontSize: 13.5,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: theme.ornamentPrimary,
              ),
              suffixIcon: _surahQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: theme.secondaryTextColor,
                      ),
                      onPressed: () {
                        _surahFilterController.clear();
                        setState(() => _surahQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: theme.ornamentFill,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.pageInnerBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.pageInnerBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: theme.ornamentPrimary, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: theme.pageInnerBorder.withValues(alpha: 0.45),
            ),
            itemBuilder: (context, index) {
              final surah = filtered[index];
              final isCurrentSurah = widget.controller.currentPage >=
                      surah.startPage &&
                  widget.controller.currentPage <= surah.endPage;

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                tileColor: isCurrentSurah
                    ? theme.ayahHighlightFill.withValues(alpha: 0.18)
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.controller.goToPage(surah.startPage);
                },
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.ornamentFill,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.ornamentPrimary,
                      width: 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    ArabicUtils.toArabicDigits(surah.id),
                    style: TextStyle(
                      color: theme.glyphColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(child: Text(
                      tr(L10n.isEn ? '${surah.nameEnglish} (${surah.nameTranslation})' : 'سورة ${surah.nameArabic}', surah.nameEnglish),
                      style: TextStyle(
                        color: theme.glyphColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.ornamentPrimary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        L10n.revelation(surah),
                        style: TextStyle(
                          color: theme.ornamentPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  tr('${surah.nameEnglish} (${surah.nameTranslation}) • ${ArabicUtils.toArabicDigits(surah.ayahCount)} آية', '${surah.nameTranslation} • ${surah.ayahCount} ayahs'),
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 12,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      surah.surahCode,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontFamily: 'Surahs',
                        fontSize: 22,
                        height: 1.0,
                        color: theme.glyphColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr(tr('ص ${ArabicUtils.toArabicDigits(surah.startPage)}', 'p. ${surah.startPage}'), 'p. ${surah.startPage}'),
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJuzsTab(MushafThemeData theme) {
    final juzs = widget.controller.juzs;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: juzs.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: theme.pageInnerBorder.withValues(alpha: 0.45),
      ),
      itemBuilder: (context, index) {
        final juz = juzs[index];
        final isCurrentJuz =
            widget.controller.currentPage >= juz.startPage &&
                widget.controller.currentPage <= juz.endPage;

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          tileColor: isCurrentJuz
              ? theme.ayahHighlightFill.withValues(alpha: 0.18)
              : null,
          onTap: () {
            Navigator.of(context).pop();
            widget.controller.goToPage(juz.startPage);
          },
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.ornamentFill,
              shape: BoxShape.circle,
              border: Border.all(color: theme.ornamentPrimary, width: 1.2),
            ),
            alignment: Alignment.center,
            child: Text(
              ArabicUtils.toArabicDigits(juz.id),
              style: TextStyle(
                color: theme.glyphColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(
            tr(juz.nameArabic, 'Juz ${juz.id}'),
            style: TextStyle(
              color: theme.glyphColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            tr('يبدأ من سورة ${juz.startSurahNameArabic} (${juz.startSurahNameEnglish}) • الآية ${ArabicUtils.toArabicDigits(juz.startAyah)}', 'Starts at Surah ${juz.startSurahNameEnglish} • Ayah ${juz.startAyah}'),
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 12,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: theme.ornamentFill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.pageInnerBorder),
            ),
            child: Text(
              tr(tr('ص ${ArabicUtils.toArabicDigits(juz.startPage)}', 'p. ${juz.startPage}'), 'p. ${juz.startPage}'),
              style: TextStyle(
                color: theme.glyphColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageJumpTab(MushafThemeData theme) {
    final presets = <({String label, String sub, int page})>[
      (label: tr('سورة الفاتحة', 'Surah Al-Fatihah'), sub: tr('بداية المصحف', 'Start of the Mushaf'), page: 1),
      (label: tr('سورة البقرة', 'Surah Al-Baqarah'), sub: tr('الجزء الأول', 'Juz 1'), page: 2),
      (label: tr('سورة الكهف', 'Surah Al-Kahf'), sub: tr('الجزء الخامس عشر', 'Juz 15'), page: 293),
      (label: tr('سورة يس', 'Surah Ya-Sin'), sub: tr('الجزء الثاني والعشرون', 'Juz 22'), page: 440),
      (label: tr('سورة الرحمن', 'Surah Ar-Rahman'), sub: tr('الجزء السابع والعشرون', 'Juz 27'), page: 531),
      (label: tr('سورة الواقعة', "Surah Al-Waqi'ah"), sub: tr('الجزء السابع والعشرون', 'Juz 27'), page: 534),
      (label: tr('سورة الملك', 'Surah Al-Mulk'), sub: tr('الجزء التاسع والعشرون', 'Juz 29'), page: 562),
      (label: tr('جزء عمّ', 'Juz Amma'), sub: tr('الجزء الثلاثون', 'Juz 30'), page: 582),
      (label: tr('ختم المصحف', 'Complete the Quran'), sub: tr('سورة الناس', 'Surah An-Nas'), page: 604),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.ornamentFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.pageInnerBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr('أدخل رقم الصفحة (١ إلى ٦٠٤)', 'Enter page number (1 to 604)'),
                  style: TextStyle(
                    color: theme.glyphColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pageInputController,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.glyphColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        onSubmitted: (_) => _submitPageJump(),
                        decoration: InputDecoration(
                          hintText: '1 - 604',
                          errorText: _pageError,
                          filled: true,
                          fillColor: theme.pageBackground,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: theme.pageOuterBorder),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.ornamentPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _submitPageJump,
                      icon: Icon(
                          L10n.isEn
                              ? Icons.arrow_forward_rounded
                              : Icons.arrow_back_rounded,
                          size: 18),
                      label: Text(
                        tr('انتقال', 'Go'),
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            tr('وصول سريع', 'Quick access'),
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((item) {
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.controller.goToPage(item.page);
                },
                child: Container(
                  width: (MediaQuery.of(context).size.width - 48) / 2,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.ornamentFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.pageInnerBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: TextStyle(
                                color: theme.glyphColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              item.sub,
                              style: TextStyle(
                                color: theme.secondaryTextColor,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        tr('ص ${ArabicUtils.toArabicDigits(item.page)}', 'p. ${item.page}'),
                        style: TextStyle(
                          color: theme.ornamentPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }

  void _submitPageJump() {
    final raw = _pageInputController.text
        .trim()
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 1 || parsed > 604) {
      setState(() {
        _pageError = tr('الرجاء إدخال رقم صفحة صحيح بين ١ و ٦٠٤', 'Please enter a valid page number between 1 and 604');
      });
      return;
    }
    Navigator.of(context).pop();
    widget.controller.goToPage(parsed);
  }
}
