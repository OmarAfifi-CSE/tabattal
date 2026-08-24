import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../settings/bloc/settings_bloc.dart';
import '../../../../../settings/bloc/settings_event.dart';
import '../../../../../settings/bloc/settings_state.dart';
import '../../../../bloc/bookmark/bookmark_bloc.dart';
import '../../../../bloc/bookmark/bookmark_state.dart';
import '../../../pages/search/tablet/quran_search_screen_tablet.dart';
import '../quran_audio_manager_view.dart';
import '../theme_and_language_sheet.dart';
import 'quran_bookmarks_view_tablet.dart';
import 'quran_full_tafsir_view_tablet.dart';
import 'quran_index_view_tablet.dart';
import 'quran_translation_view_tablet.dart';

class QuranDrawerTablet extends StatelessWidget {
  final int currentPage;
  final void Function(int pageNumber, {String? verseKey}) onNavigateToPage;

  const QuranDrawerTablet({
    super.key,
    required this.currentPage,
    required this.onNavigateToPage,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final drawer = Drawer(
      width: 380.w,
      backgroundColor: AppColors.surfaceCream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          bottomLeft: Radius.circular(24.r),
        ),
      ),
      child: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const _TabletDrawerHeader(),
                  Padding(
                    padding: EdgeInsets.fromLTRB(22.w, 18.h, 22.w, 10.h),
                    child: BlocBuilder<SettingsBloc, SettingsState>(
                      builder: (context, state) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text(
                                l10n.themeScrollDirection,
                                style: TextStyle(
                                  fontSize: 16.5.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            SizedBox(height: 12.h),
                            ScrollDirectionToggle(
                              scrollDirection: state.scrollDirection,
                              onChanged: (val) => context
                                  .read<SettingsBloc>()
                                  .add(ChangeScrollDirection(val)),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _TabletDrawerItem(
                    icon: Icons.search_rounded,
                    title: l10n.drawerSearch,
                    subtitle: l10n.drawerSearchSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      final result =
                          await Navigator.push<Map<String, dynamic>>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const QuranSearchScreenTablet(),
                            ),
                          );
                      if (result != null) {
                        onNavigateToPage(
                          result['page'],
                          verseKey: result['verseKey'],
                        );
                      }
                    },
                  ),
                  _TabletDrawerItem(
                    icon: Icons.list_alt_rounded,
                    title: l10n.drawerIndex,
                    subtitle: l10n.drawerIndexSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QuranIndexViewTablet(),
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
                  _TabletDrawerItem(
                    icon: Icons.bookmark_rounded,
                    title: l10n.drawerBookmarks,
                    subtitle: l10n.drawerBookmarksSubtitle,
                    badge: const _TabletBookmarkBadge(),
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QuranBookmarksViewTablet(),
                        ),
                      );
                      if (result is Map<String, dynamic>) {
                        onNavigateToPage(
                          result['page'] as int,
                          verseKey: result['verseKey'] as String?,
                        );
                      }
                    },
                  ),
                  _TabletDrawerItem(
                    icon: Icons.menu_book_rounded,
                    title: l10n.drawerTafsir,
                    subtitle: l10n.drawerTafsirSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              QuranFullTafsirViewTablet(pageNumber: currentPage),
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
                  _TabletDrawerItem(
                    icon: Icons.translate_rounded,
                    title: l10n.drawerTranslation,
                    subtitle: l10n.drawerTranslationSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              QuranTranslationViewTablet(pageNumber: currentPage),
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
                  _TabletDrawerItem(
                    icon: Icons.headphones_rounded,
                    title: l10n.drawerAudioManager,
                    subtitle: l10n.drawerAudioManagerSubtitle,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QuranAudioManagerView(),
                        ),
                      );
                    },
                  ),
                  _TabletDrawerItem(
                    iconWidget: ThemeAndLanguageDrawerIcon(size: 52.w),
                    title: l10n.drawerThemeAndLanguage,
                    subtitle: l10n.drawerThemeAndLanguageSubtitle,
                    onTap: () {
                      Navigator.pop(context);
                      showThemeAndLanguageModal(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: 40.h, bottom: 40.h),
      child: drawer,
    );
  }
}

class _TabletDrawerHeader extends StatelessWidget {
  const _TabletDrawerHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.sizeOf(context).width,
      padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 16.h),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1.w),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_stories_rounded,
            color: AppColors.accentGold.withValues(alpha: 0.8),
            size: 36.sp,
          ),
          SizedBox(height: 10.h),
          Text(
            '\uFD71 وَاذْكُرِ اسْمَ رَبِّكَ وَتَبَتَّلْ إِلَيْهِ تَبْتِيلًا \uFD70',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'KFGQPC HAFS Uthmanic Script Regular',
              fontSize: 23.sp,
              height: 1.8.h,
              fontWeight: FontWeight.normal,
              color: AppColors.textPrimary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabletBookmarkBadge extends StatelessWidget {
  const _TabletBookmarkBadge();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookmarkBloc, BookmarkState>(
      builder: (context, state) {
        if (state.bookmarkedVerseKeys.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: AppColors.accentGold,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Text(
            '${state.bookmarkedVerseKeys.length}',
            style: TextStyle(
              color: AppColors.cardCream,
              fontSize: 13.5.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

class _TabletDrawerItem extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? badge;

  const _TabletDrawerItem({
    this.icon,
    this.iconWidget,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 13.h),
        child: Row(
          children: [
            Container(
              width: 52.w,
              height: 52.w,
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: iconWidget ??
                  (icon != null
                      ? Icon(icon, color: AppColors.accentGold, size: 26.sp)
                      : const SizedBox.shrink()),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 18.5.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (badge != null) ...[SizedBox(width: 8.w), badge!],
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textPrimary.withValues(alpha: 0.55),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              color: AppColors.textPrimary.withValues(alpha: 0.25),
              size: 24.sp,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Scroll Direction Toggle ──────────────────────────────────────────────────

class ScrollDirectionToggle extends StatelessWidget {
  final Axis scrollDirection;
  final ValueChanged<Axis> onChanged;

  const ScrollDirectionToggle({
    super.key,
    required this.scrollDirection,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isHorizontal = scrollDirection == Axis.horizontal;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final activeTheme = context.watch<SettingsBloc>().state.effectiveMushafTheme;

    final horizontalAlignment = isArabic
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final verticalAlignment = isArabic
        ? Alignment.centerLeft
        : Alignment.centerRight;

    return Container(
      height: 52.h,
      decoration: BoxDecoration(
        color: AppColors.divider.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            alignment: isHorizontal ? horizontalAlignment : verticalAlignment,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                margin: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  color: activeTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(10.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Directionality(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(Axis.horizontal),
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.swap_horiz_rounded,
                            size: 22.sp,
                            color: isHorizontal
                                ? activeTheme.goldColor
                                : AppColors.textPrimary.withValues(alpha: 0.6),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            l10n.themeScrollHorizontal,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: isHorizontal
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isHorizontal
                                  ? activeTheme.goldColor
                                  : AppColors.textPrimary.withValues(
                                      alpha: 0.6,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(Axis.vertical),
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.swap_vert_rounded,
                            size: 22.sp,
                            color: !isHorizontal
                                ? activeTheme.goldColor
                                : AppColors.textPrimary.withValues(alpha: 0.6),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            l10n.themeScrollVertical,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: !isHorizontal
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: !isHorizontal
                                  ? activeTheme.goldColor
                                  : AppColors.textPrimary.withValues(
                                      alpha: 0.6,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
