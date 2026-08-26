import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../../../settings/presentation/bloc/settings_event.dart';
import '../../../../../settings/presentation/bloc/settings_state.dart';
import '../../../../../quran_bookmarks/presentation/bloc/bookmark_bloc.dart';
import '../../../../../quran_bookmarks/presentation/bloc/bookmark_state.dart';
import '../../../../../quran_search/presentation/screens/desktop/quran_search_screen_desktop.dart';
import '../../../../../quran_audio/presentation/widgets/desktop/quran_audio_manager_view_desktop.dart';
import '../../../../../settings/presentation/widgets/desktop/theme_and_language_sheet_desktop.dart';
import '../../../../../quran_bookmarks/presentation/widgets/desktop/quran_bookmarks_view_desktop.dart';
import 'quran_full_tafsir_view_desktop.dart';
import 'quran_index_view_desktop.dart';
import 'quran_translation_view_desktop.dart';

class QuranDrawerDesktop extends StatelessWidget {
  final int currentPage;
  final void Function(int pageNumber, {String? verseKey}) onNavigateToPage;

  const QuranDrawerDesktop({
    super.key,
    required this.currentPage,
    required this.onNavigateToPage,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    final drawer = Drawer(
      width: isLandscape ? 360.0.w : 380.w,
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
                  const _DesktopDrawerHeader(),
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
                                  fontSize: (isLandscape ? 13.5 : 14.5).sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            SizedBox(height: (isLandscape ? 8.0 : 10.0).h),
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
                  _DesktopDrawerItem(
                    icon: Icons.search_rounded,
                    title: l10n.drawerSearch,
                    subtitle: l10n.drawerSearchSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      final result =
                          await Navigator.push<Map<String, dynamic>>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const QuranSearchScreenDesktop(),
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
                  _DesktopDrawerItem(
                    icon: Icons.list_alt_rounded,
                    title: l10n.drawerIndex,
                    subtitle: l10n.drawerIndexSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QuranIndexViewDesktop(),
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
                  _DesktopDrawerItem(
                    icon: Icons.bookmark_rounded,
                    title: l10n.drawerBookmarks,
                    subtitle: l10n.drawerBookmarksSubtitle,
                    badge: const _DesktopBookmarkBadge(),
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QuranBookmarksViewDesktop(),
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
                  _DesktopDrawerItem(
                    icon: Icons.menu_book_rounded,
                    title: l10n.drawerTafsir,
                    subtitle: l10n.drawerTafsirSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              QuranFullTafsirViewDesktop(pageNumber: currentPage),
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
                  _DesktopDrawerItem(
                    icon: Icons.translate_rounded,
                    title: l10n.drawerTranslation,
                    subtitle: l10n.drawerTranslationSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              QuranTranslationViewDesktop(pageNumber: currentPage),
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
                  _DesktopDrawerItem(
                    icon: Icons.headphones_rounded,
                    title: l10n.drawerAudioManager,
                    subtitle: l10n.drawerAudioManagerSubtitle,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QuranAudioManagerViewDesktop(),
                        ),
                      );
                    },
                  ),
                  _DesktopDrawerItem(
                    iconWidget: ThemeAndLanguageDrawerIconDesktop(
                      size: (isLandscape ? 46.0 : 50.0).r,
                    ),
                    title: l10n.drawerThemeAndLanguage,
                    subtitle: l10n.drawerThemeAndLanguageSubtitle,
                    onTap: () {
                      Navigator.pop(context);
                      showThemeAndLanguageModalDesktop(context);
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

class _DesktopDrawerHeader extends StatelessWidget {
  const _DesktopDrawerHeader();

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return Container(
      width: MediaQuery.sizeOf(context).width,
      padding: isLandscape
          ? EdgeInsets.symmetric(horizontal: 16.0.w, vertical: 16.0.h)
          : EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 16.h),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: AppColors.divider,
            width: isLandscape ? 1.0 : 1.w,
          ),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_stories_rounded,
            color: AppColors.accentGold.withValues(alpha: 0.8),
            size: (isLandscape ? 36.0 : 36.0).sp,
          ),
          SizedBox(height: (isLandscape ? 6.0 : 10.0).h),
          Text(
            '\uFD71 وَاذْكُرِ اسْمَ رَبِّكَ وَتَبَتَّلْ إِلَيْهِ تَبْتِيلًا \uFD70',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'KFGQPC HAFS Uthmanic Script Regular',
              fontSize: (isLandscape ? 23.0 : 23.0).sp,
              height: isLandscape ? 1.45 : 1.8.h,
              fontWeight: FontWeight.normal,
              color: AppColors.textPrimary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopBookmarkBadge extends StatelessWidget {
  const _DesktopBookmarkBadge();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookmarkBloc, BookmarkState>(
      builder: (context, state) {
        if (state.bookmarkedVerseKeys.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 9.0.w, vertical: 3.0.h),
          decoration: BoxDecoration(
            color: AppColors.accentGold,
            borderRadius: BorderRadius.circular(10.0.r),
          ),
          child: Text(
            '${state.bookmarkedVerseKeys.length}',
            style: TextStyle(
              color: AppColors.cardCream,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

class _DesktopDrawerItem extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? badge;

  const _DesktopDrawerItem({
    this.icon,
    this.iconWidget,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: (isLandscape ? 18.0 : 20.0).w,
          vertical: (isLandscape ? 10.0 : 13.0).h,
        ),
        child: Row(
          children: [
            Container(
              width: (isLandscape ? 46.0 : 50.0).r,
              height: (isLandscape ? 46.0 : 50.0).r,
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.0.r),
              ),
              child: iconWidget ??
                  (icon != null
                      ? Icon(
                          icon,
                          color: AppColors.accentGold,
                          size: (isLandscape ? 22.0 : 25.0).r,
                        )
                      : const SizedBox.shrink()),
            ),
            SizedBox(width: (isLandscape ? 12.0 : 14.0).w),
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
                            fontSize: (isLandscape ? 16.0 : 17.5).sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        SizedBox(width: 8.0.w),
                        badge!,
                      ],
                    ],
                  ),
                  SizedBox(height: 2.0.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: (isLandscape ? 12.5 : 13.5).sp,
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
              size: (isLandscape ? 20.0 : 22.0).r,
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
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    final activeTheme = context.watch<SettingsBloc>().state.effectiveMushafTheme;

    final horizontalAlignment = isArabic
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final verticalAlignment = isArabic
        ? Alignment.centerLeft
        : Alignment.centerRight;

    return Container(
      height: (isLandscape ? 42.0 : 46.0).h,
      decoration: BoxDecoration(
        color: AppColors.divider.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular((isLandscape ? 12.0 : 14.0).r),
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
                margin: EdgeInsets.all(3.0.r),
                decoration: BoxDecoration(
                  color: activeTheme.backgroundColor,
                  borderRadius:
                      BorderRadius.circular((isLandscape ? 10.0 : 12.0).r),
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
                            size: (isLandscape ? 18.0 : 20.0).r,
                            color: isHorizontal
                                ? activeTheme.goldColor
                                : AppColors.textPrimary.withValues(alpha: 0.6),
                          ),
                          SizedBox(width: 6.0.w),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              l10n.themeScrollHorizontal,
                              style: TextStyle(
                                fontSize: (isLandscape ? 13.5 : 15.0).sp,
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
                            size: (isLandscape ? 18.0 : 20.0).r,
                            color: !isHorizontal
                                ? activeTheme.goldColor
                                : AppColors.textPrimary.withValues(alpha: 0.6),
                          ),
                          SizedBox(width: 6.0.w),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              l10n.themeScrollVertical,
                              style: TextStyle(
                                fontSize: (isLandscape ? 13.5 : 15.0).sp,
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
