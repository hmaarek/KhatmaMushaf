import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/khatma_models.dart';
import '../models/mushaf_models.dart';
import '../state/mushaf_controller.dart';
import '../theme/mushaf_theme.dart';
import '../utils/arabic_utils.dart';

/// Shows the app startup dialog asking the user whether to:
/// 1. Continue the last active Khatma (if one is active),
/// 2. Start a new Khatma (or import one started on another device / real Mushaf), or
/// 3. Do free reading.
Future<void> showStartupKhatmaPromptDialog(
  BuildContext context, {
  required MushafController controller,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogCtx) => _StartupKhatmaPromptDialog(
      controller: controller,
      parentContext: context,
    ),
  );
}

/// Shows the configuration dialog to start a new Khatma (defaults to Surah 1, Ayah 1,
/// and Today's date, while clearly indicating that the user can choose a past start date
/// and another verse if continuing a Khatma from a physical Mushaf or another device).
Future<KhatmaRecord?> showStartNewKhatmaDialog(
  BuildContext context, {
  required MushafController controller,
}) async {
  return showDialog<KhatmaRecord>(
    context: context,
    barrierDismissible: true,
    builder: (dialogCtx) => _StartNewKhatmaDialog(
      controller: controller,
    ),
  );
}

/// Opens the celebratory Full Khatma Report modal dialog/sheet.
Future<void> showKhatmaReportModal(
  BuildContext context, {
  required MushafController controller,
  required KhatmaRecord khatma,
  bool isJustCompletedCelebration = false,
}) async {
  final report = controller.generateKhatmaReport(khatma);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _KhatmaReportSheet(
      controller: controller,
      khatma: khatma,
      report: report,
      isCelebration: isJustCompletedCelebration,
    ),
  );
}

class KhatmaSheet extends StatefulWidget {
  final MushafController controller;

  const KhatmaSheet({
    super.key,
    required this.controller,
  });

  @override
  State<KhatmaSheet> createState() => _KhatmaSheetState();
}

