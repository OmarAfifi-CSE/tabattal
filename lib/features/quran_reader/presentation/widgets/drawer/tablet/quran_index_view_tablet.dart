import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../../core/utils/arabic_text_utils.dart';
import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/constants/quran_metadata.dart';
import '../../../../../../core/theme/app_colors.dart';

class QuranIndexViewTablet extends StatefulWidget {
  final int initialIndex;

  const QuranIndexViewTablet({super.key, this.initialIndex = 0});

  @override
  State<QuranIndexViewTablet> createState() => _QuranIndexViewTabletState();
}

class _QuranIndexViewTabletState extends State<QuranIndexViewTablet>
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
            fontSize: 24.sp,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
            size: 26.sp,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accentGold,
          unselectedLabelColor: AppColors.textPrimary.withValues(alpha: 0.54),
          indicatorColor: AppColors.accentGold,
          labelStyle: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
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
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: isLandscape
          ? GridView.builder(
              padding: EdgeInsets.fromLTRB(
                16.w,
                16.h,
                16.w,
                16.h + MediaQuery.paddingOf(context).bottom,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 4.2,
                mainAxisSpacing: 8.h,
                crossAxisSpacing: 16.w,
              ),
              itemCount: 114,
              itemBuilder: (context, index) {
                final surahNum = index + 1;
                final startPage = QuranMetadata.getStartPageForSurah(surahNum);
                final surahName = isEn
                    ? QuranMetadata.getSurahNameEnglish(surahNum)
                    : QuranMetadata.getSurahName(surahNum);

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCream,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.2),
                    ),
                  ),
                  child: _IndexSurahTile(
                    surahNum: surahNum,
                    startPage: startPage,
                    surahName: surahName,
                    isEn: isEn,
                    l10n: l10n,
                    onTap: () => widget.onSelectPage(startPage),
                  ),
                );
              },
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                16.w,
                16.h,
                16.w,
                16.h + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: 114,
              separatorBuilder: (context, index) =>
                  Divider(color: AppColors.divider, height: 1.h),
              itemBuilder: (context, index) {
                final surahNum = index + 1;
                final startPage = QuranMetadata.getStartPageForSurah(surahNum);
                final surahName = isEn
                    ? QuranMetadata.getSurahNameEnglish(surahNum)
                    : QuranMetadata.getSurahName(surahNum);

                return _IndexSurahTile(
                  surahNum: surahNum,
                  startPage: startPage,
                  surahName: surahName,
                  isEn: isEn,
                  l10n: l10n,
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
  final VoidCallback onTap;

  const _IndexSurahTile({
    required this.surahNum,
    required this.startPage,
    required this.surahName,
    required this.isEn,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(
        horizontal: (isLandscape ? 12.0 : 16.0).w,
        vertical: (isLandscape ? 4.0 : 8.0).h,
      ),
      leading: _IndexNumberBadge(label: '$surahNum', filled: true),
      title: Text(
        l10n.surahListItem(surahName),
        style: TextStyle(
          fontSize: (isLandscape ? 15.5 : 21.0).sp,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Text(
        l10n.pageListItem(
          isEn ? startPage.toString() : startPage.toArabicDigits,
        ),
        style: TextStyle(
          fontSize: (isLandscape ? 13.0 : 16.5).sp,
          color: AppColors.textPrimary.withValues(alpha: 0.6),
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
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: isLandscape
          ? GridView.builder(
              padding: EdgeInsets.fromLTRB(
                16.w,
                16.h,
                16.w,
                16.h + MediaQuery.paddingOf(context).bottom,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 4.2,
                mainAxisSpacing: 8.h,
                crossAxisSpacing: 16.w,
              ),
              itemCount: 30,
              itemBuilder: (context, index) {
                final juzNum = index + 1;
                final startPage = widget.juzStartPages[index];

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCream,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.2),
                    ),
                  ),
                  child: _IndexJuzTile(
                    juzNum: juzNum,
                    startPage: startPage,
                    isEn: isEn,
                    l10n: l10n,
                    onTap: () => widget.onSelectPage(startPage),
                  ),
                );
              },
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                16.w,
                16.h,
                16.w,
                16.h + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: 30,
              separatorBuilder: (context, index) =>
                  Divider(color: AppColors.divider, height: 1.h),
              itemBuilder: (context, index) {
                final juzNum = index + 1;
                final startPage = widget.juzStartPages[index];

                return _IndexJuzTile(
                  juzNum: juzNum,
                  startPage: startPage,
                  isEn: isEn,
                  l10n: l10n,
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
  final VoidCallback onTap;

  const _IndexJuzTile({
    required this.juzNum,
    required this.startPage,
    required this.isEn,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(
        horizontal: (isLandscape ? 12.0 : 16.0).w,
        vertical: (isLandscape ? 4.0 : 8.0).h,
      ),
      leading: _IndexNumberBadge(label: '$juzNum', filled: false),
      title: Text(
        l10n.juzListItem(
          isEn ? juzNum.toString() : QuranMetadata.getJuzName(juzNum),
        ),
        style: TextStyle(
          fontSize: (isLandscape ? 15.5 : 21.0).sp,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Text(
        l10n.pageListItem(
          isEn ? startPage.toString() : startPage.toArabicDigits,
        ),
        style: TextStyle(
          fontSize: (isLandscape ? 13.0 : 16.5).sp,
          color: AppColors.textPrimary.withValues(alpha: 0.6),
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
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return Container(
      width: (isLandscape ? 34.0 : 46.0).r,
      height: (isLandscape ? 34.0 : 46.0).r,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: filled ? 0.12 : 0.1),
        shape: BoxShape.circle,
        border: filled
            ? Border.all(
                color: AppColors.accentGold.withValues(alpha: 0.4),
                width: (isLandscape ? 0.8 : 1.0).w,
              )
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: (isLandscape ? 13.0 : 16.0).sp,
          fontWeight: FontWeight.bold,
          color: AppColors.accentGold,
        ),
      ),
    );
  }
}
