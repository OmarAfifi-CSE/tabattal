import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/utils/arabic_text_utils.dart';
import '../../../../../quran_reader/domain/repositories/quran_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../../core/constants/quran_metadata.dart';
class QuranIndexViewTablet extends StatefulWidget {
  final int initialIndex;

  const QuranIndexViewTablet({super.key, this.initialIndex = 0});

  @override
  State<QuranIndexViewTablet> createState() => _QuranIndexViewTabletState();
}

class _QuranIndexViewTabletState extends State<QuranIndexViewTablet> with SingleTickerProviderStateMixin {
  late final QuranRepository _repository;
  late TabController _tabController;

  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> _surahIndex = [];

  // Approximate start pages for Juz (Madani Mushaf standard)
  static const List<int> _juzStartPages = [
    1, 22, 42, 62, 82, 102, 122, 142, 162, 182,
    202, 222, 242, 262, 282, 302, 322, 342, 362, 382,
    402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
  ];

  @override
  void initState() {
    super.initState();
    _repository = context.read<QuranRepository>();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialIndex);
    _loadSurahIndex();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSurahIndex() async {
    final result = await _repository.getSurahsIndex();
    result.fold(
      (failure) {
        if (mounted) setState(() { _isLoading = false; _hasError = true; });
      },
      (index) {
        if (mounted) setState(() { _surahIndex = index; _isLoading = false; });
      },
    );
  }

  void _navigateToPage(int pageNumber) => Navigator.pop(context, pageNumber);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final content = Scaffold(
      backgroundColor: AppColors.surfaceCream,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCream,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l10n.indexTitle,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 22.sp),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 24.sp),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accentGold,
          unselectedLabelColor: AppColors.textPrimary.withValues(alpha: 0.54),
          indicatorColor: AppColors.accentGold,
          labelStyle: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          tabs: [Tab(text: l10n.indexSurahsTab), Tab(text: l10n.indexJuzsTab)],
        ),
      ),
      body: _buildBody(l10n),
    );
    return content;
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: AppColors.accentGold));
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48.sp),
            SizedBox(height: 12.h),
            Text(l10n.indexLoadError, style: TextStyle(color: Colors.red, fontSize: 16.sp)),
            SizedBox(height: 12.h),
            ElevatedButton(onPressed: _loadSurahIndex, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    return TabBarView(
      controller: _tabController,
      children: [_buildSurahList(l10n), _buildJuzList(l10n)],
    );
  }

  Widget _buildSurahList(AppLocalizations l10n) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: ListView.separated(
        padding: EdgeInsets.all(16.r),
        itemCount: _surahIndex.length,
        separatorBuilder: (context, index) => Divider(color: AppColors.divider, height: 1),
        itemBuilder: (context, index) {
          final surahData = _surahIndex[index];
          final surahNum = surahData['surah'] as int;
          final startPage = surahData['start_page'] as int;

          return ListTile(
            onTap: () => _navigateToPage(startPage),
            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            leading: _buildCircleNumberBadge('$surahNum'),
            title: Text(
              l10n.surahListItem(isEn ? QuranMetadata.getSurahNameEnglish(surahNum) : QuranMetadata.getSurahName(surahNum)),
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            trailing: Text(
              l10n.pageListItem(isEn ? startPage.toString() : startPage.toArabicDigits),
              style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary.withValues(alpha: 0.6)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildJuzList(AppLocalizations l10n) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: ListView.separated(
        padding: EdgeInsets.all(16.r),
        itemCount: 30,
        separatorBuilder: (context, index) => Divider(color: AppColors.divider, height: 1),
        itemBuilder: (context, index) {
          final juzNum = index + 1;
          final startPage = _juzStartPages[index];

          return ListTile(
            onTap: () => _navigateToPage(startPage),
            leading: _buildCircleNumberBadge('$juzNum', filled: false),
            title: Text(
              l10n.juzListItem(isEn ? juzNum.toString() : QuranMetadata.getJuzName(juzNum)),
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            trailing: Text(
              l10n.pageListItem(isEn ? startPage.toString() : startPage.toArabicDigits),
              style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary.withValues(alpha: 0.6)),
            ),
          );
        },
      ),
    );
  }

  /// Shared circular badge used for both surah and juz numbers.
  Widget _buildCircleNumberBadge(String label, {bool filled = true}) {
    return Container(
      width: 40.r,
      height: 40.r,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: filled ? 0.12 : 0.1),
        shape: BoxShape.circle,
        border: filled ? Border.all(color: AppColors.accentGold.withValues(alpha: 0.4), width: 1) : null,
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppColors.accentGold),
      ),
    );
  }
}
