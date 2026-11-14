import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/mushaf_models.dart';
import '../services/tafsir_service.dart';
import '../state/mushaf_controller.dart';
import '../theme/mushaf_theme.dart';
import '../utils/arabic_utils.dart';

Future<void> showAyahExplanationSheet(
  BuildContext context, {
  required MushafController controller,
  required String verseKey,
  LineWord? initialWord,
  int initialTabIndex = 0,
}) async {
  final ayah = await controller.getAyahRecord(verseKey);
  if (!context.mounted || ayah == null) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AyahExplanationSheet(
      controller: controller,
      ayah: ayah,
      initialWord: initialWord,
      initialTabIndex: initialTabIndex,
    ),
  );
}

class AyahExplanationSheet extends StatefulWidget {
  final MushafController controller;
  final AyahRecord ayah;
  final LineWord? initialWord;
  final int initialTabIndex;

  const AyahExplanationSheet({
    super.key,
    required this.controller,
    required this.ayah,
    this.initialWord,
    this.initialTabIndex = 0,
  });

  @override
  State<AyahExplanationSheet> createState() => _AyahExplanationSheetState();
}

class _AyahExplanationSheetState extends State<AyahExplanationSheet> {
  late int _selectedTabIndex;
  String? _selectedWordLocation;

  SummaryTafsirSource _summarySource = SummaryTafsirSource.muyassar;
  DetailedTafsirSource _detailedSource = DetailedTafsirSource.ibnKathir;
  double _tafsirFontSize = 16.5;

