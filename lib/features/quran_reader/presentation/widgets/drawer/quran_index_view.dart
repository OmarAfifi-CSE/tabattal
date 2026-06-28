import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../../core/utils/arabic_text_utils.dart';
import '../../../../quran_reader/domain/repositories/quran_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../quran_metadata.dart';

class QuranIndexView extends StatefulWidget {
  const QuranIndexView({super.key});

  @override
  State<QuranIndexView> createState() => _QuranIndexViewState();
}

class _QuranIndexViewState extends State<QuranIndexView> with SingleTickerProviderStateMixin {
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
    _tabController = TabController(length: 2, vsync: this);
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
    final content = Scaffold(
      backgroundColor: AppColors.surfaceCream,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCream,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'الفهرس',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 22.sp),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 24.sp),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accentGold,
          unselectedLabelColor: Colors.black54,
          indicatorColor: AppColors.accentGold,
          labelStyle: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          tabs: const [Tab(text: 'السور'), Tab(text: 'الأجزاء')],
        ),
      ),
      body: _buildBody(),
    );
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: content,
          ),
        ),
      );
    }
    return content;
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48.sp),
            SizedBox(height: 12.h),
            Text('فشل تحميل الفهرس', style: TextStyle(color: Colors.red, fontSize: 16.sp)),
            SizedBox(height: 12.h),
            ElevatedButton(onPressed: _loadSurahIndex, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }
    return TabBarView(
      controller: _tabController,
      children: [_buildSurahList(), _buildJuzList()],
    );
  }

  Widget _buildSurahList() {
    return ListView.separated(
      padding: EdgeInsets.all(16.r),
      itemCount: _surahIndex.length,
      separatorBuilder: (context, index) => const Divider(color: AppColors.divider, height: 1),
      itemBuilder: (context, index) {
        final surahData = _surahIndex[index];
        final surahNum = surahData['surah'] as int;
        final startPage = surahData['start_page'] as int;

        return ListTile(
          onTap: () => _navigateToPage(startPage),
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          leading: _buildCircleNumberBadge('$surahNum'),
          title: Text(
            'سورة ${QuranMetadata.getSurahName(surahNum)}',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          trailing: Text(
            'صفحة ${startPage.toArabicDigits}',
            style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary.withValues(alpha: 0.6)),
          ),
        );
      },
    );
  }

  Widget _buildJuzList() {
    return ListView.separated(
      padding: EdgeInsets.all(16.r),
      itemCount: 30,
      separatorBuilder: (context, index) => const Divider(color: AppColors.divider, height: 1),
      itemBuilder: (context, index) {
        final juzNum = index + 1;
        final startPage = _juzStartPages[index];

        return ListTile(
          onTap: () => _navigateToPage(startPage),
          leading: _buildCircleNumberBadge('$juzNum', filled: false),
          title: Text(
            'الجزء ${QuranMetadata.getJuzName(juzNum)}',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          trailing: Text(
            'صفحة ${startPage.toArabicDigits}',
            style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary.withValues(alpha: 0.6)),
          ),
        );
      },
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
