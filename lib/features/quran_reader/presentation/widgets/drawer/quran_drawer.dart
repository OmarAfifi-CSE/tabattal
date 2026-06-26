import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../bloc/bookmark/bookmark_bloc.dart';
import '../../bloc/bookmark/bookmark_state.dart';
import '../search/quran_search_screen.dart';
import 'quran_index_view.dart';
import 'quran_full_tafsir_view.dart';
import 'quran_translation_view.dart';
import 'quran_audio_manager_view.dart';
import 'quran_bookmarks_view.dart';

class QuranDrawer extends StatelessWidget {
  final int currentPage;
  final void Function(int pageNumber, {String? verseKey}) onNavigateToPage;

  const QuranDrawer({
    super.key,
    required this.currentPage,
    required this.onNavigateToPage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 200.h, bottom: 200.h),
      child: Drawer(
        width: 280.w,
        backgroundColor: AppColors.surfaceCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.r),
            bottomLeft: Radius.circular(24.r),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildMenuItems(context)),
          ],
        ),
      ),
    );
  }


  Widget _buildMenuItems(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildDrawerItem(
          context,
          icon: Icons.search_rounded,
          title: 'البحث المتقدم',
          subtitle: 'بحث في النصوص والأرقام',
          onTap: () async {
            Navigator.pop(context);
            final result = await Navigator.push<Map<String, dynamic>>(
              context,
              MaterialPageRoute(builder: (_) => const QuranSearchScreen()),
            );
            if (result != null) {
              onNavigateToPage(result['page'], verseKey: result['verseKey']);
            }
          },
        ),
        _divider(),
        _buildDrawerItem(
          context,
          icon: Icons.list_alt_rounded,
          title: 'الفهرس',
          subtitle: 'السور والأجزاء',
          onTap: () async {
            Navigator.pop(context);
            final result = await Navigator.push<dynamic>(
              context,
              MaterialPageRoute(builder: (_) => const QuranIndexView()),
            );
            if (result is Map<String, dynamic>) {
              onNavigateToPage(
                result['page'] as int,
                verseKey: result['verseKey'] as String?,
              );
            } else if (result is int) {
              onNavigateToPage(result);
            }
          },
        ),
        _divider(),
        _buildDrawerItem(
          context,
          icon: Icons.bookmark_rounded,
          title: 'العلامات المرجعية',
          subtitle: 'الآيات المحفوظة',
          badge: _buildBookmarkBadge(),
          onTap: () async {
            Navigator.pop(context);
            final result = await Navigator.push<dynamic>(
              context,
              MaterialPageRoute(builder: (_) => const QuranBookmarksView()),
            );
            if (result is Map<String, dynamic>) {
              onNavigateToPage(
                result['page'] as int,
                verseKey: result['verseKey'] as String?,
              );
            }
          },
        ),
        _divider(),
        _buildDrawerItem(
          context,
          icon: Icons.menu_book_rounded,
          title: 'التفسير الكامل',
          subtitle: 'تفسير لجميع الآيات والسور',
          onTap: () async {
            Navigator.pop(context);
            final result = await Navigator.push<dynamic>(
              context,
              MaterialPageRoute(
                builder: (_) => QuranFullTafsirView(pageNumber: currentPage),
              ),
            );
            if (result is Map<String, dynamic>) {
              onNavigateToPage(
                result['page'] as int,
                verseKey: result['verseKey'] as String?,
              );
            } else if (result is int) {
              onNavigateToPage(result);
            }
          },
        ),
        _divider(),
        _buildDrawerItem(
          context,
          icon: Icons.translate_rounded,
          title: 'الترجمة الإنجليزية',
          subtitle: 'ترجمة لمعاني القرآن',
          onTap: () async {
            Navigator.pop(context);
            final result = await Navigator.push<dynamic>(
              context,
              MaterialPageRoute(
                builder: (_) => QuranTranslationView(pageNumber: currentPage),
              ),
            );
            if (result is Map<String, dynamic>) {
              onNavigateToPage(
                result['page'] as int,
                verseKey: result['verseKey'] as String?,
              );
            } else if (result is int) {
              onNavigateToPage(result);
            }
          },
        ),
        _divider(),
        _buildDrawerItem(
          context,
          icon: Icons.headphones_rounded,
          title: 'مدير الصوتيات',
          subtitle: 'تحميل وإدارة التلاوات',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuranAudioManagerView()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBookmarkBadge() {
    return BlocBuilder<BookmarkBloc, BookmarkState>(
      builder: (context, state) {
        if (state.bookmarkedVerseKeys.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: AppColors.accentGold,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Text(
            '${state.bookmarkedVerseKeys.length}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }


  Widget _divider() => const Divider(
    color: AppColors.divider,
    height: 1,
    indent: 20,
    endIndent: 20,
  );

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? badge,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 13.h),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              width: 46.r,
              height: 46.r,
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: AppColors.accentGold, size: 24.sp),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (badge != null) ...[SizedBox(width: 8.w), badge],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textPrimary.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textPrimary.withValues(alpha: 0.25),
              size: 22.sp,
            ),
          ],
        ),
      ),
    );
  }
}