  Future<AyahWordMeaningsResult>? _wordMeaningsFuture;
  Future<TafsirTextResult>? _summaryFuture;
  Future<TafsirTextResult>? _detailedFuture;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex.clamp(0, 2);
    _selectedWordLocation = widget.initialWord?.location;
    _loadAll();
  }

  void _loadAll() {
    final vk = widget.ayah.verseKey;
    _wordMeaningsFuture = TafsirService.instance.getWordMeaningsForAyah(vk);
    _summaryFuture = TafsirService.instance.getSummaryTafsir(vk, _summarySource);
    _detailedFuture =
        TafsirService.instance.getDetailedTafsir(vk, _detailedSource);
  }

  void _changeSummarySource(SummaryTafsirSource source) {
    if (_summarySource == source) return;
    setState(() {
      _summarySource = source;
      _summaryFuture = TafsirService.instance.getSummaryTafsir(
        widget.ayah.verseKey,
        _summarySource,
      );
    });
  }

  void _changeDetailedSource(DetailedTafsirSource source) {
    if (_detailedSource == source) return;
    setState(() {
      _detailedSource = source;
      _detailedFuture = TafsirService.instance.getDetailedTafsir(
        widget.ayah.verseKey,
        _detailedSource,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final theme = widget.controller.theme;
        final audio = widget.controller.audioService;
        final isPlayingThisAyah = audio.isPlayingAyah &&
            audio.activeVerseKey == widget.ayah.verseKey;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: BoxDecoration(
              color: theme.pageBackground,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: theme.pageOuterBorder, width: 1.5),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.secondaryTextColor.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Top Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          color: theme.ornamentPrimary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'بيان وتفسير الآية الكريمة',
                                style: TextStyle(
                                  color: theme.glyphColor,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'سورة ${widget.ayah.surahNameArabic} • الآية ${ArabicUtils.toArabicDigits(widget.ayah.ayahNumber)} • ص ${ArabicUtils.toArabicDigits(widget.ayah.pageNumber)}',
                                style: TextStyle(
                                  color: theme.ornamentPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isPlayingThisAyah
                                ? const Color(0xFFB54434)
                                : const Color(0xFF2B8A62),
                            side: BorderSide(
                              color: isPlayingThisAyah
                                  ? const Color(0xFFB54434)
                                  : const Color(0xFF2B8A62),
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            if (isPlayingThisAyah) {
                              widget.controller.stopAudio(clearSelection: false);
                            } else {
                              widget.controller.playAyahAudio(
                                widget.ayah.surahId,
                                widget.ayah.ayahNumber,
                              );
                            }
                          },
                          icon: Icon(
                            isPlayingThisAyah
                                ? Icons.stop_rounded
                                : Icons.play_circle_fill_rounded,
                            size: 17,
                          ),
                          label: Text(
                            isPlayingThisAyah ? 'إيقاف' : 'تلاوة الآية',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.glyphColor,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  // Ayah Uthmani Box
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 110),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: theme.ornamentFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.pageInnerBorder),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          '${widget.ayah.textUthmani} ﴿${ArabicUtils.toArabicDigits(widget.ayah.ayahNumber)}﴾',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.glyphColor,
                            fontSize: 17.5,
                            height: 1.65,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3-Tab Segmented Selector
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.ornamentFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.pageInnerBorder),
                      ),
                      child: Row(
                        children: [
                          _buildTabButton(
                            index: 0,
                            label: 'معاني الكلمات',
                            icon: Icons.translate_rounded,
                            theme: theme,
                          ),
                          _buildTabButton(
                            index: 1,
                            label: 'المعنى الإجمالي',
                            icon: Icons.short_text_rounded,
                            theme: theme,
                          ),
                          _buildTabButton(
                            index: 2,
                            label: 'التفسير التفصيلي',
                            icon: Icons.library_books_rounded,
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(
                    height: 1,
                    color: theme.pageInnerBorder.withValues(alpha: 0.5),
                  ),

                  // Tab Body
                  Expanded(
                    child: IndexedStack(
                      index: _selectedTabIndex,
                      children: [
                        _buildWordMeaningsTab(theme),
                        _buildSummaryTafsirTab(theme),
                        _buildDetailedTafsirTab(theme),
                      ],
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

  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
    required MushafThemeData theme,
  }) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => setState(() => _selectedTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? theme.ornamentPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : theme.secondaryTextColor,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : theme.glyphColor,
                    fontSize: 12.5,
                    fontWeight:
                        isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------- TAB 1: WORD MEANINGS --------------------

  Widget _buildWordMeaningsTab(MushafThemeData theme) {
    return FutureBuilder<AyahWordMeaningsResult>(
      future: _wordMeaningsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingView(theme, 'جاري تحميل معاني كلمات الآية...');
        }
        final data = snapshot.data;
        if (data == null || data.words.isEmpty) {
          return _buildErrorView(
            theme,
            'تعذر تحميل معاني الكلمات',
            onRetry: () => setState(() {
              _wordMeaningsFuture = TafsirService.instance
                  .getWordMeaningsForAyah(widget.ayah.verseKey);
            }),
          );
        }

        final selectedItem = data.words
            .where((w) => w.word.location == _selectedWordLocation)
            .firstOrNull;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Interactive Word Selector Chips
            Text(
              'المس أي كلمة لعرض معناها وسماع نطقها:',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: data.words.map((item) {
                final isSelected =
                    item.word.location == _selectedWordLocation;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() {
                      _selectedWordLocation = item.word.location;
                    });
                    widget.controller.pronounceWord(item.word);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.ornamentPrimary
                          : theme.ornamentFill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? theme.ornamentPrimary
                            : theme.pageInnerBorder,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.cleanWord,
                          style: TextStyle(
                            color:
                                isSelected ? Colors.white : theme.glyphColor,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.volume_up_rounded,
                          size: 14,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.9)
                              : theme.ornamentPrimary,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 14),

            // Highlighted Selected Word Card (if a word is selected)
            if (selectedItem != null) ...[
              _buildSelectedWordHeroCard(selectedItem, theme),
              const SizedBox(height: 14),
            ],

            // Concise Arabic Vocabulary Overview of the Ayah (تنوير المقباس / الجلالين)
            if (data.ayahVocabularyOverview != null &&
                data.ayahVocabularyOverview!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.ornamentFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.ornamentPrimary.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_stories_rounded,
                          size: 18,
                          color: theme.ornamentPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'بيان مفردات الآية وسياقها:',
                          style: TextStyle(
                            color: theme.ornamentPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.ayahVocabularyOverview!,
                      style: TextStyle(
                        color: theme.glyphColor,
                        fontSize: 15.5,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Full Word-by-Word List
            Text(
              'جميع كلمات الآية (${ArabicUtils.toArabicDigits(data.words.length)} كلمات):',
              style: TextStyle(
                color: theme.glyphColor,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...data.words.map((item) => _buildWordRowCard(item, theme)),
          ],
        );
      },
    );
  }

  Widget _buildSelectedWordHeroCard(
    WordMeaningItem item,
    MushafThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.ornamentPrimary.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.ornamentPrimary, width: 1.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.pageBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.ornamentPrimary),
                    ),
                    child: Text(
                      item.cleanWord,
                      style: TextStyle(
                        color: theme.glyphColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الكلمة رقم ${ArabicUtils.toArabicDigits(item.word.wordNumberInAyah)} في الآية',
                        style: TextStyle(
                          color: theme.ornamentPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'الجذر اللغوي: (${item.arabicRoot})',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.ornamentPrimary,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => widget.controller.pronounceWord(item.word),
                icon: const Icon(Icons.volume_up_rounded, size: 17),
                label: const Text(
                  'نطق الكلمة',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.arabicMeaning,
            style: TextStyle(
              color: theme.glyphColor,
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (item.englishMeaning != null &&
              item.englishMeaning!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Meaning: ${item.englishMeaning!}'
              '${item.transliteration != null ? " (${item.transliteration})" : ""}',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWordRowCard(WordMeaningItem item, MushafThemeData theme) {
    final isSelected = item.word.location == _selectedWordLocation;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedWordLocation = item.word.location;
          });
          widget.controller.pronounceWord(item.word);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.ornamentPrimary.withValues(alpha: 0.10)
                : theme.ornamentFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isSelected ? theme.ornamentPrimary : theme.pageInnerBorder,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.pageBackground,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.pageInnerBorder),
                ),
                child: Text(
                  ArabicUtils.toArabicDigits(item.word.wordNumberInAyah),
                  style: TextStyle(
                    color: theme.ornamentPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                constraints: const BoxConstraints(minWidth: 74),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.pageBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.pageInnerBorder),
                ),
                child: Text(
                  item.cleanWord,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.glyphColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.arabicMeaning,
                      style: TextStyle(
                        color: theme.glyphColor,
                        fontSize: 13.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          'الجذر: (${item.arabicRoot})',
                          style: TextStyle(
                            color: theme.ornamentPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (item.englishMeaning != null &&
                            item.englishMeaning!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '• ${item.englishMeaning!}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                color: theme.secondaryTextColor,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.volume_up_rounded,
                  color: theme.ornamentPrimary,
                  size: 20,
                ),
                onPressed: () => widget.controller.pronounceWord(item.word),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------- TAB 2: FULL AYAH SUMMARY --------------------

  Widget _buildSummaryTafsirTab(MushafThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: SummaryTafsirSource.values.map((source) {
                    final isSelected = _summarySource == source;
                    return ChoiceChip(
                      label: Text(
                        source.arabicTitle,
                        style: TextStyle(
                          color: isSelected ? Colors.white : theme.glyphColor,
                          fontSize: 12.5,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: theme.ornamentPrimary,
                      backgroundColor: theme.ornamentFill,
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                        color: isSelected
                            ? theme.ornamentPrimary
                            : theme.pageInnerBorder,
                      ),
                      onSelected: (_) => _changeSummarySource(source),
                    );
                  }).toList(growable: false),
                ),
              ),
              _buildFontZoomButtons(theme),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<TafsirTextResult>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingView(
                  theme,
                  'جاري تحميل ${_summarySource.arabicTitle}...',
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return _buildErrorView(
                  theme,
                  'يتطلب تحميل التفسير للمرة الأولى الاتصال بالإنترنت (ويُحفظ بعدها تلقائياً للقراءة بدون إنترنت)',
                  onRetry: () => setState(() {
                    _summaryFuture = TafsirService.instance.getSummaryTafsir(
                      widget.ayah.verseKey,
                      _summarySource,
                    );
                  }),
                );
              }
              return _buildTafsirContentCard(snapshot.data!, theme);
            },
          ),
        ),
      ],
    );
  }

  // -------------------- TAB 3: DETAILED TAFSIR --------------------

  Widget _buildDetailedTafsirTab(MushafThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: DetailedTafsirSource.values.map((source) {
                      final isSelected = _detailedSource == source;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: ChoiceChip(
                          label: Text(
                            source.arabicTitle,
                            style: TextStyle(
                              color:
                                  isSelected ? Colors.white : theme.glyphColor,
                              fontSize: 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: theme.ornamentPrimary,
                          backgroundColor: theme.ornamentFill,
                          checkmarkColor: Colors.white,
                          side: BorderSide(
                            color: isSelected
                                ? theme.ornamentPrimary
                                : theme.pageInnerBorder,
                          ),
                          onSelected: (_) => _changeDetailedSource(source),
                        ),
                      );
                    }).toList(growable: false),
                  ),
                ),
              ),
              _buildFontZoomButtons(theme),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<TafsirTextResult>(
            future: _detailedFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingView(
                  theme,
                  'جاري تحميل ${_detailedSource.arabicTitle}...',
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return _buildErrorView(
                  theme,
                  'يتطلب تحميل التفسير التفصيلي للمرة الأولى الاتصال بالإنترنت (ويُحفظ بعدها تلقائياً على جهازك)',
                  onRetry: () => setState(() {
                    _detailedFuture = TafsirService.instance.getDetailedTafsir(
                      widget.ayah.verseKey,
                      _detailedSource,
                    );
                  }),
                );
              }
              return _buildTafsirContentCard(snapshot.data!, theme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFontZoomButtons(MushafThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'تصغير الخط',
          icon: Icon(
            Icons.text_decrease_rounded,
            size: 18,
            color: theme.secondaryTextColor,
          ),
          onPressed: () {
            setState(() {
              _tafsirFontSize = (_tafsirFontSize - 1.5).clamp(13.5, 26.0);
            });
          },
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'تكبير الخط',
          icon: Icon(
            Icons.text_increase_rounded,
            size: 19,
            color: theme.ornamentPrimary,
          ),
          onPressed: () {
            setState(() {
              _tafsirFontSize = (_tafsirFontSize + 1.5).clamp(13.5, 26.0);
            });
          },
        ),
      ],
    );
  }

  Widget _buildTafsirContentCard(
    TafsirTextResult result,
    MushafThemeData theme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.ornamentFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.pageInnerBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title,
                        style: TextStyle(
                          color: theme.ornamentPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        result.author,
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final textToCopy =
                        '﴿ ${widget.ayah.textUthmani} ﴾ [سورة ${widget.ayah.surahNameArabic}: ${ArabicUtils.toArabicDigits(widget.ayah.ayahNumber)}]\n\n'
                        '【${result.title}】:\n${result.text}';
                    await Clipboard.setData(ClipboardData(text: textToCopy));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          duration: const Duration(milliseconds: 1500),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: theme.hudSurface,
                          content: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              'تم نسخ التفسير مع الآية الكريمة',
                              style: TextStyle(color: theme.hudText),
                            ),
                          ),
                        ),
                      );
                  },
                  icon: Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: theme.ornamentPrimary,
                  ),
                  label: Text(
                    'نسخ',
                    style: TextStyle(
                      color: theme.ornamentPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            Divider(
              height: 18,
              color: theme.pageInnerBorder.withValues(alpha: 0.6),
            ),
            SelectableText(
              result.text,
              style: TextStyle(
                color: theme.glyphColor,
                fontSize: _tafsirFontSize,
                height: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView(MushafThemeData theme, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: theme.ornamentPrimary),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(
    MushafThemeData theme,
    String message, {
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: theme.secondaryTextColor,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 13.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.ornamentPrimary,
                side: BorderSide(color: theme.ornamentPrimary),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'إعادة المحاولة',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
