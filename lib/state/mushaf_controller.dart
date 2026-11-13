import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/mushaf_models.dart';
import '../services/database_service.dart';
import '../services/font_loader_service.dart';
import '../theme/mushaf_theme.dart';

/// Controls how the 15-line Uthmani Mushaf page is sized/zoomed.
/// All modes strictly preserve the 15-line Madinah Mushaf page & line breaks.
enum MushafFontScaleMode {
  standard(
    scaleFactor: 1.0,
    arabicTitle: 'قياسي (كامل الصفحة)',
    arabicSubtitle: 'عرض الـ ١٥ سطراً كاملة على الشاشة بدون تمرير',
    badgeText: '١٠٠٪',
    icon: Icons.fit_screen_rounded,
  ),
  large(
    scaleFactor: 1.22,
    arabicTitle: 'كبير',
    arabicSubtitle: 'تكبير خط المصحف مع تمرير عمودي سلس للصفحة',
    badgeText: '١٢٠٪',
    icon: Icons.text_increase_rounded,
  ),
  extraLarge(
    scaleFactor: 1.45,
    arabicTitle: 'كبير جداً',
    arabicSubtitle: 'خط واضح وكبير جداً مع الحفاظ التام على الـ ١٥ سطراً',
    badgeText: '١٤٥٪',
    icon: Icons.format_size_rounded,
  ),
  pinchToZoom(
    scaleFactor: 1.0,
    arabicTitle: 'تكبير حر باللمس (Pinch-to-Zoom)',
    arabicSubtitle: 'استخدم إصبعين لتكبير وتصغير الصفحة بحرية تامة',
    badgeText: 'حر  pinch',
    icon: Icons.pinch_rounded,
  );

  final double scaleFactor;
  final String arabicTitle;
  final String arabicSubtitle;
  final String badgeText;
  final IconData icon;

  const MushafFontScaleMode({
    required this.scaleFactor,
    required this.arabicTitle,
    required this.arabicSubtitle,
    required this.badgeText,
    required this.icon,
  });
}

class MushafController extends ChangeNotifier {
  static const String _prefLastReadPage = 'mushaf_last_read_page';
  static const String _prefThemeIndex = 'mushaf_theme_index';
  static const String _prefFontScaleModeIndex = 'mushaf_font_scale_mode_index';
  static const String _prefKeepScreenAwake = 'mushaf_keep_screen_awake';

  final DatabaseService _dbService = DatabaseService.instance;
  final QpcFontLoaderService _fontLoader = QpcFontLoaderService.instance;

  SharedPreferences? _prefs;
  PageController? _pageController;

  bool _isInitialized = false;
  int _currentPage = 1;
  MushafThemeType _themeType = MushafThemeType.warmPaper;
  MushafFontScaleMode _fontScaleMode = MushafFontScaleMode.standard;
  bool _keepScreenAwake = true;
  bool _isHudVisible = false;
  String? _selectedVerseKey;

  List<SurahInfo> _surahs = const <SurahInfo>[];
  List<JuzInfo> _juzs = const <JuzInfo>[];
  List<BookmarkItem> _bookmarks = const <BookmarkItem>[];
  final Set<int> _bookmarkedPages = <int>{};
  final Set<String> _bookmarkedVerseKeys = <String>{};

  bool get isInitialized => _isInitialized;
  int get currentPage => _currentPage;
  MushafThemeType get themeType => _themeType;
  MushafThemeData get theme => MushafThemeData.fromType(_themeType);
  MushafFontScaleMode get fontScaleMode => _fontScaleMode;
  bool get keepScreenAwake => _keepScreenAwake;
  bool get isHudVisible => _isHudVisible;
  String? get selectedVerseKey => _selectedVerseKey;
  List<SurahInfo> get surahs => _surahs;
  List<JuzInfo> get juzs => _juzs;
  List<BookmarkItem> get bookmarks => _bookmarks;
  List<BookmarkItem> get pageBookmarks =>
      _bookmarks.where((b) => b.isPageBookmark).toList(growable: false);
  List<BookmarkItem> get ayahBookmarks =>
      _bookmarks.where((b) => b.isAyahBookmark).toList(growable: false);

  PageController get pageController {
    _pageController ??= PageController(initialPage: _currentPage - 1);
    return _pageController!;
  }

  MushafPageData? get currentPageData =>
      _dbService.getCachedPageData(_currentPage);

  SurahInfo? getSurahById(int id) {
    if (id < 1 || id > _surahs.length) return null;
    return _surahs[id - 1];
  }

  bool isPageBookmarked(int pageNumber) =>
      _bookmarkedPages.contains(pageNumber);

  bool get isCurrentPageBookmarked => _bookmarkedPages.contains(_currentPage);

  bool isAyahBookmarked(String verseKey) =>
      _bookmarkedVerseKeys.contains(verseKey);

  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    final savedPage = (_prefs?.getInt(_prefLastReadPage) ?? 1).clamp(1, 604);
    final savedThemeIdx = (_prefs?.getInt(_prefThemeIndex) ?? 0)
        .clamp(0, MushafThemeType.values.length - 1);
    final savedScaleIdx = (_prefs?.getInt(_prefFontScaleModeIndex) ?? 0)
        .clamp(0, MushafFontScaleMode.values.length - 1);
    final savedWake = _prefs?.getBool(_prefKeepScreenAwake) ?? true;

    _currentPage = savedPage;
    _themeType = MushafThemeType.values[savedThemeIdx];
    _fontScaleMode = MushafFontScaleMode.values[savedScaleIdx];
    _keepScreenAwake = savedWake;
    _pageController = PageController(initialPage: _currentPage - 1);

