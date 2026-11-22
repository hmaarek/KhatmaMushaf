import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../state/mushaf_controller.dart';
import '../theme/mushaf_theme.dart';

/// Displays the first-run 3-screen introduction flow for Khatma Mushaf.
Future<void> showOnboardingIntro(
  BuildContext context, {
  required MushafController controller,
}) async {
  await Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => OnboardingScreen(controller: controller),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class OnboardingScreen extends StatefulWidget {
  final MushafController controller;

  const OnboardingScreen({super.key, required this.controller});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  static const int _totalPages = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finish() {
    widget.controller.markOnboardingCompleted();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _nextPage() {
    if (_currentIndex < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _prevPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final theme = widget.controller.theme;
        final isLast = _currentIndex == _totalPages - 1;

        return PopScope(
          canPop: false,
          child: Directionality(
            textDirection: L10n.dir,
            child: Scaffold(
              backgroundColor: theme.pageBackground,
              body: SafeArea(
                child: Column(
                  children: [
                    // Top Bar: Step badge & Skip button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: theme.ornamentFill,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: theme.pageInnerBorder),
                            ),
                            child: Text(
                              '${L10n.n(_currentIndex + 1)} / ${L10n.n(_totalPages)}',
                              style: TextStyle(
                                color: theme.ornamentPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _finish,
                            child: Text(
                              tr('تخطي', 'Skip', 'چھوڑیں'),
                              style: TextStyle(
                                color: theme.secondaryTextColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Simple decorated calligraphic app title visible on every page
                    _buildDecoratedAppTitle(theme),

                    // Main 3-screen PageView
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() => _currentIndex = index);
                        },
                        children: [
                          _buildVirtuePage(theme),
                          _buildKhatmaFeaturesPage(theme),
                          _buildNafalPrayerPage(theme),
                        ],
                      ),
                    ),

                    // Bottom Navigation & Page Indicators
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_totalPages, (idx) {
                              final active = idx == _currentIndex;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: active ? 26 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: active
                                      ? (isLast
                                            ? const Color(0xFF2B8A62)
                                            : theme.ornamentPrimary)
                                      : theme.pageInnerBorder,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              if (_currentIndex > 0) ...[
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: theme.secondaryTextColor,
                                    side: BorderSide(
                                      color: theme.pageInnerBorder,
                                      width: 1.4,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: _prevPage,
                                  child: Text(
                                    tr('السابق', 'Back', 'واپس'),
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isLast
                                        ? const Color(0xFF2B8A62)
                                        : theme.ornamentPrimary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: _nextPage,
                                  icon: Icon(
                                    isLast
                                        ? Icons.menu_book_rounded
                                        : Icons.arrow_forward_rounded,
                                    size: 20,
                                  ),
                                  label: Text(
                                    isLast
                                        ? tr(
                                            'ابدأ التلاوة الآن',
                                            'Start Reading Now',
                                            'ابھی تلاوت شروع کریں',
                                          )
                                        : tr('التالي', 'Next', 'اگلا'),
                                    style: const TextStyle(
                                      fontSize: 16,
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Simple decorated calligraphic app name shown on every onboarding page.
  Widget _buildDecoratedAppTitle(MushafThemeData theme) {
    Widget flourish({required bool leftSide}) {
      return Expanded(
        child: Row(
          mainAxisAlignment: leftSide
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!leftSide) ...[
              Transform.rotate(
                angle: 0.7854,
                child: Container(
                  width: 5.5,
                  height: 5.5,
                  color: theme.ornamentPrimary.withValues(alpha: 0.80),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Container(
                height: 1.2,
                constraints: const BoxConstraints(maxWidth: 64),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: leftSide
                        ? [
                            theme.ornamentPrimary.withValues(alpha: 0.0),
                            theme.ornamentPrimary.withValues(alpha: 0.70),
                          ]
                        : [
                            theme.ornamentPrimary.withValues(alpha: 0.70),
                            theme.ornamentPrimary.withValues(alpha: 0.0),
                          ],
                  ),
                ),
              ),
            ),
            if (leftSide) ...[
              const SizedBox(width: 6),
              Transform.rotate(
                angle: 0.7854,
                child: Container(
                  width: 5.5,
                  height: 5.5,
                  color: theme.ornamentPrimary.withValues(alpha: 0.80),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                flourish(leftSide: true),
                const SizedBox(width: 12),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    'مُصْحَفُ الْخَتْمَةِ',
                    style: TextStyle(
                      fontFamily: 'IndoPak',
                      fontSize: 25,
                      height: 1.25,
                      color: theme.ornamentPrimary,
                      shadows: [
                        Shadow(
                          color: theme.ornamentSecondary.withValues(
                            alpha: 0.35,
                          ),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                flourish(leftSide: false),
              ],
            ),
          ),
          if (L10n.isEn)
            Text(
              'Khatma Mushaf',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  /// Screen 1: Importance of regular Quran recitation & great Thawab of Khatm al-Quran
  Widget _buildVirtuePage(MushafThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.ornamentFill,
                border: Border.all(color: theme.ornamentPrimary, width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: theme.ornamentPrimary.withValues(alpha: 0.16),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                size: 40,
                color: theme.ornamentPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(
              'فضل المداومة على القرآن وعظيم ثواب الختم',
              'The Virtue of Daily Quran & Completing a Khatma',
              'روزانہ تلاوتِ قرآن اور ختمِ قرآن کا عظیم ثواب',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.glyphColor,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'المداومة على تلاوة كتاب الله ولو بوردٍ يسيرٍ كل يوم تُنير القلب، وتجلب الطمأنينة، وترفع الدرجات.',
              'Reciting the Book of Allah regularly — even a small portion each day — illuminates the heart, brings tranquility, and elevates your ranks.',
              'قرآنِ کریم کی روزانہ باقاعدگی سے تلاوت — چاہے تھوڑا ہی حصہ کیوں نہ ہو — دل کو منور کرتی ہے، سکون بخشتی ہے اور درجات بلند کرتی ہے۔',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Supporting Ayah 1: Surah Fatir 35:29-30
          _buildAyahQuoteCard(
            theme: theme,
            arabicVerse:
                '﴿إِنَّ الَّذِينَ يَتْلُونَ كِتَابَ اللَّهِ وَأَقَامُوا الصَّلَاةَ وَأَنفَقُوا مِمَّا رَزَقْنَاهُمْ سِرًّا وَعَلَانِيَةً يَرْجُونَ تِجَارَةً لَّن تَبُورَ ۝ لِيُوَفِّيَهُمْ أُجُورَهُمْ وَيَزِيدَهُم مِّن فَضْلِهِ إِنَّهُ غَفُورٌ شَكُورٌ﴾',
            translation: L10n.isEn
                ? '“Indeed, those who recite the Book of Allah and establish prayer and spend out of what We have provided for them secretly and publicly expect a commerce that will never perish — that He may give them in full their rewards and increase for them of His bounty.”'
                : L10n.isUr
                ? '«بے شک جو لوگ اللہ کی کتاب کی تلاوت کرتے ہیں، نماز قائم کرتے ہیں اور ہمارے دیے ہوئے رزق میں سے پوشیدہ و علانیہ خرچ کرتے ہیں، وہ ایسی تجارت کے امیدوار ہیں جس میں کبھی خسارہ نہ ہوگا؛ تاکہ اللہ انہیں ان کا پورا اجر دے اور اپنے فضل سے مزید عطا فرمائے۔»'
                : null,
            reference: tr(
              'سورة فاطر • الآيتان ٢٩ – ٣٠',
              'Surah Fatir • 35:29–30',
              'سورۃ فاطر • آیات ٢٩ – ٣٠',
            ),
          ),
          const SizedBox(height: 10),

          // Supporting Ayah 2: Surah Al-Muzzammil 73:20
          _buildAyahQuoteCard(
            theme: theme,
            arabicVerse: '﴿فَاقْرَءُوا مَا تَيَسَّرَ مِنَ الْقُرْآنِ﴾',
            translation: L10n.isEn
                ? '“So recite what is easy [for you] of the Quran.”'
                : L10n.isUr
                ? '«پس قرآن میں سے جتنا آسانی سے ہو سکے پڑھو۔»'
                : null,
            reference: tr(
              'سورة المزمل • الآية ٢٠',
              'Surah Al-Muzzammil • 73:20',
              'سورۃ المزمل • آیت ٢٠',
            ),
          ),
          const SizedBox(height: 12),

          // Khatma Thawab Highlight Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2B8A62).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF2B8A62).withValues(alpha: 0.45),
                width: 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFF2B8A62),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(
                          'أجرٌ عظيم في كل ختمة!',
                          'Immense Reward in Every Khatma!',
                          'ہر ختمِ قرآن پر بے پناہ ثواب!',
                        ),
                        style: TextStyle(
                          color: theme.glyphColor,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(
                          'بكل حرفٍ من كتاب الله حسنة، والحسنة بعشر أمثالها — فإتمام ختمة واحدة للقرآن الكريم (أكثر من ٣٢٤ ألف حرف) يُرجى به أكثر من ٣ ملايين و٢٠٠ ألف حسنة، والله يضاعف لمن يشاء.',
                          'Every single letter recited earns a good deed multiplied tenfold — finishing one full Khatma (over 324,000 letters) brings an estimated reward of more than 3.2 million Hasanat, and Allah multiplies for whom He wills.',
                          'قرآن کے ہر ایک حرف پر ایک نیکی اور ہر نیکی دس گنا ملتی ہے — ایک مکمل ختمِ قرآن (٣ لاکھ ٢٤ ہزار سے زائد حروف) پر ٣٢ لاکھ سے زیادہ نیکیوں کی امید ہے، اور اللہ جس کے لیے چاہے مزید بڑھا دیتا ہے۔',
                        ),
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 12.8,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAyahQuoteCard({
    required MushafThemeData theme,
    required String arabicVerse,
    String? translation,
    required String reference,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: theme.ornamentFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.ornamentPrimary.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              arabicVerse,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.glyphColor,
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                height: 1.75,
              ),
            ),
          ),
          if (translation != null) ...[
            const SizedBox(height: 6),
            Text(
              translation,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 12.5,
                fontStyle: L10n.isEn ? FontStyle.italic : FontStyle.normal,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            reference,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.ornamentPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// Screen 2: Features built specifically to facilitate completing a Khatma
  Widget _buildKhatmaFeaturesPage(MushafThemeData theme) {
    final features = <({IconData icon, Color accent, String title, String desc})>[
      (
        icon: Icons.flag_rounded,
        accent: const Color(0xFF2B8A62),
        title: tr(
          'تتبع ذكي ودقيق لتقدم الختمة',
          'Accurate Khatma Progress & Finish Estimate',
          'ختمہ کی درست پیش رفت اور تکمیل کا اندازہ',
        ),
        desc: tr(
          'اضغط مطوّلاً على أي آية لتحديد موضعك، وتابع نسبتك الحقيقية بعدد الحروف المقروءة مع تاريخ الإتمام المتوقع (هجري وميلادي) وتقدير الحسنات.',
          'Long-press any ayah to mark your reading place and track true progress by letters read, estimated Hijri & Gregorian finish date, and estimated Hasanat.',
          'کسی بھی آیت پر دیر تک دبا کر اپنا مقام محفوظ کریں، پڑھے گئے حروف کے مطابق اصل فیصد، تکمیل کی متوقع تاریخ (ہجری و عیسوی) اور متوقع ثواب دیکھیں۔',
        ),
      ),
      (
        icon: Icons.notifications_active_rounded,
        accent: theme.ornamentPrimary,
        title: tr(
          'تذكير لطيف للحفاظ على وردك اليومي',
          'Gentle 24-Hour Daily Reading Reminder',
          'روزانہ تلاوت کی ٢٤ گھنٹے بعد نرم یاددہانی',
        ),
        desc: tr(
          'إن مرّت ٢٤ ساعة دون تحديث علامة ختمتك، يذكّرك التطبيق بلطف لتعود إلى وردك القرآني ولا تنقطع عن الختم.',
          'If 24 hours pass without updating your Khatma mark, a gentle reminder encourages you to return to your daily reading.',
          'اگر ٢٤ گھنٹے تک آپ ختمہ کا نشان اپ ڈیٹ نہ کریں تو ایپ نرمی سے یاددہانی کراتی ہے تاکہ آپ کا سلسلہ برقرار رہے۔',
        ),
      ),
      (
        icon: Icons.menu_book_rounded,
        accent: const Color(0xFF3A7BD5),
        title: tr(
          'مصحف المدينة ١٤٤١هـ وخط النستعليق',
          'Authentic 1441H Madinah Mushaf & Indo-Pak',
          'مدینہ مصحف ١٤٤١ھ اور برصغیر نستعلیق خط',
        ),
        desc: tr(
          'خط عثمان طه الواضح بصفحات كاملة بدون تشتيت، مع خيارات تكبير الخط والخط العريض و٣ مظاهر مريحة للعين منها الوضع الداكن.',
          'Crystal-clear Uthman Taha calligraphy with Large/Extra-Large text, Bold font toggle, optional page border, and 3 eye-friendly themes including AMOLED Dark.',
          'عثمان طہٰ کا نہایت واضح خط، بڑے فونٹ، موٹے خط کا انتخاب، اور آنکھوں کے لیے آرام دہ ٣ تھیمز بشمول ڈارک موڈ۔',
        ),
      ),
      (
        icon: Icons.record_voice_over_rounded,
        accent: const Color(0xFFD98A2B),
        title: tr(
          'نطق الكلمات وتلاوة الآيات والتفسير',
          'Word Pronunciation, Recitation & Tafsir',
          'الفاظ کا تلفظ، تلاوت اور تفسیر',
        ),
        desc: tr(
          'انقر مرتين على أي كلمة لسماع نطقها الصحيح، والمس رقم الآية للاستماع إليها كاملة بصوت قارئك المفضل، أو افتح المعاني والتفسير فوراً.',
          'Double-tap any word to hear it pronounced, tap any ayah number to listen with your preferred reciter, or open meanings & Tafsir anytime.',
          'کسی بھی لفظ پر دو بار ٹیپ کر کے تلفظ سنیں، آیت کے نمبر پر ٹیپ کر کے اپنے پسندیدہ قاری کی آواز میں تلاوت سنیں، یا فوراً معنی و تفسیر دیکھیں۔',
        ),
      ),
      (
        icon: Icons.emoji_events_rounded,
        accent: const Color(0xFF2B8A62),
        title: tr(
          'سجل الختمات وتقارير الإتمام',
          'Multiple Khatmas & Completion Reports',
          'متعدد ختمے اور تکمیل کی رپورٹس',
        ),
        desc: tr(
          'يحتفظ التطبيق بتاريخ كل ختمة أتممتها مع تقرير شامل لإنجازك، ويتيح لك بدء ختمة جديدة بلمسة واحدة.',
          'Keep an archive of every Khatma you complete with full milestone stats, and begin your next Khatma in one tap.',
          'آپ کے ہر مکمل ختمہ کا ریکارڈ اور تفصیلی رپورٹ محفوظ رہتی ہے، اور ایک ٹیپ سے نیا ختمہ شروع کر سکتے ہیں۔',
        ),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2B8A62).withValues(alpha: 0.12),
                border: Border.all(color: const Color(0xFF2B8A62), width: 1.8),
              ),
              child: const Icon(
                Icons.fact_check_rounded,
                size: 36,
                color: Color(0xFF2B8A62),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            tr(
              'مزايا صُمِّمت خصيصاً لإعانتك على الختم',
              'Built Specifically to Facilitate Your Khatma',
              'آپ کا ختمِ قرآن آسان بنانے کے لیے خصوصی سہولیات',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.glyphColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.32,
            ),
          ),
          const SizedBox(height: 14),
          for (final item in features) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: theme.ornamentFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.pageInnerBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: item.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, color: item.accent, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            color: theme.glyphColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.desc,
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 12.2,
                            fontWeight: FontWeight.w600,
                            height: 1.42,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }

  /// Screen 3: Vertical Scrolling while standing in Nafal (optional) prayers
  Widget _buildNafalPrayerPage(MushafThemeData theme) {
    final verticalOn = widget.controller.verticalScroll;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Serene illustration of a worshiper standing in Nafal prayer holding phone
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFAF6EC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.ornamentPrimary.withValues(alpha: 0.55),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: theme.isDark ? 0.35 : 0.08,
                  ),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.asset(
                'assets/images/onboarding_nafal_prayer.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Icon(
                    Icons.swap_vert_circle_rounded,
                    size: 72,
                    color: theme.ornamentPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(
              'القراءة المريحة في صلاة النافلة وقيام الليل',
              'Effortless Reading in Nafal & Night Prayers',
              'نفل اور قیام اللیل کی نماز میں آسان تلاوت',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.glyphColor,
              fontSize: 20.5,
              fontWeight: FontWeight.w900,
              height: 1.32,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tr(
              'أثناء صلاة النافلة وقيام الليل والتهجد، يمكنك الإمساك بالهاتف بيدٍ واحدة والقراءة بسلاسة عبر «التمرير العمودي للصفحات» مع المحاذاة التلقائية عند أعلى كل صفحة — حركة إبهام واحدة خفيفة لأعلى تنقلك بسكينة إلى الصفحة التالية دون تشويش على خشوعك، مع إبقاء الشاشة مضاءة طوال الصلاة.',
              'During Nafal (optional) prayers, Qiyam al-Layl, and Tahajjud, hold your phone comfortably in one hand and read smoothly with Vertical Page Scrolling and automatic page-top snap — a single gentle thumb swipe upward glides seamlessly to the next page without breaking your Khushu\', while keeping the screen awake throughout your prayer.',
              'نفل نماز، تہجد اور قیام اللیل کے دوران آپ ایک ہاتھ میں موبائل پکڑ کر «عمودی اسکرولنگ» کی سہولت کے ساتھ نہایت آسانی سے تلاوت کر سکتے ہیں۔ انگوٹھے کے ایک ہلکے اشارے سے اگلا صفحہ خودکار انداز میں درست جگہ پر آ جاتا ہے، خشوع میں خلل نہیں پڑتا اور پوری نماز کے دوران اسکرین روشن رہتی ہے۔',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),

          // Instant optional toggle so the user can turn on Vertical Scroll right here
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: verticalOn
                  ? const Color(0xFF2B8A62).withValues(alpha: 0.12)
                  : theme.ornamentFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: verticalOn
                    ? const Color(0xFF2B8A62)
                    : theme.pageInnerBorder,
                width: verticalOn ? 1.5 : 1.0,
              ),
            ),
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: const Color(0xFF2B8A62),
              secondary: Icon(
                Icons.swap_vert_rounded,
                color: verticalOn
                    ? const Color(0xFF2B8A62)
                    : theme.ornamentPrimary,
              ),
              value: verticalOn,
              onChanged: widget.controller.setVerticalScroll,
              title: Text(
                tr(
                  'تفعيل التمرير العمودي الآن',
                  'Enable Vertical Scrolling now',
                  'عمودی اسکرولنگ ابھی فعال کریں',
                ),
                style: TextStyle(
                  color: theme.glyphColor,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                tr(
                  'يمكنك التبديل بين التمرير العمودي وقلب الصفحات في أي وقت من الإعدادات',
                  'You can switch between vertical scrolling and page flipping anytime in Settings',
                  'آپ کسی بھی وقت ترتیبات سے عمودی اسکرولنگ اور صفحات پلٹنے میں تبدیلی کر سکتے ہیں',
                ),
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: 11.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
