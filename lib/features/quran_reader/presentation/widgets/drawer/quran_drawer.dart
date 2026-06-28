import 'package:flutter/foundation.dart' show kIsWeb;
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
    final drawer = Drawer(
      width: kIsWeb ? 300 : 280.w,
      backgroundColor: AppColors.surfaceCream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(kIsWeb ? 24 : 24.r),
          bottomLeft: Radius.circular(kIsWeb ? 24 : 24.r),
        ),
      ),
      child: SafeArea(
        child: _buildMenuItems(context),
      ),
    );
    // On mobile, float the drawer with vertical padding for the visual effect.
    // On web, fill the full height to avoid overflow on smaller viewports.
    if (kIsWeb) return drawer;
    return Padding(
      padding: EdgeInsets.only(top: 200.h, bottom: 200.h),
      child: drawer,
    );
  }


  Widget _buildMenuItems(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
        if (!kIsWeb) ...[
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
        ],
      ),
    );
  }

  Widget _buildBookmarkBadge() {
    return BlocBuilder<BookmarkBloc, BookmarkState>(
      builder: (context, state) {
        if (state.bookmarkedVerseKeys.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.accentGold,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${state.bookmarkedVerseKeys.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.accentGold, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (badge != null) ...[const SizedBox(width: 8), badge],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textPrimary.withValues(alpha: 0.25),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
