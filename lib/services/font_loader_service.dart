import 'package:flutter/services.dart';

/// Dynamically loads King Fahd Complex (QPC V1) page-specific glyph fonts
/// (`assets/fonts/qpc/p001.ttf` .. `p604.ttf`) on demand via [FontLoader]
/// so startup time is instant and memory usage remains low.
class QpcFontLoaderService {
  QpcFontLoaderService._();
  static final QpcFontLoaderService instance = QpcFontLoaderService._();

  final Set<int> _loadedPages = <int>{};
  final Map<int, Future<void>> _inFlightLoads = <int, Future<void>>{};
  bool _indoPakLoaded = false;
  Future<void>? _indoPakInFlight;

  /// Ensures `assets/fonts/IndoPak.ttf` is registered under family `'IndoPak'`.
  Future<void> ensureIndoPakFontLoaded() async {
    if (_indoPakLoaded) return;
    if (_indoPakInFlight != null) {
      await _indoPakInFlight;
      return;
    }
    final future = () async {
      try {
        final loader = FontLoader('IndoPak');
        loader.addFont(rootBundle.load('assets/fonts/IndoPak.ttf'));
        await loader.load();
        _indoPakLoaded = true;
      } finally {
        _indoPakInFlight = null;
      }
    }();
    _indoPakInFlight = future;
    await future;
  }

  /// Returns the registered Flutter font family name for [pageNumber] (1..604).
  static String fontFamilyForPage(int pageNumber) {
    final padded = pageNumber.clamp(1, 604).toString().padLeft(3, '0');
    return 'QPC1_p$padded';
  }

  /// Returns true if the QPC V1 font for [pageNumber] is already registered.
  bool isPageFontLoaded(int pageNumber) => _loadedPages.contains(pageNumber);

  /// Dynamically loads the TTF font for [pageNumber] if not already loaded.
  Future<void> ensurePageFontLoaded(int pageNumber) {
    final clamped = pageNumber.clamp(1, 604);
    if (_loadedPages.contains(clamped)) {
      return Future<void>.value();
    }
    final existing = _inFlightLoads[clamped];
    if (existing != null) {
      return existing;
    }

    final future = _loadFontInternal(clamped);
    _inFlightLoads[clamped] = future;
    return future;
  }

  Future<void> _loadFontInternal(int pageNumber) async {
    try {
      final padded = pageNumber.toString().padLeft(3, '0');
      final familyName = fontFamilyForPage(pageNumber);
      final assetPath = 'assets/fonts/qpc/p$padded.ttf';

      final loader = FontLoader(familyName);
      loader.addFont(rootBundle.load(assetPath));
      await loader.load();

      _loadedPages.add(pageNumber);
    } finally {
      _inFlightLoads.remove(pageNumber);
    }
  }

  /// Preloads the font for [centerPage] and its immediate neighbors (+/- [radius]).
  Future<void> preloadWindow(int centerPage, {int radius = 2}) async {
    await Future.wait([
      ensureIndoPakFontLoaded(),
      ensurePageFontLoaded(centerPage),
    ]);
    final futures = <Future<void>>[];
    for (int offset = 1; offset <= radius; offset++) {
      final next = centerPage + offset;
      final prev = centerPage - offset;
      if (next <= 604 && !_loadedPages.contains(next)) {
        futures.add(ensurePageFontLoaded(next));
      }
      if (prev >= 1 && !_loadedPages.contains(prev)) {
        futures.add(ensurePageFontLoaded(prev));
      }
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }
}
