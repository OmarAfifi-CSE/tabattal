import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../settings/bloc/settings_bloc.dart';
import '../../../../../settings/bloc/settings_event.dart';
import '../../../../../settings/bloc/settings_state.dart';
import '../../../../bloc/bookmark/bookmark_bloc.dart';
import '../../../../bloc/bookmark/bookmark_state.dart';
import '../../../pages/search/web/quran_search_screen_web.dart';
import '../tablet/quran_audio_manager_view_tablet.dart';
import '../tablet/quran_full_tafsir_view_tablet.dart';
import '../tablet/quran_translation_view_tablet.dart';
import '../tablet/theme_and_language_sheet_tablet.dart';
import 'quran_bookmarks_view_web.dart';
import 'quran_index_view_web.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final drawer = Drawer(
      width: 300,
      backgroundColor: AppColors.surfaceCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
      ),
      child: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const _WebDrawerHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
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
                  _WebDrawerItem(
                    icon: Icons.search_rounded,
                    title: l10n.drawerSearch,
                    subtitle: l10n.drawerSearchSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      final result =
                          await Navigator.push<Map<String, dynamic>>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const QuranSearchScreenWeb(),
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
                  _WebDrawerItem(
                    icon: Icons.list_alt_rounded,
                    title: l10n.drawerIndex,
                    subtitle: l10n.drawerIndexSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QuranIndexViewWeb(),
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
                  _WebDrawerItem(
                    icon: Icons.bookmark_rounded,
                    title: l10n.drawerBookmarks,
                    subtitle: l10n.drawerBookmarksSubtitle,
                    badge: const _WebBookmarkBadge(),
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push<dynamic>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QuranBookmarksViewWeb(),
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
                  _WebDrawerItem(
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
                  _WebDrawerItem(
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
                  _WebDrawerItem(
                    icon: Icons.headphones_rounded,
                    title: l10n.drawerAudioManager,
                    subtitle: l10n.drawerAudioManagerSubtitle,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QuranAudioManagerViewTablet(),
                        ),
                      );
                    },
                  ),
                  _WebDrawerItem(
                    iconWidget: const _WebThemeAndLanguageIcon(),
                    title: l10n.drawerThemeAndLanguage,
                    subtitle: l10n.drawerThemeAndLanguageSubtitle,
                    onTap: () {
                      Navigator.pop(context);
                      showThemeAndLanguageModalTablet(context);
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
      padding: const EdgeInsets.only(top: 50, bottom: 50),
      child: drawer,
    );
  }
}

class _WebDrawerHeader extends StatelessWidget {
  const _WebDrawerHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.sizeOf(context).width,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_stories_rounded,
            color: AppColors.accentGold.withValues(alpha: 0.8),
            size: 32,
          ),
          const SizedBox(height: 10),
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
}

class _WebBookmarkBadge extends StatelessWidget {
  const _WebBookmarkBadge();

  @override
  Widget build(BuildContext context) {
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
}

class _WebDrawerItem extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? badge;

  const _WebDrawerItem({
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
              child: iconWidget ??
                  (icon != null
                      ? Icon(icon, color: AppColors.accentGold, size: 22)
                      : const SizedBox.shrink()),
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
                      if (badge != null) ...[const SizedBox(width: 8), badge!],
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
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
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
                  color: activeTheme.backgroundColor,
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
                          Icon(
                            Icons.swap_horiz_rounded,
                            size: 18,
                            color: isHorizontal
                                ? activeTheme.goldColor
                                : AppColors.textPrimary.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.themeScrollHorizontal,
                            style: TextStyle(
                              fontSize: 14,
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
                            size: 18,
                            color: !isHorizontal
                                ? activeTheme.goldColor
                                : AppColors.textPrimary.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.themeScrollVertical,
                            style: TextStyle(
                              fontSize: 14,
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

class _WebThemeAndLanguageIcon extends StatelessWidget {
  const _WebThemeAndLanguageIcon();

  @override
  Widget build(BuildContext context) {
    const double webS = 44.0;
    return SizedBox(
      width: webS,
      height: webS,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: webS * 0.16,
            left: webS * 0.16,
            child: Icon(
              Icons.palette_rounded,
              color: AppColors.accentGold,
              size: webS * 0.44,
            ),
          ),
          Positioned(
            bottom: webS * 0.11,
            right: webS * 0.11,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: AppColors.cardCream,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.translate_rounded,
                color: AppColors.accentGold,
                size: webS * 0.32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

