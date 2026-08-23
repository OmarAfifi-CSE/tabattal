import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../core/bloc/locale/locale_cubit.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/mushaf_theme.dart';
import '../../../../settings/bloc/settings_bloc.dart';
import '../../../../settings/bloc/settings_event.dart';
import '../../../../settings/bloc/settings_state.dart';


/// Unified modal bottom sheet for managing App Language, Dark Mode, and Mushaf Color Themes.
void showThemeAndLanguageModal(BuildContext context) {
  final settingsBloc = context.read<SettingsBloc>();
  final localeCubit = context.read<LocaleCubit>();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    elevation: 0,
    builder: (ctx) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: settingsBloc),
        BlocProvider.value(value: localeCubit),
      ],
      child: const ThemeAndLanguageSheet(),
    ),
  );
}

class ThemeAndLanguageSheet extends StatelessWidget {
  const ThemeAndLanguageSheet({super.key});

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

    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        final isDark = state.themeMode == ThemeMode.dark;
        final activeTheme = state.effectiveMushafTheme;

        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardCream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20.w,
                14.h,
                20.w,
                math.max(28.h, MediaQuery.paddingOf(context).bottom + 12.h),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Drag Handle
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      margin: EdgeInsets.only(bottom: 16.h),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),

                  // 2. Sheet Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.palette_rounded,
                        size: 20.sp,
                        color: AppColors.accentGold,
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.translate_rounded,
                        size: 18.sp,
                        color: AppColors.accentGold,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        l10n.drawerThemeAndLanguage,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // 3. Language Selector Section
                  Row(
                    children: [
                      Icon(
                        Icons.translate_rounded,
                        size: 16.sp,
                        color: AppColors.accentGold,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        l10n.drawerLanguage,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: BlocBuilder<LocaleCubit, Locale>(
                      builder: (context, locale) {
                        final isCurrentArabic = locale.languageCode == 'ar';
                        return Container(
                          padding: EdgeInsets.all(4.r),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCream,
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: AppColors.borderLight,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _LanguagePill(
                                  label: 'العربية',
                                  isSelected: isCurrentArabic,
                                  activeGold: activeTheme.goldColor,
                                  onTap: () {
                                    if (!isCurrentArabic) {
                                      context.read<LocaleCubit>().setLocale('ar');
                                    }
                                  },
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Expanded(
                                child: _LanguagePill(
                                  label: 'English',
                                  isSelected: !isCurrentArabic,
                                  activeGold: activeTheme.goldColor,
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
                  SizedBox(height: 18.h),

                  // 4. Dark Mode Switch Section
                  Container(
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
                            Container(
                              padding: EdgeInsets.all(6.r),
                              decoration: BoxDecoration(
                                color: activeTheme.goldColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isDark
                                    ? Icons.dark_mode_rounded
                                    : Icons.light_mode_rounded,
                                size: 18.sp,
                                color: activeTheme.goldColor,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Text(
                              l10n.themeDarkMode,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: isDark,
                          thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
                            if (states.contains(WidgetState.selected)) {
                              return activeTheme.goldColor;
                            }
                            return activeTheme.textColor.withValues(alpha: 0.75);
                          }),
                          trackColor: WidgetStateProperty.resolveWith<Color>((states) {
                            if (states.contains(WidgetState.selected)) {
                              return activeTheme.goldColor.withValues(alpha: 0.45);
                            }
                            return activeTheme.innerBorderColor;
                          }),
                          trackOutlineColor: WidgetStateProperty.resolveWith<Color>((states) {
                            return activeTheme.goldColor.withValues(alpha: 0.35);
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
                  SizedBox(height: 20.h),

                  // 5. Mushaf Color Grid Section
                  Text(
                    l10n.themeMushafColor,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 12.h,
                      crossAxisSpacing: 6.w,
                      childAspectRatio: 0.81,
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
                              width: 52.w,
                              height: 52.w,
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LanguagePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color activeGold;
  final VoidCallback onTap;

  const _LanguagePill({
    required this.label,
    required this.isSelected,
    required this.activeGold,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 9.h),
        decoration: BoxDecoration(
          color: isSelected
              ? activeGold.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
          border: isSelected
              ? Border.all(color: activeGold.withValues(alpha: 0.4), width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected) ...[
              Icon(
                Icons.check_circle_rounded,
                size: 15.sp,
                color: activeGold,
              ),
              SizedBox(width: 6.w),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeGold : AppColors.textPrimary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dual icon for Drawer entry representing both Mushaf Appearance and Language.
class ThemeAndLanguageDrawerIcon extends StatelessWidget {
  final bool isWeb;
  const ThemeAndLanguageDrawerIcon({super.key, this.isWeb = false});

  @override
  Widget build(BuildContext context) {
    if (isWeb) {
      return SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 7,
              left: 7,
              child: Icon(
                Icons.palette_rounded,
                color: AppColors.accentGold,
                size: 19,
              ),
            ),
            Positioned(
              bottom: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  color: AppColors.cardCream,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.translate_rounded,
                  color: AppColors.accentGold,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 44.w,
      height: 44.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 7.h,
            left: 7.w,
            child: Icon(
              Icons.palette_rounded,
              color: AppColors.accentGold,
              size: 19.sp,
            ),
          ),
          Positioned(
            bottom: 5.h,
            right: 5.w,
            child: Container(
              padding: EdgeInsets.all(1.5.r),
              decoration: BoxDecoration(
                color: AppColors.cardCream,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.translate_rounded,
                color: AppColors.accentGold,
                size: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

