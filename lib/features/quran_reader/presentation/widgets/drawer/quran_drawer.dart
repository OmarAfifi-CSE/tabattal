import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/bloc/locale/locale_cubit.dart';
import '../../bloc/bookmark/bookmark_bloc.dart';
import '../../bloc/bookmark/bookmark_state.dart';
import '../search/quran_search_screen.dart';
import 'quran_index_view.dart';
import 'quran_full_tafsir_view.dart';
import 'quran_translation_view.dart';
import 'quran_audio_manager_view.dart';
import 'quran_bookmarks_view.dart';
import '../../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../../settings/presentation/bloc/settings_event.dart';
import '../../../../settings/presentation/bloc/settings_state.dart';
import '../../../../../core/theme/mushaf_theme.dart';

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
      width: kIsWeb ? 320 : 300.w,
      backgroundColor: AppColors.surfaceCream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(kIsWeb ? 24 : 24.r),
          bottomLeft: Radius.circular(kIsWeb ? 24 : 24.r),
        ),
      ),
      child: _buildMenuItems(context),
    );
    // On mobile, float the drawer with vertical padding for the visual effect.
    // On web, fill the full height to avoid overflow on smaller viewports.
    if (kIsWeb) return drawer;
    return Padding(
      padding: EdgeInsets.only(top: 50.h, bottom: 50.h),
      child: drawer,
    );
  }


  Widget _buildMenuItems(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildHeader(context),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
                  child: BlocBuilder<SettingsBloc, SettingsState>(
                    builder: (context, state) {
                      final l10n = AppLocalizations.of(context)!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              l10n.themeScrollDirection,
                              style: TextStyle(
                                fontSize: kIsWeb ? 14 : 14.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          SizedBox(height: kIsWeb ? 12 : 12.h),
                          ScrollDirectionToggle(
                            scrollDirection: state.scrollDirection,
                            onChanged: (val) => context.read<SettingsBloc>().add(ChangeScrollDirection(val)),
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
                      _buildDrawerItem(
            context,
                      icon: Icons.search_rounded,
                      title: l10n.drawerSearch,
                      subtitle: l10n.drawerSearchSubtitle,
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
            
                    _buildDrawerItem(
                      context,
                      icon: Icons.list_alt_rounded,
                      title: l10n.drawerIndex,
                      subtitle: l10n.drawerIndexSubtitle,
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
            
                    _buildDrawerItem(
                      context,
                      icon: Icons.bookmark_rounded,
                      title: l10n.drawerBookmarks,
                      subtitle: l10n.drawerBookmarksSubtitle,
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
            
                    _buildDrawerItem(
                      context,
                      icon: Icons.menu_book_rounded,
                      title: l10n.drawerTafsir,
                      subtitle: l10n.drawerTafsirSubtitle,
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
            
                    _buildDrawerItem(
                      context,
                      icon: Icons.translate_rounded,
                      title: l10n.drawerTranslation,
                      subtitle: l10n.drawerTranslationSubtitle,
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
            
                      _buildDrawerItem(
            context,
            icon: Icons.headphones_rounded,
            title: l10n.drawerAudioManager,
            subtitle: l10n.drawerAudioManagerSubtitle,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuranAudioManagerView()),
              );
            },
                      ),
                    ],
            
                    _buildDrawerItem(
                      context,
                      icon: Icons.palette_rounded,
                      title: l10n.themeAppearanceTitle,
                      subtitle: l10n.themeAppearanceSubtitle,
                      onTap: () {
            Navigator.pop(context);
            _showThemePicker(context);
                      },
                    ),
            
                    _buildDrawerItem(
                      context,
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 32.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_stories_rounded, color: AppColors.accentGold.withValues(alpha: 0.8), size: 32.sp),
          SizedBox(height: 16.h),
          Text(
            '\uFD71 وَاذْكُرِ اسْمَ رَبِّكَ وَتَبَتَّلْ إِلَيْهِ تَبْتِيلًا \uFD70',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'KFGQPC HAFS Uthmanic Script Regular',
              fontSize: 20.sp,
              height: 1.8,
              fontWeight: FontWeight.normal,
              color: AppColors.textPrimary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
    final bloc = context.read<SettingsBloc>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => BlocProvider.value(
        value: bloc,
        child: const _ThemePickerSheet(),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, AppLocalizations l10n) {
    final cubit = context.read<LocaleCubit>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardCream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kIsWeb ? 24 : 24.r)),
      ),
      builder: (ctx) => BlocProvider.value(
        value: cubit,
        child: _LanguagePickerSheet(l10n: l10n),
      ),
    );
  }

  Widget _buildBookmarkBadge() {
    return BlocBuilder<BookmarkBloc, BookmarkState>(
      builder: (context, state) {
        if (state.bookmarkedVerseKeys.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 8 : 8.w, vertical: kIsWeb ? 2 : 2.h),
          decoration: BoxDecoration(
            color: AppColors.accentGold,
            borderRadius: BorderRadius.circular(kIsWeb ? 10 : 10.r),
          ),
          child: Text(
            '${state.bookmarkedVerseKeys.length}',
            style: TextStyle(
              color: AppColors.cardCream,
              fontSize: kIsWeb ? 12 : 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }


  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? badge,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 20 : 20.w, vertical: kIsWeb ? 12 : 12.h),
        child: Row(
          children: [
            Container(
              width: kIsWeb ? 44 : 44.w,
              height: kIsWeb ? 44 : 44.w,
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.r),
              ),
              child: Icon(icon, color: AppColors.accentGold, size: kIsWeb ? 22 : 22.sp),
            ),
            SizedBox(width: kIsWeb ? 14 : 14.w),
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
                            fontSize: kIsWeb ? 15 : 15.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (badge != null) ...[SizedBox(width: kIsWeb ? 8 : 8.w), badge],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: kIsWeb ? 12 : 12.sp,
                      color: AppColors.textPrimary.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              color: AppColors.textPrimary.withValues(alpha: 0.25),
              size: kIsWeb ? 20 : 20.sp,
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
          padding: EdgeInsets.fromLTRB(kIsWeb ? 24 : 24.w, kIsWeb ? 16 : 16.h, kIsWeb ? 24 : 24.w, kIsWeb ? 32 : 32.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: kIsWeb ? 40 : 40.w,
                height: kIsWeb ? 4 : 4.h,
                margin: EdgeInsets.only(bottom: kIsWeb ? 20 : 20.h),
                decoration: BoxDecoration(
                  color: AppColors.accentGold,
                  borderRadius: BorderRadius.circular(kIsWeb ? 2 : 2.r),
                ),
              ),
              Text(
                l10n.languagePickerTitle,
                style: TextStyle(
                  fontSize: kIsWeb ? 18 : 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: kIsWeb ? 20 : 20.h),
              _LanguageOption(
                label: l10n.languageArabic,
                isSelected: isArabic,
                onTap: () {
                  context.read<LocaleCubit>().setLocale('ar');
                  Navigator.pop(context);
                },
              ),
              SizedBox(height: kIsWeb ? 12 : 12.h),
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
        padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 20 : 20.w, vertical: kIsWeb ? 14 : 14.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentGold.withValues(alpha: 0.12) : AppColors.surfaceCream,
          borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.r),
          border: Border.all(
            color: isSelected ? AppColors.accentGold : AppColors.borderLight,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppColors.accentGold : AppColors.textPrimary.withValues(alpha: 0.3),
              size: kIsWeb ? 22 : 22.sp,
            ),
            SizedBox(width: kIsWeb ? 14 : 14.w),
            Text(
              label,
              style: TextStyle(
                fontSize: kIsWeb ? 16 : 16.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.accentGold : AppColors.textPrimary,
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

    // In RTL, Alignment.centerRight corresponds to the first item visually.
    final horizontalAlignment = isArabic ? Alignment.centerRight : Alignment.centerLeft;
    final verticalAlignment = isArabic ? Alignment.centerLeft : Alignment.centerRight;

    return Container(
      height: kIsWeb ? 44 : 44.h,
      decoration: BoxDecoration(
        color: AppColors.divider.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(kIsWeb ? 12 : 12.r),
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
                margin: EdgeInsets.all(kIsWeb ? 4 : 4.r),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCream,
                  borderRadius: BorderRadius.circular(kIsWeb ? 8 : 8.r),
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
                          Icon(Icons.swap_horiz_rounded, size: kIsWeb ? 18 : 18.sp, color: isHorizontal ? AppColors.accentGold : AppColors.textPrimary.withValues(alpha: 0.6)),
                          SizedBox(width: kIsWeb ? 6 : 6.w),
                          Text(
                            l10n.themeScrollHorizontal,
                            style: TextStyle(
                              fontSize: kIsWeb ? 14 : 14.sp,
                              fontWeight: isHorizontal ? FontWeight.bold : FontWeight.w500,
                              color: isHorizontal ? AppColors.accentGold : AppColors.textPrimary.withValues(alpha: 0.6),
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
                          Icon(Icons.swap_vert_rounded, size: kIsWeb ? 18 : 18.sp, color: !isHorizontal ? AppColors.accentGold : AppColors.textPrimary.withValues(alpha: 0.6)),
                          SizedBox(width: kIsWeb ? 6 : 6.w),
                          Text(
                            l10n.themeScrollVertical,
                            style: TextStyle(
                              fontSize: kIsWeb ? 14 : 14.sp,
                              fontWeight: !isHorizontal ? FontWeight.bold : FontWeight.w500,
                              color: !isHorizontal ? AppColors.accentGold : AppColors.textPrimary.withValues(alpha: 0.6),
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
    switch (id) {
      case 'cream': return l10n.themeCream;
      case 'white': return l10n.themeWhite;
      case 'mint': return l10n.themeMint;
      case 'iceBlue': return l10n.themeIceBlue;
      case 'dark': return l10n.themeDark;
      default: return id;
    }
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(kIsWeb ? 24 : 24.r)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(kIsWeb ? 24 : 24.w, kIsWeb ? 16 : 16.h, kIsWeb ? 24 : 24.w, kIsWeb ? 32 : 32.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: kIsWeb ? 40 : 40.w,
                  height: kIsWeb ? 4 : 4.h,
                  margin: EdgeInsets.only(bottom: kIsWeb ? 20 : 20.h),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold,
                    borderRadius: BorderRadius.circular(kIsWeb ? 2 : 2.r),
                  ),
                ),
              ),
              Text(
                l10n.themeAppearanceTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: kIsWeb ? 18 : 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: kIsWeb ? 24 : 24.h),
              
              // Dark Mode Toggle
              Directionality(
                textDirection: TextDirection.rtl,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 16 : 16.w, vertical: kIsWeb ? 8 : 8.h),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCream,
                    borderRadius: BorderRadius.circular(kIsWeb ? 14 : 14.r),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppColors.accentGold),
                          SizedBox(width: kIsWeb ? 12 : 12.w),
                          Text(
                            l10n.themeDarkMode,
                            style: TextStyle(
                              fontSize: kIsWeb ? 16 : 16.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: isDark,
                        activeTrackColor: AppColors.accentGold,
                        onChanged: (val) {
                          context.read<SettingsBloc>().add(ToggleThemeMode(val ? ThemeMode.dark : ThemeMode.light));
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: kIsWeb ? 24 : 24.h),
              
              // Mushaf Colors List
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  l10n.themeMushafColor,
                  style: TextStyle(
                    fontSize: kIsWeb ? 16 : 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(height: kIsWeb ? 12 : 12.h),
              
              // Grid of colors
              Directionality(
                textDirection: TextDirection.rtl,
                child: Wrap(
                  spacing: kIsWeb ? 12 : 12.w,
                  runSpacing: kIsWeb ? 12 : 12.h,
                  children: MushafTheme.values.map((theme) {
                    final isSelected = state.mushafTheme.id == theme.id;
                    return GestureDetector(
                      onTap: () {
                        context.read<SettingsBloc>().add(ChangeMushafTheme(theme.id));
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: kIsWeb ? 56 : 56.w,
                            height: kIsWeb ? 56 : 56.w,
                            decoration: BoxDecoration(
                              color: theme.backgroundColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? theme.goldColor : AppColors.borderLight,
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: isSelected
                                ? Icon(Icons.check_rounded, color: theme.goldColor)
                                : null,
                          ),
                          SizedBox(height: kIsWeb ? 8 : 8.h),
                          Text(
                            _getThemeName(context, theme.id),
                            style: TextStyle(
                              fontSize: kIsWeb ? 12 : 12.sp,
                              color: isSelected ? theme.goldColor : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
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