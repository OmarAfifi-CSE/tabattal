import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/bloc/locale/locale_cubit.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/mushaf_theme.dart';
import '../../../../../settings/bloc/settings_bloc.dart';
import '../../../../../settings/bloc/settings_event.dart';
import '../../../../../settings/bloc/settings_state.dart';
import '../../../../bloc/bookmark/bookmark_bloc.dart';
import '../../../../bloc/bookmark/bookmark_state.dart';
import '../../../pages/search/mobile/quran_search_screen_mobile.dart';
import '../quran_audio_manager_view.dart';
import '../quran_full_tafsir_view.dart';
import '../quran_translation_view.dart';
import 'quran_bookmarks_view_mobile.dart';
import 'quran_index_view_mobile.dart';

class QuranDrawerMobile extends StatelessWidget {
  final int currentPage;
  final void Function(int pageNumber, {String? verseKey}) onNavigateToPage;

  const QuranDrawerMobile({
    super.key,
    required this.currentPage,
    required this.onNavigateToPage,
  });

  void _showThemePicker(BuildContext context) {
    final bloc = context.read<SettingsBloc>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0.r,
      builder: (ctx) =>
          BlocProvider.value(value: bloc, child: const _ThemePickerSheet()),
    );
  }

  void _showLanguagePicker(BuildContext context, AppLocalizations l10n) {
    final cubit = context.read<LocaleCubit>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardCream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => BlocProvider.value(
        value: cubit,
        child: _LanguagePickerSheet(l10n: l10n),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final drawer = Drawer(
      width: 300.w,
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
                  const _MobileDrawerHeader(),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
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
                                  fontSize: 14.sp,
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
                  _MobileDrawerItem(
                    icon: Icons.search_rounded,
                    title: l10n.drawerSearch,
                    subtitle: l10n.drawerSearchSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      final result =
                          await Navigator.push<Map<String, dynamic>>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const QuranSearchScreenMobile(),
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
                  _MobileDrawerItem(
                    icon: Icons.list_alt_rounded,
                    title: l10n.drawerIndex,
                    subtitle: l10n.drawerIndexSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QuranIndexViewMobile(),
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
                  _MobileDrawerItem(
                    icon: Icons.bookmark_rounded,
                    title: l10n.drawerBookmarks,
                    subtitle: l10n.drawerBookmarksSubtitle,
                    badge: const _MobileBookmarkBadge(),
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QuranBookmarksViewMobile(),
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
                  _MobileDrawerItem(
                    icon: Icons.menu_book_rounded,
                    title: l10n.drawerTafsir,
                    subtitle: l10n.drawerTafsirSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              QuranFullTafsirView(pageNumber: currentPage),
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
                  _MobileDrawerItem(
                    icon: Icons.translate_rounded,
                    title: l10n.drawerTranslation,
                    subtitle: l10n.drawerTranslationSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              QuranTranslationView(pageNumber: currentPage),
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
                  _MobileDrawerItem(
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
                  _MobileDrawerItem(
                    icon: Icons.palette_rounded,
                    title: l10n.themeAppearanceTitle,
                    subtitle: l10n.themeAppearanceSubtitle,
                    onTap: () {
                      Navigator.pop(context);
                      _showThemePicker(context);
                    },
                  ),
                  _MobileDrawerItem(
                    icon: Icons.language_rounded,
                    title: l10n.drawerLanguage,
                    subtitle: l10n.drawerLanguageSubtitle,
                    onTap: () {
                      Navigator.pop(context);
                      _showLanguagePicker(context, l10n);
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
      padding: EdgeInsets.only(top: 50.h, bottom: 50.h),
      child: drawer,
    );
  }
}

class _MobileDrawerHeader extends StatelessWidget {
  const _MobileDrawerHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.sizeOf(context).width,
      padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 14.h),
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
            size: 32.sp,
          ),
          SizedBox(height: 10.h),
          Text(
            '\uFD71 وَاذْكُرِ اسْمَ رَبِّكَ وَتَبَتَّلْ إِلَيْهِ تَبْتِيلًا \uFD70',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'KFGQPC HAFS Uthmanic Script Regular',
              fontSize: 20.sp,
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

class _MobileBookmarkBadge extends StatelessWidget {
  const _MobileBookmarkBadge();

  @override
  Widget build(BuildContext context) {
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
              color: AppColors.cardCream,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

class _MobileDrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? badge;

  const _MobileDrawerItem({
    required this.icon,
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
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: AppColors.accentGold, size: 22.sp),
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
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (badge != null) ...[SizedBox(width: 8.w), badge!],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textPrimary.withValues(alpha: 0.45),
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
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Language Picker Sheet ────────────────────────────────────────────────────

class _LanguagePickerSheet extends StatelessWidget {
  final AppLocalizations l10n;
  const _LanguagePickerSheet({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) {
        final isArabic = locale.languageCode == 'ar';
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24.w,
            16.h,
            24.w,
            math.max(32.h, MediaQuery.paddingOf(context).bottom),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 20.h),
                decoration: BoxDecoration(
                  color: AppColors.accentGold,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Text(
                l10n.languagePickerTitle,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 20.h),
              _LanguageOption(
                label: l10n.languageArabic,
                isSelected: isArabic,
                onTap: () {
                  context.read<LocaleCubit>().setLocale('ar');
                  Navigator.pop(context);
                },
              ),
              SizedBox(height: 12.h),
              _LanguageOption(
                label: l10n.languageEnglish,
                isSelected: !isArabic,
                onTap: () {
                  context.read<LocaleCubit>().setLocale('en');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentGold.withValues(alpha: 0.12)
              : AppColors.surfaceCream,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isSelected ? AppColors.accentGold : AppColors.borderLight,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected
                  ? AppColors.accentGold
                  : AppColors.textPrimary.withValues(alpha: 0.3),
              size: 22.sp,
            ),
            SizedBox(width: 14.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? AppColors.accentGold
                    : AppColors.textPrimary,
              ),
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
      height: 44.h,
      decoration: BoxDecoration(
        color: AppColors.divider.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12.r),
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
                  borderRadius: BorderRadius.circular(8.r),
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
                            size: 18.sp,
                            color: isHorizontal
                                ? activeTheme.goldColor
                                : AppColors.textPrimary.withValues(alpha: 0.6),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            l10n.themeScrollHorizontal,
                            style: TextStyle(
                              fontSize: 14.sp,
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
                            size: 18.sp,
                            color: !isHorizontal
                                ? activeTheme.goldColor
                                : AppColors.textPrimary.withValues(alpha: 0.6),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            l10n.themeScrollVertical,
                            style: TextStyle(
                              fontSize: 14.sp,
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

// ─── Theme Picker Sheet ───────────────────────────────────────────────────────

class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet();

  String _getThemeName(BuildContext context, String id) {
    final l10n = AppLocalizations.of(context)!;
    return switch (id) {
      'cream' => l10n.themeCream,
      'white' => l10n.themeWhite,
      'mint' => l10n.themeMint,
      'iceBlue' => l10n.themeIceBlue,
      'parchment' => l10n.themeParchment,
      'roseGold' => l10n.themeRoseGold,
      'slate' => l10n.themeSlate,
      'olive' => l10n.themeOlive,
      'emerald' => l10n.themeEmerald,
      'burgundy' => l10n.themeBurgundy,
      'dark' => l10n.themeDark,
      _ => id,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        final isDark = state.themeMode == ThemeMode.dark;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardCream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24.w,
              16.h,
              24.w,
              math.max(32.h, MediaQuery.paddingOf(context).bottom),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: 20.h),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                Text(
                  l10n.themeAppearanceTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 24.h),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCream,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isDark
                                  ? Icons.dark_mode_rounded
                                  : Icons.light_mode_rounded,
                              color: state.effectiveMushafTheme.goldColor,
                            ),
                            SizedBox(width: 12.w),
                            Text(
                              l10n.themeDarkMode,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: isDark,
                          thumbColor:
                              WidgetStateProperty.resolveWith<Color>((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return state.effectiveMushafTheme.goldColor;
                                }
                                return state.effectiveMushafTheme.textColor
                                    .withValues(alpha: 0.75);
                              }),
                          trackColor:
                              WidgetStateProperty.resolveWith<Color>((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return state.effectiveMushafTheme.goldColor
                                      .withValues(alpha: 0.45);
                                }
                                return state
                                    .effectiveMushafTheme
                                    .innerBorderColor;
                              }),
                          trackOutlineColor:
                              WidgetStateProperty.resolveWith<Color>((states) {
                                return state.effectiveMushafTheme.goldColor
                                    .withValues(alpha: 0.35);
                              }),
                          onChanged: (val) {
                            context.read<SettingsBloc>().add(
                              ToggleThemeMode(
                                val ? ThemeMode.dark : ThemeMode.light,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    l10n.themeMushafColor,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 12.h,
                      crossAxisSpacing: 6.w,
                      childAspectRatio: 0.80,
                    ),
                    itemCount: MushafTheme.values.length,
                    itemBuilder: (context, index) {
                      final theme = MushafTheme.values[index];
                      final isSelected = state.mushafTheme.id == theme.id;
                      return GestureDetector(
                        onTap: () {
                          context.read<SettingsBloc>().add(
                            ChangeMushafTheme(theme.id),
                          );
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56.w,
                              height: 56.w,
                              decoration: BoxDecoration(
                                color: theme.backgroundColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? theme.goldColor
                                      : AppColors.borderLight,
                                  width: isSelected ? 2.5 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.05,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check_rounded,
                                      color: theme.goldColor,
                                      size: 20.sp,
                                    )
                                  : null,
                            ),
                            SizedBox(height: 6.h),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _getThemeName(context, theme.id),
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: isSelected
                                      ? theme.goldColor
                                      : AppColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
