import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/bloc/locale/locale_cubit.dart';
import '../../../../bloc/bookmark/bookmark_bloc.dart';
import '../../../../bloc/bookmark/bookmark_state.dart';
import '../../../pages/search/web/quran_search_screen_web.dart';
import 'quran_index_view_web.dart';
import '../quran_full_tafsir_view.dart';
import '../quran_translation_view.dart';
import '../quran_audio_manager_view.dart';
import 'quran_bookmarks_view_web.dart';
import '../../../../../settings/bloc/settings_bloc.dart';
import '../../../../../settings/bloc/settings_event.dart';
import '../../../../../settings/bloc/settings_state.dart';
import '../../../../../../core/theme/mushaf_theme.dart';
class QuranDrawerWeb extends StatelessWidget {
  final int currentPage;
  final void Function(int pageNumber, {String? verseKey}) onNavigateToPage;

  const QuranDrawerWeb({
    super.key,
    required this.currentPage,
    required this.onNavigateToPage,
  });

  @override
  Widget build(BuildContext context) {
    final drawer = Drawer(
      width: 300,
      backgroundColor: AppColors.surfaceCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
      ),
      child: _buildMenuItems(context),
    );
    // On mobile, float the drawer with vertical padding for the visual effect.
    // On web, fill the full height to avoid overflow on smaller viewports.
    return Padding(
      padding: const EdgeInsets.only(top: 50, bottom: 50),
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
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
              MaterialPageRoute(builder: (_) => const QuranSearchScreenWeb()),
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
              MaterialPageRoute(builder: (_) => const QuranIndexViewWeb()),
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
              MaterialPageRoute(builder: (_) => const QuranBookmarksViewWeb()),
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
                    ...[
            
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
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_stories_rounded, color: AppColors.accentGold.withValues(alpha: 0.8), size: 32),
          const SizedBox(height: 16),
          Text(
            '\uFD71 وَاذْكُرِ اسْمَ رَبِّكَ وَتَبَتَّلْ إِلَيْهِ تَبْتِيلًا \uFD70',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'KFGQPC HAFS Uthmanic Script Regular',
              fontSize: 20,
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.accentGold,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${state.bookmarkedVerseKeys.length}',
            style: TextStyle(
              color: AppColors.cardCream,
              fontSize: 12,
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
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
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
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
              Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              color: AppColors.textPrimary.withValues(alpha: 0.25),
              size: 20,
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
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.accentGold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                l10n.languagePickerTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _LanguageOption(
                label: l10n.languageArabic,
                isSelected: isArabic,
                onTap: () {
                  context.read<LocaleCubit>().setLocale('ar');
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentGold.withValues(alpha: 0.12) : AppColors.surfaceCream,
          borderRadius: BorderRadius.circular(14),
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
              size: 22,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
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
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.divider.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
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
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCream,
                  borderRadius: BorderRadius.circular(8),
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
                          Icon(Icons.swap_horiz_rounded, size: 18, color: isHorizontal ? AppColors.accentGold : AppColors.textPrimary.withValues(alpha: 0.6)),
                          const SizedBox(width: 6),
                          Text(
                            l10n.themeScrollHorizontal,
                            style: TextStyle(
                              fontSize: 14,
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
                          Icon(Icons.swap_vert_rounded, size: 18, color: !isHorizontal ? AppColors.accentGold : AppColors.textPrimary.withValues(alpha: 0.6)),
                          const SizedBox(width: 6),
                          Text(
                            l10n.themeScrollVertical,
                            style: TextStyle(
                              fontSize: 14,
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                l10n.themeAppearanceTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              
              // Dark Mode Toggle
              Directionality(
                textDirection: TextDirection.rtl,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCream,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppColors.accentGold),
                          const SizedBox(width: 12),
                          Text(
                            l10n.themeDarkMode,
                            style: TextStyle(
                              fontSize: 16,
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
              
              const SizedBox(height: 24),
              
              // Mushaf Colors List
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  l10n.themeMushafColor,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Grid of colors
              Directionality(
                textDirection: TextDirection.rtl,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
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
                            width: 56,
                            height: 56,
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
                          const SizedBox(height: 8),
                          Text(
                            _getThemeName(context, theme.id),
                            style: TextStyle(
                              fontSize: 12,
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

