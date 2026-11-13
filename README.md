# Mushaf App (المصحف الشريف) — v1.0 MVP

A distraction-free **15-Line Madinah Mushaf** reading and bookmarking application for **iOS and Android** built with Flutter, using the **King Fahd Glorious Qur'an Printing Complex (QPC V1)** 604 page-specific glyph fonts and a pre-populated offline SQLite database (`assets/mushaf.db`).

---

## Architecture & Key Features

1. **Authentic 15-Line Madinah Mushaf Rendering Engine (Option A)**
   - **604 Page-Specific QPC V1 Fonts (`assets/fonts/qpc/p001.ttf` – `p604.ttf`)**: Dynamically registered on demand via Flutter's `FontLoader` (`QpcFontLoaderService`) for the visible page and its immediate neighbors (`±2` pages), keeping startup instant and memory footprint low.
   - **Calligraphic Ornaments (`Surahs.ttf` & `QPC1BSML.ttf`)**: Ornate geometric Surah headers with calligraphic Surah titles, Basmala lines (`ﭑﭒﭓ`), and centered ornamental layout for **Pages 1 & 2** (Surah Al-Fatihah and opening of Surah Al-Baqarah).
   - **Word-Level Interactivity**: Each word on a line maps to its exact `surah:ayah:word` coordinate and QPC V1 glyph (`line_words` table), enabling whole-Ayah highlighting across lines on long press.

2. **Local Offline SQLite Database (`assets/mushaf.db`)**
   - `surahs` (114 rows): Arabic/English names, translation, Meccan/Medinan classification, verse counts, and page ranges.
   - `juzs` (30 rows): Arabic names, starting Surah & Ayah, and page ranges.
   - `pages` (604 rows): Juz/Hizb metadata, Surah spans, and centered-layout flags.
   - `page_lines` (9,046 rows): Line-by-line structure (`surah-header`, `basmala`, `text`) across all 604 pages.
   - `line_words` (77,995 rows): Word-by-word Uthmani tokens and QPC V1 glyph codes.
   - `ayahs` (6,236 rows): Full Uthmani text, stripped/diacritic-free normalized `text_clean` for instant offline Arabic search, QPC V1 glyphs, plus nullable `audio_url` and `tafseer_id` columns reserved for future expansion.
   - `bookmarks`: User Page and Ayah bookmarks persisted locally.

3. **Core User Experience**
   - **Smooth 604-Page RTL PageView Navigation** with automatic screen wakelock (`wakelock_plus`).
   - **Translucent HUD Overlay**: Tap the center of the screen to toggle the top bar (Surah/Juz info, Index, Search, Bookmarks, Quick Page Bookmark Ribbon) and bottom bar (Theme Switcher + RTL 1–604 Page Scrubber Slider).
   - **Fast Offline Index**: Browse all 114 Surahs (with Meccan/Medinan & start page), all 30 Juzs, or jump directly to any page (1–604).
   - **Offline Diacritic-Free Arabic Search**: Search any word or phrase in plain Arabic against `text_clean` and jump straight to the matching page with the target Ayah highlighted.
   - **Auto-Saved Last Read Page + Page & Ayah Bookmarks**: Long-press any Ayah to highlight, bookmark, or copy formatted Uthmani text to the clipboard.
   - **3 Reading Themes**:
     - **Warm Mushaf Paper** (Cream/Sepia `#FAF2E1`)
     - **Crisp White** (`#FFFFFF`)
     - **True AMOLED Dark Mode** (`#000000` with cleanly recolored `#EDE6D8` glyphs and muted gold ornaments)

---

## Project Structure

```text
lib/
├── main.dart                      # App entry point & portrait orientation lock
├── models/
│   └── mushaf_models.dart         # Data models for Surahs, Juzs, Pages, Lines, Words, Ayahs, Bookmarks
├── services/
│   ├── database_service.dart      # SQLite initialization, LRU page cache, offline search & bookmarks
│   └── font_loader_service.dart   # Dynamic on-demand FontLoader for p001.ttf..p604.ttf
├── state/
│   └── mushaf_controller.dart     # Reader state, last-read persistence, wakelock & preloading
├── theme/
│   └── mushaf_theme.dart          # Warm Paper, Crisp White, and True AMOLED Dark themes
├── utils/
│   └── arabic_utils.dart          # Eastern Arabic-Indic digit formatting & diacritic stripping
├── widgets/
│   ├── mushaf_page_widget.dart    # 15-line & centered page renderer with interactive word spans
│   ├── reader_hud_overlay.dart    # Translucent top/bottom HUD & RTL 1-604 page scrubber
│   └── surah_header_banner.dart   # Custom-painted Islamic ornamental Surah header banner
└── screens/
    ├── reader_screen.dart         # 604-page RTL PageView & Ayah long-press action sheet
    ├── index_sheet.dart           # 3-tab Surah (1-114), Juz (1-30) & Page Jump index
    ├── search_sheet.dart          # Instant offline Arabic search modal
    └── bookmarks_sheet.dart       # Saved Page & Ayah bookmarks modal
```

---

## Getting Started

```bash
flutter pub get
flutter run
```
