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
      width: kIsWeb ? 320 : 310.w,
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
      padding: EdgeInsets.only(top: 75.h, bottom: 75.h),
      child: drawer,
    );
  }


  Widget _buildMenuItems(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
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
        _divider(),
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
        _divider(),
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
        _divider(),
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
        _divider(),
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
          _divider(),
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
        _divider(),
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
    ));
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 32.h, 20.w, 24.h),
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.08),
        border: const Border(
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
                          style: const TextStyle(
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
                style: const TextStyle(
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
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
