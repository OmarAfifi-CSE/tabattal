import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../core/bloc/locale/locale_cubit.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/mushaf_theme.dart';
import '../../bloc/settings_bloc.dart';
import '../../bloc/settings_event.dart';
import '../../bloc/settings_state.dart';

/// Dedicated tablet modal for managing App Language, Dark Mode, and Mushaf Color Themes.
void showThemeAndLanguageModalTablet(BuildContext context) {
  final isLandscape =
      MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
  final settingsBloc = context.read<SettingsBloc>();
  final localeCubit = context.read<LocaleCubit>();

  if (isLandscape) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 480.w, maxHeight: 520.h),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: settingsBloc),
                BlocProvider.value(value: localeCubit),
              ],
              child: const ThemeAndLanguageSheetTablet(isDialog: true),
            ),
          ),
        ),
      ),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    constraints: BoxConstraints(maxWidth: 620.w),
    elevation: 0,
    builder: (ctx) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: settingsBloc),
        BlocProvider.value(value: localeCubit),
      ],
      child: const ThemeAndLanguageSheetTablet(),
    ),
  );
}

class ThemeAndLanguageSheetTablet extends StatelessWidget {
  final bool isDialog;

  const ThemeAndLanguageSheetTablet({
    super.key,
    this.isDialog = false,
  });

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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        final isDark = state.themeMode == ThemeMode.dark;
        final activeTheme = state.effectiveMushafTheme;

        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              (isLandscape ? 16.0 : 24.0).w,
              (isLandscape ? 14.0 : 20.0).h,
              (isLandscape ? 16.0 : 24.0).w,
              isDialog
                  ? (isLandscape ? 14.0 : 20.0).h
                  : math.max(
                      (isLandscape ? 14.0 : 20.0).h,
                      MediaQuery.paddingOf(context).bottom,
                    ),
            ),
            decoration: BoxDecoration(
              color: AppColors.cardCream,
              borderRadius: isDialog
                  ? BorderRadius.circular(20.r)
                  : BorderRadius.vertical(top: Radius.circular(24.r)),
              border: isDialog
                  ? Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.35),
                      width: 1.5.w,
                    )
                  : null,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Drag Indicator (only for bottom sheet)
                  if (!isDialog)
                    Center(
                      child: Container(
                        width: 44.w,
                        height: 4.h,
                        margin: EdgeInsets.only(bottom: 16.h),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                    ),

                  // Header Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.palette_outlined,
                            color: AppColors.accentGold,
                            size: (isLandscape ? 22.0 : 28.0).sp,
                          ),
                          SizedBox(width: 10.0.w),
                          Text(
                            l10n.drawerThemeAndLanguage,
                            style: TextStyle(
                              fontSize: (isLandscape ? 17.0 : 22.0).sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      if (isDialog)
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          color: AppColors.textPrimary,
                          iconSize: 22.sp,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  SizedBox(height: (isLandscape ? 14.0 : 20.0).h),

                  // 1. Language Toggle Row
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: BlocBuilder<LocaleCubit, Locale>(
                      builder: (context, locale) {
                        final isCurrentArabic = locale.languageCode == 'ar';
                        return Container(
                          padding: EdgeInsets.all(4.r),
                          decoration: BoxDecoration(
                            color: AppColors.accentGold.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: AppColors.accentGold.withValues(alpha: 0.25),
                              width: 1.w,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _LanguagePillTablet(
                                  label: 'العربية',
                                  isSelected: isCurrentArabic,
                                  activeGold: activeTheme.goldColor,
                                  isLandscape: isLandscape,
                                  onTap: () {
                                    if (!isCurrentArabic) {
                                      context.read<LocaleCubit>().setLocale('ar');
                                    }
                                  },
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Expanded(
                                child: _LanguagePillTablet(
                                  label: 'English',
                                  isSelected: !isCurrentArabic,
                                  activeGold: activeTheme.goldColor,
                                  isLandscape: isLandscape,
                                  onTap: () {
                                    if (isCurrentArabic) {
                                      context.read<LocaleCubit>().setLocale('en');
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: (isLandscape ? 14.0 : 20.0).h),

                  // 2. Dark Mode Quick Switch
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: (isLandscape ? 14.0 : 18.0).w,
                      vertical: (isLandscape ? 10.0 : 14.0).h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: AppColors.accentGold.withValues(alpha: 0.2),
                        width: 1.w,
                      ),
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
                              color: AppColors.accentGold,
                              size: (isLandscape ? 20.0 : 24.0).sp,
                            ),
                            SizedBox(width: 12.w),
                            Text(
                              l10n.themeDarkMode,
                              style: TextStyle(
                                fontSize: (isLandscape ? 15.0 : 17.5).sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: isDark,
                          activeThumbColor: AppColors.accentGold,
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
                  SizedBox(height: (isLandscape ? 16.0 : 22.0).h),

                  // 3. Mushaf Colors Palette Title
                  Text(
                    l10n.themeMushafColor,
                    style: TextStyle(
                      fontSize: (isLandscape ? 16.0 : 18.5).sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: (isLandscape ? 10.0 : 14.0).h),

                  // Mushaf Themes Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isLandscape ? 6 : 5,
                      mainAxisSpacing: (isLandscape ? 8.0 : 12.0).h,
                      crossAxisSpacing: (isLandscape ? 8.0 : 10.0).w,
                      childAspectRatio: isLandscape ? 0.82 : 0.78,
                    ),
                    itemCount: MushafTheme.values.length,
                    itemBuilder: (context, index) {
                      final theme = MushafTheme.values[index];
                      final isSelected = state.mushafTheme.id == theme.id;
                      final double circleSize = (isLandscape ? 44.0 : 64.0).r;

                      return GestureDetector(
                        onTap: () {
                          context.read<SettingsBloc>().add(
                                ChangeMushafTheme(theme.id),
                              );
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          children: [
                            Expanded(
                              child: Center(
                                child: Container(
                                  width: circleSize,
                                  height: circleSize,
                                  decoration: BoxDecoration(
                                    color: theme.backgroundColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.goldColor
                                          : AppColors.accentGold
                                              .withValues(alpha: 0.25),
                                      width: (isSelected ? 2.5 : 1.0).w,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: theme.goldColor
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 8.r,
                                              spreadRadius: 1.r,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: isSelected
                                      ? Icon(
                                          Icons.check_rounded,
                                          color: theme.goldColor,
                                          size: (isLandscape ? 20.0 : 26.0).sp,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            SizedBox(height: (isLandscape ? 4.0 : 6.0).h),
                            SizedBox(
                              height: (isLandscape ? 18.0 : 22.0).h,
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _getThemeName(context, theme.id),
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: (isLandscape ? 12.5 : 15.0).sp,
                                      color: isSelected
                                          ? theme.goldColor
                                          : AppColors.textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LanguagePillTablet extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color activeGold;
  final bool isLandscape;
  final VoidCallback onTap;

  const _LanguagePillTablet({
    required this.label,
    required this.isSelected,
    required this.activeGold,
    this.isLandscape = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: (isLandscape ? 10.0 : 14.0).h),
        decoration: BoxDecoration(
          color: isSelected
              ? activeGold.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular((isLandscape ? 10.0 : 12.0).r),
          border: isSelected
              ? Border.all(color: activeGold.withValues(alpha: 0.4), width: 1.w)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected) ...[
              Icon(
                Icons.check_circle_rounded,
                size: (isLandscape ? 16.0 : 20.0).sp,
                color: activeGold,
              ),
              SizedBox(width: (isLandscape ? 6.0 : 8.0).w),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: (isLandscape ? 15.0 : 17.5).sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? activeGold
                    : AppColors.textPrimary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dual icon for Tablet Drawer entry representing both Mushaf Appearance and Language.
class ThemeAndLanguageDrawerIconTablet extends StatelessWidget {
  final double? size;
  const ThemeAndLanguageDrawerIconTablet({super.key, this.size});

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final s = size ?? (isLandscape ? 46.0 : 50.0).r;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: s * 0.16,
            left: s * 0.16,
            child: Icon(
              Icons.palette_rounded,
              color: AppColors.accentGold,
              size: s * 0.44,
            ),
          ),
          Positioned(
            bottom: s * 0.11,
            right: s * 0.11,
            child: Container(
              padding: EdgeInsets.all(1.5.r),
              decoration: BoxDecoration(
                color: AppColors.cardCream,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.translate_rounded,
                color: AppColors.accentGold,
                size: s * 0.32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

