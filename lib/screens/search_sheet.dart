import 'dart:async';
import 'package:flutter/material.dart';

import '../models/mushaf_models.dart';
import '../state/mushaf_controller.dart';
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
  List<AyahRecord> _results = const <AyahRecord>[];

  static const List<String> _suggestedQueries = [
    'الحمد لله رب العالمين',
    'الله لا اله الا هو الحي القيوم',
    'اصحاب الكهف',
    'ربنا اتنا في الدنيا حسنة',
    'قل هو الله احد',
    'ان مع العسر يسرا',
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
        _results = const <AyahRecord>[];
        _isSearching = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
    });
    _debounce = Timer(const Duration(milliseconds: 180), () async {
      final matches = await widget.controller.searchAyahs(value);
      if (!mounted) return;
      setState(() {
        _results = matches;
        _isSearching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.controller.theme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
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
                    'البحث في القرآن الكريم (بدون تشكيل)',
                    style: TextStyle(
                      color: theme.glyphColor,
                      fontSize: 17,
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
                  hintText: 'اكتب كلمة أو آية للبحث الفوري...',
                  hintStyle: TextStyle(
                    color: theme.secondaryTextColor.withValues(alpha: 0.7),
                    fontSize: 14,
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
            const SizedBox(height: 10),
            Expanded(
              child: _query.trim().isEmpty
                  ? _buildSuggestionsView()
                  : _isSearching
                      ? Center(
                          child: CircularProgressIndicator(
                            color: theme.ornamentPrimary,
                          ),
                        )
                      : _results.isEmpty
                          ? Center(
                              child: Text(
                                'لا توجد نتائج مطابقة لـ "$_query"',
                                style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 15,
                                ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    'عدد النتائج: ${ArabicUtils.toArabicDigits(_results.length)}',
                                    style: TextStyle(
                                      color: theme.secondaryTextColor,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      4,
                                      16,
                                      20,
                                    ),
                                    itemCount: _results.length,
                                    separatorBuilder: (_, _) => Divider(
                                      height: 1,
                                      color: theme.pageInnerBorder
                                          .withValues(alpha: 0.45),
                                    ),
                                    itemBuilder: (context, index) {
                                      final ayah = _results[index];
                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        onTap: () {
                                          Navigator.of(context).pop();
                                          widget.controller.goToPage(
                                            ayah.pageNumber,
                                            highlightVerseKey: ayah.verseKey,
                                          );
                                        },
                                        title: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'سورة ${ayah.surahNameArabic} • الآية ${ArabicUtils.toArabicDigits(ayah.ayahNumber)}',
                                              style: TextStyle(
                                                color: theme.ornamentPrimary,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: theme.ornamentFill,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: theme.pageInnerBorder,
                                                ),
                                              ),
                                              child: Text(
                                                'ص ${ArabicUtils.toArabicDigits(ayah.pageNumber)}',
                                                style: TextStyle(
                                                  color:
                                                      theme.secondaryTextColor,
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        subtitle: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6.0),
                                          child: Text(
                                            '${ayah.textUthmani} ﴿${ArabicUtils.toArabicDigits(ayah.ayahNumber)}﴾',
                                            style: TextStyle(
                                              color: theme.glyphColor,
                                              fontSize: 16.5,
                                              height: 1.65,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsView() {
    final theme = widget.controller.theme;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أمثلة للبحث السريع:',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedQueries.map((suggestion) {
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
                onPressed: () {
                  _searchController.text = suggestion;
                  _onQueryChanged(suggestion);
                },
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }
}
