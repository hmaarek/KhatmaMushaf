import 'package:flutter/services.dart';

import 'qcf4_page_metrics.dart';

/// Dynamically loads King Fahd Complex QCF4 (1441H Madinah Mushaf) glyph fonts
/// (`assets/fonts/qcf4/QCF4_Hafs_01_W.ttf` .. `QCF4_Hafs_47_W.ttf`) on demand
/// via [FontLoader] so startup time is instant and memory usage remains low.
class QpcFontLoaderService {
  QpcFontLoaderService._();
  static final QpcFontLoaderService instance = QpcFontLoaderService._();

  final Set<int> _loadedFontIndices = <int>{};
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
    final idx = qcf4FontIndexForPage(pageNumber);
    final padded = idx.toString().padLeft(2, '0');
    return 'QCF4_Hafs_$padded';
  }

  /// Returns true if the QCF4 font chunk for [pageNumber] is already registered.
  bool isPageFontLoaded(int pageNumber) =>
      _loadedFontIndices.contains(qcf4FontIndexForPage(pageNumber));

  /// Dynamically loads the QCF4 TTF font chunk for [pageNumber] if not already loaded.
  Future<void> ensurePageFontLoaded(int pageNumber) {
    final fontIdx = qcf4FontIndexForPage(pageNumber);
    if (_loadedFontIndices.contains(fontIdx)) {
      return Future<void>.value();
    }
    final existing = _inFlightLoads[fontIdx];
    if (existing != null) {
      return existing;
    }

    final future = _loadFontChunkInternal(fontIdx);
    _inFlightLoads[fontIdx] = future;
    return future;
  }

  Future<void> _loadFontChunkInternal(int fontIdx) async {
    try {
      final padded = fontIdx.toString().padLeft(2, '0');
      final familyName = 'QCF4_Hafs_$padded';
      final assetPath = 'assets/fonts/qcf4/QCF4_Hafs_${padded}_W.ttf';

      final loader = FontLoader(familyName);
      loader.addFont(rootBundle.load(assetPath));
      await loader.load();

      _loadedFontIndices.add(fontIdx);
    } finally {
      _inFlightLoads.remove(fontIdx);
    }
  }

  /// Preloads the font chunk for [centerPage] and its immediate neighbors (+/- [radius]).
  Future<void> preloadWindow(int centerPage, {int radius = 2}) async {
    await Future.wait([
      ensureIndoPakFontLoaded(),
      ensurePageFontLoaded(centerPage),
    ]);
    final futures = <Future<void>>[];
    for (int offset = 1; offset <= radius; offset++) {
      final next = centerPage + offset;
      final prev = centerPage - offset;
      if (next <= 604 && !isPageFontLoaded(next)) {
        futures.add(ensurePageFontLoaded(next));
      }
      if (prev >= 1 && !isPageFontLoaded(prev)) {
        futures.add(ensurePageFontLoaded(prev));
      }
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }
}