class _KhatmaSheetState extends State<KhatmaSheet>
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
        final activeKhatma = widget.controller.activeKhatma;
        final completedList = widget.controller.completedKhatmas;

        return Directionality(
          textDirection: L10n.dir,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: BoxDecoration(
              color: theme.pageBackground,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
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
                            Icons.workspace_premium_rounded,
                            color: theme.ornamentPrimary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tr('متابعة الختمة القرآنية', 'Khatma Tracker'),
                            style: TextStyle(
                              color: theme.glyphColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: theme.glyphColor,
                        ),
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
                      Tab(text: tr('الختمة الحالية', 'Current Khatma')),
                      Tab(
                        text:
                            tr('الختمات المكتملة (${ArabicUtils.toArabicDigits(completedList.length)})', 'Completed (${completedList.length})'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      activeKhatma == null
                          ? _buildNoActiveKhatmaView(context, theme)
                          : _buildActiveKhatmaView(
                              context,
                              activeKhatma,
                              theme,
                            ),
                      _buildCompletedKhatmasTab(context, completedList, theme),
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

  Widget _buildNoActiveKhatmaView(BuildContext context, MushafThemeData theme) {
    final nextSerial = widget.controller.khatmas.isEmpty
        ? 1
        : widget.controller.khatmas
                  .map((k) => k.serialNumber)
                  .reduce((a, b) => a > b ? a : b) +
              1;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(22.0),
          decoration: BoxDecoration(
            color: theme.ornamentFill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.pageOuterBorder, width: 1.4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: theme.ornamentPrimary,
                    width: 1.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/intro_cover.jpg',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                tr('ابدأ الختمة رقم ${ArabicUtils.toArabicDigits(nextSerial)}', 'Start Khatma #$nextSerial'),
                style: TextStyle(
                  color: theme.glyphColor,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'يمكنك بدء ختمة جديدة من أول المصحف (سورة الفاتحة آية ١) بتاريخ اليوم، أو استكمال ختمة بدأتها في مصحفك الورقي أو على جهاز آخر عبر تحديد تاريخ بدئها في الماضي والآية التي وصلت إليها.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: 13.5,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.ornamentPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final created = await showStartNewKhatmaDialog(
                      context,
                      controller: widget.controller,
                    );
                    if (!context.mounted || created == null) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: theme.hudSurface,
                          content: Directionality(
                            textDirection: L10n.dir,
                            child: Text(
                              tr('بدأت ${created.displayTitle} على بركة الله!', '${created.displayTitle} started!'),
                              style: TextStyle(color: theme.hudText),
                            ),
                          ),
                        ),
                      );
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: Text(
                    tr('بدء الختمة رقم ${ArabicUtils.toArabicDigits(nextSerial)} الآن', 'Start Khatma #$nextSerial Now'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveKhatmaView(
    BuildContext context,
    KhatmaRecord khatma,
    MushafThemeData theme,
  ) {
    final mark = khatma.currentMark;
    final prevMark = khatma.previousMark;
    final percent = (khatma.progressRatio * 100).clamp(0.0, 100.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        // 1. Active Khatma Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.ornamentFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.ornamentPrimary, width: 1.4),
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
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.ornamentPrimary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#${ArabicUtils.toArabicDigits(khatma.serialNumber)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        khatma.displayTitle,
                        style: TextStyle(
                          color: theme.glyphColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '${ArabicUtils.toArabicDigits(percent.toStringAsFixed(1))}٪',
                        style: TextStyle(
                          color: theme.ornamentPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: tr('حذف هذه الختمة', 'Delete this Khatma'),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: theme.bookmarkRibbon,
                          size: 20,
                        ),
                        onPressed: () =>
                            _confirmAndDeleteKhatma(context, khatma),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tr('تاريخ ووقت البدء: ', 'Started: ') + _formatDateTimeArabic(khatma.startedAt),
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _DecoratedGreenProgressBar(
                progress: khatma.progressRatio.clamp(0.02, 1.0),
                theme: theme,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniStatBox(
                    label: tr('الآيات المقروءة', 'Ayahs Read'),
                    value:
                        '${ArabicUtils.toArabicDigits(khatma.reachedAyahsCount)} / ٦٢٣٦',
                    theme: theme,
                  ),
                  const SizedBox(width: 8),
                  _MiniStatBox(
                    label: tr('الصفحة الحالية', 'Current Page'),
                    value:
                        '${ArabicUtils.toArabicDigits(khatma.reachedPageNumber)} / ٦٠٤',
                    theme: theme,
                  ),
                  const SizedBox(width: 8),
                  _MiniStatBox(
                    label: tr('الجزء الحالي', 'Current Juz'),
                    value:
                        '${ArabicUtils.toArabicDigits(khatma.reachedJuzNumber)} / ٣٠',
                    theme: theme,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Current Khatma Mark & Rollback Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.pageBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.pageInnerBorder, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.flag_rounded,
                    color: theme.ornamentPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tr('الموضع الحالي في الختمة', 'Current Khatma Position'),
                    style: TextStyle(
                      color: theme.glyphColor,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (mark == null)
                Text(
                  'لم يتم وضع علامة بعد (البداية: سورة الفاتحة ص ١).\nاضغط مطولاً على أي آية أثناء القراءة واختر "تحديد كعلامة الختمة".',
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 13,
                    height: 1.5,
                  ),
                )
              else ...[
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'سورة ${mark.surahNameArabic} • الآية ${ArabicUtils.toArabicDigits(mark.ayahNumber)}',
                            style: TextStyle(
                              color: theme.glyphColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'ص ${ArabicUtils.toArabicDigits(mark.pageNumber)} • جزء ${ArabicUtils.toArabicDigits(mark.juzNumber)}',
                            style: TextStyle(
                              color: theme.ornamentPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'وقت التسجيل: ${_formatDateTimeArabic(mark.recordedAt)}',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (prevMark != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'الموضع السابق المحفوظ: سورة ${prevMark.surahNameArabic} آية ${ArabicUtils.toArabicDigits(prevMark.ayahNumber)} (ص ${ArabicUtils.toArabicDigits(prevMark.pageNumber)})',
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.ornamentPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.controller.goToPage(
                          mark?.pageNumber ?? 1,
                          highlightVerseKey: mark?.verseKey ?? '1:1',
                        );
                      },
                      icon: const Icon(Icons.menu_book_rounded, size: 18),
                      label: Text(
                        mark == null
                            ? tr('الذهاب لبداية الختمة', 'Go to Start of Khatma')
                            : tr('مواصلة القراءة من العلامة', 'Continue from Mark'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (mark != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.bookmarkRibbon,
                        side: BorderSide(color: theme.bookmarkRibbon),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        await widget.controller
                            .deleteCurrentKhatmaMark(khatma.id);
                      },
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      label: Text(
                        tr('حذف العلامة', 'Remove Mark'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Option to preview live report or complete Khatma
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => showKhatmaReportModal(
                        context,
                        controller: widget.controller,
                        khatma: khatma,
                      ),
                      icon: Icon(
                        Icons.analytics_outlined,
                        size: 18,
                        color: theme.ornamentPrimary,
                      ),
                      label: Text(
                        tr('إحصائيات الختمة حتى الآن', 'Khatma Stats So Far'),
                        style: TextStyle(
                          color: theme.ornamentPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final completed =
                            await widget.controller.completeActiveKhatma();
                        if (!context.mounted || completed == null) return;
                        await showKhatmaReportModal(
                          context,
                          controller: widget.controller,
                          khatma: completed,
                          isJustCompletedCelebration: true,
                        );
                      },
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: Color(0xFF2B8A62),
                      ),
                      label: Text(
                        tr('إتمام الختمة الآن', 'Complete Khatma Now'),
                        style: TextStyle(
                          color: Color(0xFF2B8A62),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.ornamentPrimary,
                  side: BorderSide(
                    color: theme.ornamentPrimary.withValues(alpha: 0.6),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  final created = await showStartNewKhatmaDialog(
                    context,
                    controller: widget.controller,
                  );
                  if (!context.mounted || created == null) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: theme.hudSurface,
                        content: Directionality(
                          textDirection: L10n.dir,
                          child: Text(
                            tr('بدأت ${created.displayTitle} على بركة الله!', '${created.displayTitle} started!'),
                            style: TextStyle(color: theme.hudText),
                          ),
                        ),
                      ),
                    );
                },
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: Text(
                  tr('بدء ختمة جديدة / استكمال ختمة من مصحف آخر', 'Start New / Import from Another Mushaf'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        // 3. Progress History Log
        Text(
          tr('سجل علامات التقدم (${ArabicUtils.toArabicDigits(khatma.logs.length)})', 'Progress Log (${khatma.logs.length})'),
          style: TextStyle(
            color: theme.glyphColor,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (khatma.logs.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.ornamentFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'سيظهر هنا السجل الزمني لكل آية تحددها أثناء تقدمك في الختمة.',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 12.5,
              ),
            ),
          )
        else
          ...khatma.logs.asMap().entries.map((entry) {
            final idx = entry.key;
            final log = entry.value;
            final isLatest = idx == 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isLatest
                    ? theme.ornamentPrimary.withValues(alpha: 0.12)
                    : theme.ornamentFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isLatest ? theme.ornamentPrimary : theme.pageInnerBorder,
                ),
              ),
              child: ListTile(
                dense: true,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.controller.goToPage(
                    log.pageNumber,
                    highlightVerseKey: log.verseKey,
                  );
                },
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: isLatest
                      ? theme.ornamentPrimary
                      : theme.pageBackground,
                  child: Icon(
                    isLatest ? Icons.flag_rounded : Icons.history_rounded,
                    size: 16,
                    color: isLatest ? Colors.white : theme.ornamentPrimary,
                  ),
                ),
                title: Text(
                  'سورة ${log.surahNameArabic} • الآية ${ArabicUtils.toArabicDigits(log.ayahNumber)} (ص ${ArabicUtils.toArabicDigits(log.pageNumber)})',
                  style: TextStyle(
                    color: theme.glyphColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  _formatDateTimeArabic(log.recordedAt),
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 11.5,
                  ),
                ),
                trailing: isLatest
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: theme.ornamentPrimary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tr('الحالية', 'Current'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : null,
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCompletedKhatmasTab(
    BuildContext context,
    List<KhatmaRecord> completedList,
    MushafThemeData theme,
  ) {
    if (completedList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'لا توجد ختمات مكتملة بعد.\nعند إتمام الختمة ستظهر هنا مع التقرير التفصيلي الكامل لكل ختمة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      itemCount: completedList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final khatma = completedList[index];
        final report = widget.controller.generateKhatmaReport(khatma);

        return Container(
          padding: const EdgeInsets.all(14),
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
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF2B8A62),
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'الختمة رقم ${ArabicUtils.toArabicDigits(khatma.serialNumber)}',
                        style: TextStyle(
                          color: theme.glyphColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B8A62).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'المدة: ${_formatDaysLabel(report.durationInDays, report.calendarDaysSpan)}',
                      style: const TextStyle(
                        color: Color(0xFF2B8A62),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'البدء: ${_formatDateTimeArabic(report.startedAt)}\nالإتمام: ${_formatDateTimeArabic(report.completedAt)}',
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.ornamentPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => showKhatmaReportModal(
                        context,
                        controller: widget.controller,
                        khatma: khatma,
                      ),
                      icon: const Icon(Icons.assessment_rounded, size: 18),
                      label: Text(
                        tr('عرض التقرير الكامل', 'View Full Report'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'التراجع عن آخر علامة وإعادة فتح الختمة',
                    icon: Icon(
                      Icons.undo_rounded,
                      color: theme.secondaryTextColor,
                    ),
                    onPressed: () =>
                        widget.controller.deleteCurrentKhatmaMark(khatma.id),
                  ),
                  IconButton(
                    tooltip: 'حذف سجل الختمة',
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: theme.bookmarkRibbon,
                    ),
                    onPressed: () => _confirmAndDeleteKhatma(context, khatma),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmAndDeleteKhatma(
    BuildContext context,
    KhatmaRecord khatma,
  ) async {
    final theme = widget.controller.theme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return Directionality(
          textDirection: L10n.dir,
          child: AlertDialog(
            backgroundColor: theme.pageBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: theme.pageOuterBorder, width: 1.5),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.bookmarkRibbon,
                  size: 26,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تأكيد حذف الختمة',
                    style: TextStyle(
                      color: theme.glyphColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'هل أنت متأكد من حذف «${khatma.displayTitle}» وسجلها بالكامل؟\n\nتنبيه: لا يمكن التراجع عن هذا الإجراء بعد الحذف.',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 14.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: Text(
                  tr('إلغاء', 'Cancel'),
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.bookmarkRibbon,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                label: const Text(
                  'تأكيد الحذف النهائي',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await widget.controller.deleteKhatma(khatma.id);
    }
  }
}

class _KhatmaReportSheet extends StatelessWidget {
  final MushafController controller;
  final KhatmaRecord khatma;
  final KhatmaReport report;
  final bool isCelebration;

  const _KhatmaReportSheet({
    required this.controller,
    required this.khatma,
    required this.report,
    required this.isCelebration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = controller.theme;

    return Directionality(
      textDirection: L10n.dir,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: theme.pageBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: theme.ornamentPrimary, width: 1.8),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Celebration Header
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: theme.ornamentFill,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.ornamentPrimary,
                            width: 1.4,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 108,
                              height: 108,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: theme.ornamentPrimary,
                                  width: 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/images/intro_cover.jpg',
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              khatma.isCompleted
                                  ? 'تقبّل الله طاعتكم! تم إتمام الختمة المباركة'
                                  : 'تقرير تقدم الختمة',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.ornamentPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'تقرير الختمة رقم ${ArabicUtils.toArabicDigits(report.serialNumber)}',
                              style: TextStyle(
                                color: theme.glyphColor,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Dates & Duration Grid
                      _ReportDetailRow(
                        icon: Icons.tag_rounded,
                        label: 'رقم الختمة التسلسلي',
                        value:
                            'الختمة رقم ${ArabicUtils.toArabicDigits(report.serialNumber)}',
                        theme: theme,
                      ),
                      _ReportDetailRow(
                        icon: Icons.timer_outlined,
                        label: 'المدة المستغرقة بالأيام',
                        value: _formatDetailedDuration(
                          report.durationInDays,
                          report.exactDuration,
                          report.calendarDaysSpan,
                        ),
                        theme: theme,
                      ),
                      _ReportDetailRow(
                        icon: Icons.play_circle_outline_rounded,
                        label: 'تاريخ ووقت البدء',
                        value: _formatDateTimeArabic(report.startedAt),
                        theme: theme,
                      ),
                      _ReportDetailRow(
                        icon: Icons.check_circle_outline_rounded,
                        label: khatma.isCompleted
                            ? 'تاريخ ووقت الإتمام'
                            : 'آخر تحديث مسجل',
                        value: _formatDateTimeArabic(report.completedAt),
                        theme: theme,
                      ),

                      const SizedBox(height: 14),
                      Text(
                        'المعدلات اليومية للختمة',
                        style: TextStyle(
                          color: theme.glyphColor,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _MiniStatBox(
                            label: 'معدل الآيات / يوم',
                            value: ArabicUtils.toArabicDigits(
                              report.averageAyahsPerDay.toStringAsFixed(1),
                            ),
                            theme: theme,
                          ),
                          const SizedBox(width: 8),
                          _MiniStatBox(
                            label: 'معدل الصفحات / يوم',
                            value: ArabicUtils.toArabicDigits(
                              report.averagePagesPerDay.toStringAsFixed(1),
                            ),
                            theme: theme,
                          ),
                          const SizedBox(width: 8),
                          _MiniStatBox(
                            label: 'معدل الأجزاء / يوم',
                            value: ArabicUtils.toArabicDigits(
                              report.averageJuzPerDay.toStringAsFixed(2),
                            ),
                            theme: theme,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      // Usual time of day where most readings are done
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.ornamentFill,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: theme.pageInnerBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  color: theme.ornamentPrimary,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'الوقت المعتاد للقراءة في اليوم',
                                  style: TextStyle(
                                    color: theme.glyphColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${report.usualReadingSlot.arabicName} (${report.usualReadingSlot.rangeLabel})',
                              style: TextStyle(
                                color: theme.ornamentPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ساعة الذروة الأكثر قراءة: حوالي ${_formatHourArabic(report.peakReadingHour)}',
                              style: TextStyle(
                                color: theme.secondaryTextColor,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.glyphColor,
                                side: BorderSide(color: theme.ornamentPrimary),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                final textSummary = _buildPlainTextReport(
                                  report,
                                );
                                await Clipboard.setData(
                                  ClipboardData(text: textSummary),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: theme.hudSurface,
                                      content: Directionality(
                                        textDirection: L10n.dir,
                                        child: Text(
                                          'تم نسخ تقرير الختمة إلى الحافظة',
                                          style:
                                              TextStyle(color: theme.hudText),
                                        ),
                                      ),
                                    ),
                                  );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              label: Text(
                                tr('نسخ التقرير', 'Copy Report'),
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
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
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: Text(
                                tr('إغلاق', 'Close'),
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildPlainTextReport(KhatmaReport r) {
    return '''
📖 تقرير الختمة القرآنية رقم ${ArabicUtils.toArabicDigits(r.serialNumber)}
• المدة المستغرقة: ${_formatDetailedDuration(r.durationInDays, r.exactDuration, r.calendarDaysSpan)}
• تاريخ ووقت البدء: ${_formatDateTimeArabic(r.startedAt)}
• تاريخ ووقت الإتمام: ${_formatDateTimeArabic(r.completedAt)}
• معدل الآيات يومياً: ${ArabicUtils.toArabicDigits(r.averageAyahsPerDay.toStringAsFixed(1))} آية/يوم
• معدل الصفحات يومياً: ${ArabicUtils.toArabicDigits(r.averagePagesPerDay.toStringAsFixed(1))} صفحة/يوم
• معدل الأجزاء يومياً: ${ArabicUtils.toArabicDigits(r.averageJuzPerDay.toStringAsFixed(2))} جزء/يوم
• الوقت المعتاد للقراءة: ${r.usualReadingSlot.arabicName} (حوالي ${_formatHourArabic(r.peakReadingHour)})
''';
  }
}

class _ReportDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final MushafThemeData theme;

  const _ReportDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.ornamentFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.pageInnerBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: theme.ornamentPrimary),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: theme.glyphColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  final String label;
  final String value;
  final MushafThemeData theme;

  const _MiniStatBox({
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: theme.pageBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.pageInnerBorder),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: theme.ornamentPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTimeArabic(DateTime dt) {
  final y = ArabicUtils.toArabicDigits(dt.year);
  final m = ArabicUtils.toArabicDigits(dt.month.toString().padLeft(2, '0'));
  final d = ArabicUtils.toArabicDigits(dt.day.toString().padLeft(2, '0'));
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final h = ArabicUtils.toArabicDigits(hour12.toString().padLeft(2, '0'));
  final min = ArabicUtils.toArabicDigits(dt.minute.toString().padLeft(2, '0'));
  final amPm = dt.hour < 12 ? 'ص' : 'م';
  return '$y/$m/$d — $h:$min $amPm';
}

String _formatHourArabic(int hour24) {
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final amPm = hour24 < 12 ? 'صباحاً' : 'مساءً';
  return '${ArabicUtils.toArabicDigits(hour12)}:٠٠ $amPm';
}

String _formatDaysLabel(double exactDays, int calendarDays) {
  if (exactDays < 1.0) {
    return '${ArabicUtils.toArabicDigits(calendarDays)} يوم';
  }
  return '${ArabicUtils.toArabicDigits(exactDays.toStringAsFixed(1))} يوم';
}

String _formatDetailedDuration(
  double exactDays,
  Duration duration,
  int calendarDays,
) {
  final wholeDays = duration.inDays;
  final remHours = duration.inHours % 24;
  final remMins = duration.inMinutes % 60;

  if (wholeDays == 0) {
    if (remHours == 0) {
      return 'يوم واحد (${ArabicUtils.toArabicDigits(remMins)} دقيقة)';
    }
    return 'يوم واحد (${ArabicUtils.toArabicDigits(remHours)} س و ${ArabicUtils.toArabicDigits(remMins)} د)';
  }
  return '${ArabicUtils.toArabicDigits(exactDays.toStringAsFixed(1))} يوم (${ArabicUtils.toArabicDigits(wholeDays)} يوم و ${ArabicUtils.toArabicDigits(remHours)} ساعة)';
}

String _formatDateOnlyArabic(DateTime dt) {
  final y = ArabicUtils.toArabicDigits(dt.year);
  final m = ArabicUtils.toArabicDigits(dt.month.toString().padLeft(2, '0'));
  final d = ArabicUtils.toArabicDigits(dt.day.toString().padLeft(2, '0'));
  return '$y/$m/$d';
}

class _StartupKhatmaPromptDialog extends StatelessWidget {
  final MushafController controller;
  final BuildContext parentContext;

  const _StartupKhatmaPromptDialog({
    required this.controller,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = controller.theme;
    final activeKhatma = controller.activeKhatma;
    final mark = activeKhatma?.currentMark;

    return Directionality(
      textDirection: L10n.dir,
      child: Dialog(
        backgroundColor: theme.pageBackground,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: theme.ornamentPrimary, width: 1.6),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ornamental Intro Cover Header
              Center(
                child: Container(
                  width: 165,
                  height: 165,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: theme.ornamentPrimary,
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/intro_cover.jpg',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                tr('مرحباً بك في مصحف الختمة', 'Welcome to Khatma Mushaf'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.glyphColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                tr('اختر كيف تودّ المتابعة في هذه الجلسة:', 'How would you like to continue this session?'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),

              // Option 1: Continue Active Khatma (only if an active Khatma exists)
              if (activeKhatma != null) ...[
                _StartupOptionCard(
                  icon: Icons.flag_rounded,
                  title: tr('مواصلة الختمة الحالية (${activeKhatma.displayTitle})', 'Continue ${activeKhatma.displayTitle}'),
                  subtitle: mark != null
                      ? 'الموضع الحالي: سورة ${mark.surahNameArabic} • الآية ${ArabicUtils.toArabicDigits(mark.ayahNumber)} (ص ${ArabicUtils.toArabicDigits(mark.pageNumber)})'
                      : 'البداية: سورة الفاتحة • الآية ١ (ص ١)',
                  isPrimary: true,
                  theme: theme,
                  onTap: () {
                    Navigator.of(context).pop();
                    controller.goToPage(
                      mark?.pageNumber ?? 1,
                      highlightVerseKey: mark?.verseKey ?? '1:1',
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],

              // Option 2: Start a New Khatma (or import from real Mushaf / another device)
              _StartupOptionCard(
                icon: Icons.add_task_rounded,
                title: tr('بدء ختمة جديدة', 'Start a New Khatma'),
                subtitle:
                    tr('بدء ختمة من أول المصحف، أو استكمال ختمة بدأتها في مصحف ورقي أو جهاز آخر', 'Start from Al-Fatihah, or continue a Khatma from a physical Mushaf or another device'),
                isPrimary: activeKhatma == null,
                theme: theme,
                onTap: () async {
                  Navigator.of(context).pop();
                  final created = await showStartNewKhatmaDialog(
                    parentContext,
                    controller: controller,
                  );
                  if (!parentContext.mounted || created == null) return;
                  ScaffoldMessenger.of(parentContext)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: theme.hudSurface,
                        content: Directionality(
                          textDirection: L10n.dir,
                          child: Text(
                            tr('بدأت ${created.displayTitle} على بركة الله!', '${created.displayTitle} started!'),
                            style: TextStyle(color: theme.hudText),
                          ),
                        ),
                      ),
                    );
                },
              ),
              const SizedBox(height: 10),

              // Option 3: Free Reading
              _StartupOptionCard(
                icon: Icons.menu_book_rounded,
                title: tr('قراءة حرة', 'Free Reading'),
                subtitle:
                    tr('تصفح المصحف والقراءة الحرة دون الارتباط بعلامة الختمة (ص ${ArabicUtils.toArabicDigits(controller.currentPage)})', 'Browse and read freely without updating Khatma mark (p. ${controller.currentPage})'),
                isPrimary: false,
                theme: theme,
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartupOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPrimary;
  final MushafThemeData theme;
  final VoidCallback onTap;

  const _StartupOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isPrimary,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isPrimary
              ? theme.ornamentPrimary.withValues(alpha: 0.14)
              : theme.ornamentFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPrimary ? theme.ornamentPrimary : theme.pageInnerBorder,
            width: isPrimary ? 1.8 : 1.1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    isPrimary ? theme.ornamentPrimary : theme.pageBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isPrimary
                      ? theme.ornamentPrimary
                      : theme.pageInnerBorder,
                ),
              ),
              child: Icon(
                icon,
                color: isPrimary ? Colors.white : theme.ornamentPrimary,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.glyphColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isPrimary
                  ? theme.ornamentPrimary
                  : theme.secondaryTextColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _StartNewKhatmaDialog extends StatefulWidget {
  final MushafController controller;

  const _StartNewKhatmaDialog({
    required this.controller,
  });

  @override
  State<_StartNewKhatmaDialog> createState() => _StartNewKhatmaDialogState();
}

class _StartNewKhatmaDialogState extends State<_StartNewKhatmaDialog> {
  int _selectedSurahId = 1;
  int _selectedAyahNumber = 1;
  DateTime _selectedStartDate = DateTime.now();
  AyahRecord? _previewAyahRecord;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadAyahPreview();
  }

  Future<void> _loadAyahPreview() async {
    final verseKey = '$_selectedSurahId:$_selectedAyahNumber';
    final record = await widget.controller.getAyahRecord(verseKey);
    if (!mounted) return;
    setState(() {
      _previewAyahRecord = record;
    });
  }

  bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate.isAfter(now) ? now : _selectedStartDate,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: now,
      helpText: 'اختر تاريخ بدء الختمة',
      cancelText: tr('إلغاء', 'Cancel'),
      confirmText: 'تأكيد التاريخ',
      builder: (context, child) {
        return Directionality(
          textDirection: L10n.dir,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedStartDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        now.hour,
        now.minute,
      );
    });
  }

  void _setRelativeDaysAgo(int daysAgo) {
    final now = DateTime.now();
    final target = now.subtract(Duration(days: daysAgo));
    setState(() {
      _selectedStartDate = target;
    });
  }

  Future<void> _confirmStartKhatma() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final verseKey = '$_selectedSurahId:$_selectedAyahNumber';
    final ayahRecord =
        _previewAyahRecord ?? await widget.controller.getAyahRecord(verseKey);

    final created = await widget.controller.startNewKhatma(
      startedAt: _selectedStartDate,
      initialAyah: ayahRecord,
    );

    if (ayahRecord != null) {
      await widget.controller.goToPage(
        ayahRecord.pageNumber,
        highlightVerseKey:
            (_selectedSurahId != 1 || _selectedAyahNumber != 1)
                ? ayahRecord.verseKey
                : null,
      );
    } else {
      await widget.controller.goToPage(1);
    }

    if (!mounted) return;
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.controller.theme;
    final surahs = widget.controller.surahs;
    final currentSurah = widget.controller.getSurahById(_selectedSurahId);
    final maxAyahs = currentSurah?.ayahCount ?? 7;

    final nextSerial = widget.controller.khatmas.isEmpty
        ? 1
        : widget.controller.khatmas
                  .map((k) => k.serialNumber)
                  .reduce((a, b) => a > b ? a : b) +
              1;

    final now = DateTime.now();
    final isToday = _isSameCalendarDay(_selectedStartDate, now);
    final isYesterday = _isSameCalendarDay(
      _selectedStartDate,
      now.subtract(const Duration(days: 1)),
    );
    final is7DaysAgo = _isSameCalendarDay(
      _selectedStartDate,
      now.subtract(const Duration(days: 7)),
    );

    return Directionality(
      textDirection: L10n.dir,
      child: Dialog(
        backgroundColor: theme.pageBackground,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: theme.ornamentPrimary, width: 1.6),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        color: theme.ornamentPrimary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tr('بدء الختمة رقم ${ArabicUtils.toArabicDigits(nextSerial)}', 'Start Khatma #$nextSerial'),
                        style: TextStyle(
                          color: theme.glyphColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded, color: theme.glyphColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Explanatory Banner indicating past date & custom verse capability
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.ornamentPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.ornamentPrimary.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: theme.ornamentPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr('يمكنك البدء من أول المصحف (سورة الفاتحة آية ١) بتاريخ اليوم، أو استكمال ختمة بدأتها في الماضي على مصحف ورقي أو جهاز آخر عبر اختيار تاريخ سابق وتحديد السورة والآية التي وصلت إليها.', 'You can start from Surah Al-Fatihah (1:1) today, or continue a Khatma you started in the past on a physical Mushaf or another device by picking a past start date and the Surah & Ayah you reached.'),
                        style: TextStyle(
                          color: theme.glyphColor,
                          fontSize: 12.5,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section 1: Starting Verse (Surah & Ayah)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: 18,
                        color: theme.ornamentPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tr('بداية الختمة (السورة والآية)', 'Khatma Starting Verse'),
                        style: TextStyle(
                          color: theme.glyphColor,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedSurahId != 1 || _selectedAyahNumber != 1)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedSurahId = 1;
                          _selectedAyahNumber = 1;
                        });
                        _loadAyahPreview();
                      },
                      child: Text(
                        tr('إعادة للفاتحة (١:١)', 'Reset to 1:1'),
                        style: TextStyle(
                          color: theme.ornamentPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.ornamentFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.pageInnerBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        // Surah Dropdown
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('السورة:', 'Surah:'),
                                style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.pageBackground,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: theme.pageInnerBorder,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _selectedSurahId,
                                    isExpanded: true,
                                    dropdownColor: theme.pageBackground,
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: theme.ornamentPrimary,
                                    ),
                                    items: surahs.map((s) {
                                      return DropdownMenuItem<int>(
                                        value: s.id,
                                        child: Text(
                                          tr('${ArabicUtils.toArabicDigits(s.id)}. سورة ${s.nameArabic}', '${s.id}. ${s.nameEnglish}'),
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: theme.glyphColor,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      );
                                    }).toList(growable: false),
                                    onChanged: (newSurahId) {
                                      if (newSurahId == null) return;
                                      setState(() {
                                        _selectedSurahId = newSurahId;
                                        _selectedAyahNumber = 1;
                                      });
                                      _loadAyahPreview();
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Ayah Dropdown
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('الآية:', 'Ayah:'),
                                style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.pageBackground,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: theme.pageInnerBorder,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _selectedAyahNumber.clamp(
                                      1,
                                      maxAyahs,
                                    ),
                                    isExpanded: true,
                                    dropdownColor: theme.pageBackground,
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: theme.ornamentPrimary,
                                    ),
                                    items: List<DropdownMenuItem<int>>.generate(
                                      maxAyahs,
                                      (idx) {
                                        final ayahNum = idx + 1;
                                        return DropdownMenuItem<int>(
                                          value: ayahNum,
                                          child: Text(
                                            tr('الآية ${ArabicUtils.toArabicDigits(ayahNum)}', 'Ayah $ayahNum'),
                                            style: TextStyle(
                                              color: theme.glyphColor,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    onChanged: (newAyah) {
                                      if (newAyah == null) return;
                                      setState(() {
                                        _selectedAyahNumber = newAyah;
                                      });
                                      _loadAyahPreview();
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_previewAyahRecord != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedSurahId == 1 && _selectedAyahNumber == 1
                                ? 'الوضع الافتراضي: بداية المصحف الشريف'
                                : 'سيتم وضع علامة الختمة عند هذه الآية',
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.pageBackground,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: theme.pageInnerBorder),
                            ),
                            child: Text(
                              'ص ${ArabicUtils.toArabicDigits(_previewAyahRecord!.pageNumber)} • جزء ${ArabicUtils.toArabicDigits(_previewAyahRecord!.juzNumber)}',
                              style: TextStyle(
                                color: theme.ornamentPrimary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section 2: Khatma Start Date
              Row(
                children: [
                  Icon(
                    Icons.event_rounded,
                    size: 18,
                    color: theme.ornamentPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tr('تاريخ بدء الختمة', 'Khatma Start Date'),
                    style: TextStyle(
                      color: theme.glyphColor,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickStartDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.ornamentFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.pageInnerBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isToday
                                ? 'اليوم (${_formatDateOnlyArabic(_selectedStartDate)})'
                                : isYesterday
                                    ? 'أمس (${_formatDateOnlyArabic(_selectedStartDate)})'
                                    : 'تاريخ سابق (${_formatDateOnlyArabic(_selectedStartDate)})',
                            style: TextStyle(
                              color: theme.glyphColor,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'اضغط لاختيار تاريخ بدء الختمة من التقويم',
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.pageBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.ornamentPrimary),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 16,
                              color: theme.ornamentPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tr('تغيير', 'Change'),
                              style: TextStyle(
                                color: theme.ornamentPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Quick Date Chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: Text(tr('اليوم', 'Today')),
                    selected: isToday,
                    selectedColor: theme.ornamentPrimary,
                    backgroundColor: theme.ornamentFill,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isToday ? Colors.white : theme.glyphColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => _setRelativeDaysAgo(0),
                  ),
                  ChoiceChip(
                    label: Text(tr('أمس', 'Yesterday')),
                    selected: isYesterday,
                    selectedColor: theme.ornamentPrimary,
                    backgroundColor: theme.ornamentFill,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isYesterday ? Colors.white : theme.glyphColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => _setRelativeDaysAgo(1),
                  ),
                  ChoiceChip(
                    label: Text(tr('قبل أسبوع', '1 Week Ago')),
                    selected: is7DaysAgo,
                    selectedColor: theme.ornamentPrimary,
                    backgroundColor: theme.ornamentFill,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: is7DaysAgo ? Colors.white : theme.glyphColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => _setRelativeDaysAgo(7),
                  ),
                  ActionChip(
                    avatar: Icon(
                      Icons.date_range_rounded,
                      size: 16,
                      color: theme.ornamentPrimary,
                    ),
                    label: Text(
                      tr('تاريخ آخر...', 'Other Date...'),
                      style: TextStyle(
                        color: theme.glyphColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    backgroundColor: theme.ornamentFill,
                    onPressed: _pickStartDate,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Submit & Cancel Buttons
              Row(
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      tr('إلغاء', 'Cancel'),
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.ornamentPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSubmitting ? null : _confirmStartKhatma,
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: Text(
                        tr('بدء الختمة رقم ${ArabicUtils.toArabicDigits(nextSerial)}', 'Start Khatma #$nextSerial'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
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
  }
}


class _DecoratedGreenProgressBar extends StatelessWidget {
  final double progress;
  final MushafThemeData theme;

  const _DecoratedGreenProgressBar({
    required this.progress,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    const greenLight = Color(0xFF34A877);
    const greenMain = Color(0xFF2B8A62);
    const greenDark = Color(0xFF1F7A53);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: progress.clamp(0.02, 1.0)),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Container(
          height: 18,
          decoration: BoxDecoration(
            color: theme.pageBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: greenMain.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fullW = constraints.maxWidth;
                final fillW = (fullW * value).clamp(16.0, fullW);
                return Stack(
                  children: [
                    // 25%, 50%, 75% subtle tick marks on the track
                    for (final frac in const [0.25, 0.50, 0.75])
                      Positioned(
                        left: fullW * frac,
                        top: 3,
                        bottom: 3,
                        child: Container(
                          width: 1,
                          color: theme.secondaryTextColor.withValues(alpha: 0.25),
                        ),
                      ),
                    // Green gradient fill with diagonal stripe decoration
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        width: fillW,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          gradient: const LinearGradient(
                            colors: [greenDark, greenMain, greenLight],
                          ),
                        ),
                        child: CustomPaint(
                          painter: _DiagonalStripePainter(),
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _DiagonalStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 2.0;
    const step = 10.0;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
