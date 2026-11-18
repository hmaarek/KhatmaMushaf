import '../l10n/l10n.dart';
import 'dart:async';
import 'package:flutter/material.dart';

import '../services/smart_search_service.dart';
import '../state/mushaf_controller.dart';
import '../theme/mushaf_theme.dart';
import '../utils/arabic_utils.dart';

class SearchSheet extends StatefulWidget {
  final MushafController controller;

  const SearchSheet({
    super.key,
    required this.controller,
  });

  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  String _query = '';
  SmartSearchResponse? _response;

  /// `null` means "الكل" (All results, with Synonyms/Topics grouped in a separate section).
  SearchMatchCategory? _selectedFilter;

  static const List<String> _suggestedWordQueries = [
    'مغفرة',
    'الصلاة',
    'الصبر',
    'الجنة',
    'الرحمن',
    'الوالدين',
    'التقوى',
    'الرزق',
  ];

  static const List<String> _suggestedPhraseQueries = [
    'ربنا آتنا الدنيا حسنة',
    'ان مع العسر يسرا',
    'الله لا اله الا هو الحي القيوم',
    'اصحاب الكهف',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
    });
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _response = null;
        _selectedFilter = null;
        _isSearching = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
    });
    _debounce = Timer(const Duration(milliseconds: 140), () async {
      final res = await widget.controller.smartSearchAyahs(value);
      if (!mounted) return;
      setState(() {
        _response = res;
        _isSearching = false;
      });
    });
  }

  void _applyQuickQuery(String text) {
    _searchController.text = text;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    _selectedFilter = null;
    _onQueryChanged(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.controller.theme;

    return Directionality(
      textDirection: L10n.dir,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: BoxDecoration(
          color: theme.pageBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: theme.ornamentPrimary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tr('البحث الذكي في القرآن الكريم', 'Smart Quran Search'),
                        style: TextStyle(
                          color: theme.glyphColor,
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.glyphColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onQueryChanged,
                style: TextStyle(
                  color: theme.glyphColor,
                  fontSize: 15.5,
                ),
                decoration: InputDecoration(
                  hintText:
                      'ابحث بكلمة، جذر لغوي، آية غير مكتملة، أو موضوع...',
                  hintStyle: TextStyle(
                    color: theme.secondaryTextColor.withValues(alpha: 0.7),
                    fontSize: 13.5,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: theme.ornamentPrimary,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: theme.secondaryTextColor,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _onQueryChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.ornamentFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
                    borderSide: BorderSide(
                      color: theme.ornamentPrimary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _query.trim().isEmpty
                  ? _buildSuggestionsView(theme)
                  : _isSearching
                      ? Center(
                          child: CircularProgressIndicator(
                            color: theme.ornamentPrimary,
                          ),
                        )
                      : (_response == null || _response!.isEmpty)
                          ? _buildEmptyState(theme)
                          : _buildResultsBody(context, _response!, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsBody(
    BuildContext context,
    SmartSearchResponse res,
    MushafThemeData theme,
  ) {
    final directList = res.byCategory(SearchMatchCategory.direct);
    final rootList = res.byCategory(SearchMatchCategory.root);
    final approxList = res.byCategory(SearchMatchCategory.approximate);
    final synList = res.synonymTopicResults;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Linguistic Root & Derivatives Bar
        if (res.extractedRoots.isNotEmpty)
          _buildRootAndDerivativesBar(res, theme),

        // 2. Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _FilterChipButton(
                label:
                    'الكل (${ArabicUtils.toArabicDigits(res.totalCount)})',
                isSelected: _selectedFilter == null,
                theme: theme,
                onTap: () => setState(() => _selectedFilter = null),
              ),
              if (directList.isNotEmpty) ...[
                const SizedBox(width: 6),
                _FilterChipButton(
                  label:
                      'تطابق مباشر (${ArabicUtils.toArabicDigits(directList.length)})',
                  isSelected: _selectedFilter == SearchMatchCategory.direct,
                  theme: theme,
                  onTap: () => setState(
                    () => _selectedFilter = SearchMatchCategory.direct,
                  ),
                ),
              ],
              if (rootList.isNotEmpty) ...[
                const SizedBox(width: 6),
                _FilterChipButton(
                  label:
                      'بالجذر والاشتقاقات (${ArabicUtils.toArabicDigits(rootList.length)})',
                  isSelected: _selectedFilter == SearchMatchCategory.root,
                  theme: theme,
                  onTap: () => setState(
                    () => _selectedFilter = SearchMatchCategory.root,
                  ),
                ),
              ],
              if (approxList.isNotEmpty) ...[
                const SizedBox(width: 6),
                _FilterChipButton(
                  label:
                      'تطابق تقريبي (${ArabicUtils.toArabicDigits(approxList.length)})',
                  isSelected:
                      _selectedFilter == SearchMatchCategory.approximate,
                  theme: theme,
                  onTap: () => setState(
                    () => _selectedFilter = SearchMatchCategory.approximate,
                  ),
                ),
              ],
              if (synList.isNotEmpty) ...[
                const SizedBox(width: 6),
                _FilterChipButton(
                  label:
                      'مرادفات ومواضيع (${ArabicUtils.toArabicDigits(synList.length)})',
                  isSelected:
                      _selectedFilter == SearchMatchCategory.synonymTopic,
                  accentColor: const Color(0xFF2B8A62),
                  theme: theme,
                  onTap: () => setState(
                    () => _selectedFilter = SearchMatchCategory.synonymTopic,
                  ),
                ),
              ],
            ],
          ),
        ),

        Divider(
          height: 1,
          color: theme.pageInnerBorder.withValues(alpha: 0.5),
        ),

        // 3. Results List
        Expanded(
          child: _selectedFilter == null
              ? _buildCombinedWithSeparateSynonymsList(
                  context,
                  res,
                  theme,
                )
              : _buildFilteredCategoryList(
                  context,
                  res,
                  _selectedFilter!,
                  theme,
                ),
        ),
      ],
    );
  }

  Widget _buildRootAndDerivativesBar(
    SmartSearchResponse res,
    MushafThemeData theme,
  ) {
    final formattedRoots = res.extractedRoots
        .map(SmartSearchService.formatRootLetters)
        .join(' ، ');
    final derivatives = res.rootDerivativesCounts.entries.toList(
      growable: false,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.ornamentFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.pageInnerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_tree_outlined,
                size: 16,
                color: theme.ornamentPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                'الجذر اللغوي المستخرج: ',
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '[ $formattedRoots ]',
                style: TextStyle(
                  color: theme.ornamentPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (derivatives.isNotEmpty) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 28,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: derivatives.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final entry = derivatives[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _applyQuickQuery(entry.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.pageBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.pageInnerBorder),
                      ),
                      child: Center(
                        child: Text(
                          '${entry.key} (${ArabicUtils.toArabicDigits(entry.value)})',
                          style: TextStyle(
                            color: theme.glyphColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Shows primary results (Direct + Root + Approximate) first, followed by
  /// a clearly separated section for Synonym/Topic matches so they are grouped alone.
  Widget _buildCombinedWithSeparateSynonymsList(
    BuildContext context,
    SmartSearchResponse res,
    MushafThemeData theme,
  ) {
    final primary = res.primaryResults;
    final synonyms = res.synonymTopicResults;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (primary.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6, right: 4, left: 4),
            child: Text(
              'النتائج المباشرة ومشتقات الجذر (${ArabicUtils.toArabicDigits(primary.length)})',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ...primary.map(
            (item) => _SmartResultCard(
              item: item,
              theme: theme,
              onTap: () {
                Navigator.of(context).pop();
                widget.controller.goToPage(
                  item.ayah.pageNumber,
                  highlightVerseKey: item.ayah.verseKey,
                );
              },
            ),
          ),
        ],

        // Grouped Alone: Synonym & Topic Section
        if (synonyms.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF2B8A62).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF2B8A62).withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.topic_rounded,
                      color: Color(0xFF2B8A62),
                      size: 19,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'مرادفات وآيات ذات صلة بالموضوع (${ArabicUtils.toArabicDigits(synonyms.length)})',
                      style: const TextStyle(
                        color: Color(0xFF1F7A53),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (res.relatedTopicTerms.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'مفاهيم مرتبطة: ${res.relatedTopicTerms.join(' • ')}',
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...synonyms.map(
            (item) => _SmartResultCard(
              item: item,
              theme: theme,
              onTap: () {
                Navigator.of(context).pop();
                widget.controller.goToPage(
                  item.ayah.pageNumber,
                  highlightVerseKey: item.ayah.verseKey,
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilteredCategoryList(
    BuildContext context,
    SmartSearchResponse res,
    SearchMatchCategory category,
    MushafThemeData theme,
  ) {
    final items = res.byCategory(category);
    if (items.isEmpty) {
      return _buildEmptyState(theme);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _SmartResultCard(
          item: item,
          theme: theme,
          onTap: () {
            Navigator.of(context).pop();
            widget.controller.goToPage(
              item.ayah.pageNumber,
              highlightVerseKey: item.ayah.verseKey,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(MushafThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          'لا توجد نتائج مطابقة لـ "$_query"',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.secondaryTextColor,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsView(MushafThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.ornamentFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.pageInnerBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 18,
                      color: theme.ornamentPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'مميزات البحث الذكي:',
                      style: TextStyle(
                        color: theme.glyphColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '• البحث بالكلمة ومشتقات جذرها اللغوي (مثل: مغفرة ← يغفر، غفور، استغفروا).\n'
                  '• مطابقة الرسم العثماني والإملائي الحديث تلقائياً (مثل: الصلاة ← الصلوة).\n'
                  '• البحث التقريبي للعبارات حتى لو لم تتذكر الآية كاملة.\n'
                  '• قسم مستقل للمرادفات والآيات ذات الصلة بالموضوع.',
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 12.5,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'جرّب البحث بالكلمة والجذر والموضوع:',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedWordQueries.map((suggestion) {
              return ActionChip(
                backgroundColor: theme.ornamentFill,
                side: BorderSide(color: theme.pageInnerBorder),
                label: Text(
                  suggestion,
                  style: TextStyle(
                    color: theme.glyphColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => _applyQuickQuery(suggestion),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 16),
          Text(
            'جرّب البحث بالعبارات (حتى لو غير مكتملة):',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedPhraseQueries.map((suggestion) {
              return ActionChip(
                backgroundColor: theme.ornamentFill,
                side: BorderSide(color: theme.pageInnerBorder),
                label: Text(
                  suggestion,
                  style: TextStyle(
                    color: theme.glyphColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => _applyQuickQuery(suggestion),
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final MushafThemeData theme;
  final Color? accentColor;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.isSelected,
    required this.theme,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = accentColor ?? theme.ornamentPrimary;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : theme.ornamentFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : theme.pageInnerBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : theme.glyphColor,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SmartResultCard extends StatelessWidget {
  final SmartSearchResultItem item;
  final MushafThemeData theme;
  final VoidCallback onTap;

  const _SmartResultCard({
    required this.item,
    required this.theme,
    required this.onTap,
  });

  Color _badgeColor() {
    switch (item.category) {
      case SearchMatchCategory.direct:
        return theme.ornamentPrimary;
      case SearchMatchCategory.root:
        return const Color(0xFF8B6520);
      case SearchMatchCategory.approximate:
        return const Color(0xFF4A6B82);
      case SearchMatchCategory.synonymTopic:
        return const Color(0xFF2B8A62);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ayah = item.ayah;
    final badgeColor = _badgeColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.ornamentFill.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.pageInnerBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'سورة ${ayah.surahNameArabic} • الآية ${ArabicUtils.toArabicDigits(ayah.ayahNumber)}',
                      style: TextStyle(
                        color: theme.ornamentPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          item.matchReasonLabel,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
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
                          'ص ${ArabicUtils.toArabicDigits(ayah.pageNumber)}',
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildHighlightedUthmaniText(ayah, badgeColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedUthmaniText(dynamic ayah, Color highlightColor) {
    final uthmaniWords = (ayah.textUthmani as String).split(' ');
    final matchedSet = item.matchedCleanWords.toSet();
    final spans = <InlineSpan>[];

    for (int i = 0; i < uthmaniWords.length; i++) {
      final uWord = uthmaniWords[i];
      final cleaned = ArabicUtils.normalizeForSearch(uWord);
      final isHit = cleaned.isNotEmpty &&
          (matchedSet.contains(cleaned) ||
              matchedSet.any(
                (m) =>
                    m.length >= 3 &&
                    (cleaned.contains(m) || m.contains(cleaned)),
              ));

      spans.add(
        TextSpan(
          text: '$uWord ',
          style: TextStyle(
            color: isHit ? highlightColor : theme.glyphColor,
            fontWeight: isHit ? FontWeight.w800 : FontWeight.w400,
            backgroundColor:
                isHit ? highlightColor.withValues(alpha: 0.16) : null,
          ),
        ),
      );
    }

    spans.add(
      TextSpan(
        text: '﴿${ArabicUtils.toArabicDigits(ayah.ayahNumber)}﴾',
        style: TextStyle(
          color: theme.ornamentPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return RichText(
      textDirection: L10n.dir,
      text: TextSpan(
        style: TextStyle(
          color: theme.glyphColor,
          fontSize: 16.5,
          height: 1.7,
        ),
        children: spans,
      ),
    );
  }
}