    await _applyWakelock(_keepScreenAwake);

    // Load index tables, bookmarks, and initial page data + QPC font in parallel
    final results = await Future.wait<Object?>([
      _dbService.getAllSurahs(),
      _dbService.getAllJuzs(),
      _dbService.getBookmarks(),
      _dbService.preloadPages(_currentPage, radius: 1),
      _fontLoader.preloadWindow(_currentPage, radius: 1),
    ]);

    _surahs = results[0] as List<SurahInfo>;
    _juzs = results[1] as List<JuzInfo>;
    _updateBookmarksCache(results[2] as List<BookmarkItem>);

    _isInitialized = true;
    notifyListeners();

    // Preload slightly wider window in background
    unawaited(_dbService.preloadPages(_currentPage, radius: 2));
    unawaited(_fontLoader.preloadWindow(_currentPage, radius: 2));
  }

  Future<void> _applyWakelock(bool enabled) async {
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {
      // Ignore wakelock errors in headless/test environments
    }
  }

  void _updateBookmarksCache(List<BookmarkItem> items) {
    _bookmarks = items;
    _bookmarkedPages
      ..clear()
      ..addAll(
        items.where((b) => b.isPageBookmark).map((b) => b.pageNumber),
      );
    _bookmarkedVerseKeys
      ..clear()
      ..addAll(
        items
            .where((b) => b.isAyahBookmark && b.verseKey != null)
            .map((b) => b.verseKey!),
      );
  }

  /// Loads page data and ensures its QPC V1 glyph font is registered in Flutter.
  Future<MushafPageData> loadPageAndFont(int pageNumber) async {
    final results = await Future.wait([
      _dbService.getPageData(pageNumber),
      _fontLoader.ensurePageFontLoaded(pageNumber),
    ]);
    return results[0] as MushafPageData;
  }

  /// Called by [PageView.onPageChanged] when the user swipes between pages.
  void onPageChanged(int index) {
    final newPage = (index + 1).clamp(1, 604);
    if (_currentPage == newPage) return;

    _currentPage = newPage;
    _selectedVerseKey = null;
    _prefs?.setInt(_prefLastReadPage, _currentPage);
    notifyListeners();

    unawaited(_preloadAround(_currentPage));
  }

  Future<void> _preloadAround(int page) async {
    await Future.wait([
      _dbService.preloadPages(page, radius: 2),
      _fontLoader.preloadWindow(page, radius: 2),
    ]);
    notifyListeners();
  }

  /// Jumps directly to [targetPage] (1..604) and optionally highlights [highlightVerseKey].
  Future<void> goToPage(
    int targetPage, {
    String? highlightVerseKey,
    bool hideHud = true,
  }) async {
    final clamped = targetPage.clamp(1, 604);
    await loadPageAndFont(clamped);

    _currentPage = clamped;
    _selectedVerseKey = highlightVerseKey;
    if (hideHud) {
      _isHudVisible = false;
    }
    _prefs?.setInt(_prefLastReadPage, _currentPage);

    if (_pageController != null && _pageController!.hasClients) {
      _pageController!.jumpToPage(clamped - 1);
    }
    notifyListeners();

    unawaited(_preloadAround(clamped));
  }

  void toggleHud() {
    if (_selectedVerseKey != null) {
      _selectedVerseKey = null;
      notifyListeners();
      return;
    }
    _isHudVisible = !_isHudVisible;
    notifyListeners();
  }

  void setHudVisible(bool visible) {
    if (_isHudVisible == visible) return;
    _isHudVisible = visible;
    notifyListeners();
  }

  void selectVerse(String? verseKey) {
    if (_selectedVerseKey == verseKey) return;
    _selectedVerseKey = verseKey;
    notifyListeners();
  }

  void setTheme(MushafThemeType newTheme) {
    if (_themeType == newTheme) return;
    _themeType = newTheme;
    _prefs?.setInt(_prefThemeIndex, newTheme.index);
    notifyListeners();
  }

  void setFontScaleMode(MushafFontScaleMode mode) {
    if (_fontScaleMode == mode) return;
    _fontScaleMode = mode;
    _prefs?.setInt(_prefFontScaleModeIndex, mode.index);
    notifyListeners();
  }

  void setKeepScreenAwake(bool value) {
    if (_keepScreenAwake == value) return;
    _keepScreenAwake = value;
    _prefs?.setBool(_prefKeepScreenAwake, value);
    unawaited(_applyWakelock(value));
    notifyListeners();
  }

  void cycleTheme() {
    final nextIndex = (_themeType.index + 1) % MushafThemeType.values.length;
    setTheme(MushafThemeType.values[nextIndex]);
  }

  Future<bool> toggleCurrentPageBookmark() async {
    final pageData = await _dbService.getPageData(_currentPage);
    final added = await _dbService.togglePageBookmark(pageData.info);
    final updated = await _dbService.getBookmarks();
    _updateBookmarksCache(updated);
    notifyListeners();
    return added;
  }

  Future<bool> toggleAyahBookmark(AyahRecord ayah) async {
    final added = await _dbService.toggleAyahBookmark(ayah);
    final updated = await _dbService.getBookmarks();
    _updateBookmarksCache(updated);
    notifyListeners();
    return added;
  }

  Future<void> deleteBookmark(int id) async {
    await _dbService.deleteBookmark(id);
    final updated = await _dbService.getBookmarks();
    _updateBookmarksCache(updated);
    notifyListeners();
  }

  Future<AyahRecord?> getAyahRecord(String verseKey) {
    return _dbService.getAyahByVerseKey(verseKey);
  }

  Future<List<AyahRecord>> searchAyahs(String query) {
    return _dbService.searchAyahs(query);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }
}
