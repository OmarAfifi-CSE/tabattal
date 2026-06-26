import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../bloc/bookmark/bookmark_bloc.dart';
import '../../bloc/bookmark/bookmark_event.dart';
import '../../bloc/bookmark/bookmark_state.dart';
import '../../../../quran_reader/domain/repositories/quran_repository.dart';
import '../../../../../core/utils/verse_ref.dart';
import '../../../../../core/utils/arabic_text_utils.dart';
import '../quran_metadata.dart';

class QuranBookmarksView extends StatelessWidget {
  const QuranBookmarksView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCream,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'العلامات المرجعية',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 22.sp),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 24.sp),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<BookmarkBloc, BookmarkState>(
        builder: (context, state) {
          if (state.bookmarkedVerseKeys.isEmpty) return _buildEmptyState();

          return ListView.separated(
            padding: EdgeInsets.all(16.r),
            itemCount: state.bookmarkedVerseKeys.length,
            separatorBuilder: (context, index) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final verseKey = state.bookmarkedVerseKeys[index];
              final verseRef = VerseRef.fromKey(verseKey);

              return _BookmarkCard(
                verseKey: verseKey,
                surahName: QuranMetadata.getSurahName(verseRef.surah),
                surahNum: verseRef.surah,
                ayahNum: verseRef.ayah,
                onNavigate: (page) => Navigator.pop(context, {'page': page, 'verseKey': verseKey}),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border_rounded, size: 72.sp, color: AppColors.accentGold.withValues(alpha: 0.4)),
          SizedBox(height: 16.h),
          Text(
            'لا توجد علامات مرجعية',
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          SizedBox(height: 8.h),
          Text(
            'اضغط على أي آية لإضافتها كعلامة مرجعية',
            style: TextStyle(fontSize: 15.sp, color: AppColors.textPrimary.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bookmark Card
// ---------------------------------------------------------------------------

class _BookmarkCard extends StatefulWidget {
  final String verseKey;
  final String surahName;
  final int surahNum;
  final int ayahNum;
  final void Function(int page) onNavigate;

  const _BookmarkCard({
    required this.verseKey,
    required this.surahName,
    required this.surahNum,
    required this.ayahNum,
    required this.onNavigate,
  });

  @override
  State<_BookmarkCard> createState() => _BookmarkCardState();
}

class _BookmarkCardState extends State<_BookmarkCard> {
  bool _isLoadingPage = true;
  bool _hasError = false;
  int _surahStartPage = 1;

  @override
  void initState() {
    super.initState();
    _loadVersePage();
  }

  Future<void> _loadVersePage() async {
    final result = await context.read<QuranRepository>().getPageForVerse(widget.verseKey);
    result.fold(
      (failure) {
        if (mounted) setState(() { _isLoadingPage = false; _hasError = true; });
      },
      (page) {
        if (mounted) {
          setState(() {
            _isLoadingPage = false;
            _surahStartPage = page;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        onTap: (_isLoadingPage || _hasError) ? null : () => widget.onNavigate(_surahStartPage),
        leading: Container(
          width: 48.r,
          height: 48.r,
          decoration: BoxDecoration(
            color: AppColors.accentGold.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.bookmark_rounded, color: AppColors.accentGold, size: 24.sp),
        ),
        title: Text(
          'سورة ${widget.surahName}',
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 2.h),
          child: Text(
            'الآية ${widget.ayahNum.toArabicDigits}  •  صفحة ${_hasError ? '—' : _surahStartPage.toArabicDigits}',
            style: TextStyle(fontSize: 13.sp, color: AppColors.textPrimary.withValues(alpha: 0.55)),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoadingPage)
              SizedBox(
                width: 20.r,
                height: 20.r,
                child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentGold),
              )
            else
              Icon(
                _hasError ? Icons.error_outline : Icons.arrow_back_ios_rounded,
                size: 16.sp,
                color: _hasError ? Colors.red.withValues(alpha: 0.6) : AppColors.textPrimary.withValues(alpha: 0.3),
              ),
            SizedBox(width: 4.w),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Colors.red.withValues(alpha: 0.65), size: 22.sp),
              onPressed: () => context.read<BookmarkBloc>().add(ToggleBookmark(widget.verseKey)),
            ),
          ],
        ),
      ),
    );
  }
}
