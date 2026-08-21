import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../../core/utils/arabic_text_utils.dart';
import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/constants/quran_metadata.dart';
import '../../../../../../core/theme/app_colors.dart';

class QuranIndexViewMobile extends StatefulWidget {
  final int initialIndex;

  const QuranIndexViewMobile({super.key, this.initialIndex = 0});

  @override
  State<QuranIndexViewMobile> createState() => _QuranIndexViewMobileState();
}

class _QuranIndexViewMobileState extends State<QuranIndexViewMobile>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const List<int> _juzStartPages = [
    1, 22, 42, 62, 82, 102, 122, 142, 162, 182,
    202, 222, 242, 262, 282, 302, 322, 342, 362, 382,
    402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToPage(int pageNumber) => Navigator.pop(context, pageNumber);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCream,
        elevation: 0.r,
        centerTitle: true,
        title: Text(
          l10n.indexTitle,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 22.sp,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
            size: 24.sp,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accentGold,
          unselectedLabelColor: AppColors.textPrimary.withValues(alpha: 0.54),
          indicatorColor: AppColors.accentGold,
          labelStyle: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: l10n.indexSurahsTab),
            Tab(text: l10n.indexJuzsTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SurahListTab(onSelectPage: _navigateToPage),
          _JuzListTab(
            juzStartPages: _juzStartPages,
            onSelectPage: _navigateToPage,
          ),
        ],
      ),
    );
  }
}

class _SurahListTab extends StatefulWidget {
  final ValueChanged<int> onSelectPage;

  const _SurahListTab({required this.onSelectPage});

  @override
  State<_SurahListTab> createState() => _SurahListTabState();
}

class _SurahListTabState extends State<_SurahListTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          16.w,
          8.h,
          16.w,
          MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: 114,
        itemExtent: 66.h,
        itemBuilder: (context, index) {
          final surahNum = index + 1;
          final startPage = QuranMetadata.getStartPageForSurah(surahNum);
          final surahName = isEn
              ? QuranMetadata.getSurahNameEnglish(surahNum)
              : QuranMetadata.getSurahName(surahNum);

          return _IndexSurahTile(
            key: ValueKey('surah_$surahNum'),
            surahNum: surahNum,
            startPage: startPage,
            surahName: surahName,
            isEn: isEn,
            l10n: l10n,
            showDivider: surahNum < 114,
            onTap: () => widget.onSelectPage(startPage),
          );
        },
      ),
    );
  }
}

class _IndexSurahTile extends StatelessWidget {
  final int surahNum;
  final int startPage;
  final String surahName;
  final bool isEn;
  final AppLocalizations l10n;
  final bool showDivider;
  final VoidCallback onTap;

  const _IndexSurahTile({
    super.key,
    required this.surahNum,
    required this.startPage,
    required this.surahName,
    required this.isEn,
    required this.l10n,
    this.showDivider = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12.w,
          vertical: 4.h,
        ),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(color: AppColors.divider, width: 1.h),
                )
              : null,
        ),
        child: Row(
          children: [
            _IndexNumberBadge(label: '$surahNum', filled: true),
            SizedBox(width: 14.w),
            Expanded(
              child: Text(
                l10n.surahListItem(surahName),
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              l10n.pageListItem(
                isEn ? startPage.toString() : startPage.toArabicDigits,
              ),
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textPrimary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JuzListTab extends StatefulWidget {
  final List<int> juzStartPages;
  final ValueChanged<int> onSelectPage;

  const _JuzListTab({
    required this.juzStartPages,
    required this.onSelectPage,
  });

  @override
  State<_JuzListTab> createState() => _JuzListTabState();
}

class _JuzListTabState extends State<_JuzListTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          16.w,
          8.h,
          16.w,
          MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: 30,
        itemExtent: 66.h,
        itemBuilder: (context, index) {
          final juzNum = index + 1;
          final startPage = widget.juzStartPages[index];

          return _IndexJuzTile(
            key: ValueKey('juz_$juzNum'),
            juzNum: juzNum,
            startPage: startPage,
            isEn: isEn,
            l10n: l10n,
            showDivider: juzNum < 30,
            onTap: () => widget.onSelectPage(startPage),
          );
        },
      ),
    );
  }
}

class _IndexJuzTile extends StatelessWidget {
  final int juzNum;
  final int startPage;
  final bool isEn;
  final AppLocalizations l10n;
  final bool showDivider;
  final VoidCallback onTap;

  const _IndexJuzTile({
    super.key,
    required this.juzNum,
    required this.startPage,
    required this.isEn,
    required this.l10n,
    this.showDivider = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12.w,
          vertical: 4.h,
        ),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(color: AppColors.divider, width: 1.h),
                )
              : null,
        ),
        child: Row(
          children: [
            _IndexNumberBadge(label: '$juzNum', filled: false),
            SizedBox(width: 14.w),
            Expanded(
              child: Text(
                l10n.juzListItem(
                  isEn ? juzNum.toString() : QuranMetadata.getJuzName(juzNum),
                ),
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              l10n.pageListItem(
                isEn ? startPage.toString() : startPage.toArabicDigits,
              ),
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textPrimary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndexNumberBadge extends StatelessWidget {
  final String label;
  final bool filled;

  const _IndexNumberBadge({required this.label, this.filled = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.r,
      height: 40.r,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: filled ? 0.12 : 0.1),
        shape: BoxShape.circle,
        border: filled
            ? Border.all(
                color: AppColors.accentGold.withValues(alpha: 0.4),
                width: 1.w,
              )
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.bold,
          color: AppColors.accentGold,
        ),
      ),
    );
  }
}
