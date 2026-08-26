import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/bloc/locale/locale_cubit.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/mushaf_theme.dart';
import '../../../../../settings/bloc/settings_bloc.dart';
import '../../../../../settings/bloc/settings_event.dart';
import '../../../../../settings/bloc/settings_state.dart';

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
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
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
    constraints: const BoxConstraints(maxWidth: 620),
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
            padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 16.0 : 24.0,
              vertical: isLandscape ? 14.0 : 20.0,
            ),
            decoration: BoxDecoration(
              color: AppColors.cardCream,
              borderRadius: isDialog
                  ? BorderRadius.circular(20)
                  : const BorderRadius.vertical(top: Radius.circular(24)),
              border: isDialog
                  ? Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.35),
                      width: 1.5,
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
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
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
                            size: isLandscape ? 20.0 : 26.0,
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            l10n.drawerThemeAndLanguage,
                            style: TextStyle(
                              fontSize: isLandscape ? 16.0 : 20.0,
                              fontWeight: FontWeight.bold,
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
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  SizedBox(height: isLandscape ? 12.0 : 18.0),

                  // 1. Language Toggle Row
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.accentGold.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _LanguagePillTablet(
                            label: 'العربية',
                            isSelected: isArabic,
                            activeGold: activeTheme.goldColor,
                            isLandscape: isLandscape,
                            onTap: () {
                              if (!isArabic) {
                                context.read<LocaleCubit>().setLocale('ar');
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _LanguagePillTablet(
                            label: 'English',
                            isSelected: !isArabic,
                            activeGold: activeTheme.goldColor,
                            isLandscape: isLandscape,
                            onTap: () {
                              if (isArabic) {
                                context.read<LocaleCubit>().setLocale('en');
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isLandscape ? 12.0 : 18.0),

                  // 2. Dark Mode Quick Switch
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 12.0 : 16.0,
                      vertical: isLandscape ? 8.0 : 12.0,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.accentGold.withValues(alpha: 0.2),
                        width: 1,
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
                              size: isLandscape ? 18.0 : 22.0,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              l10n.themeDarkMode,
                              style: TextStyle(
                                fontSize: isLandscape ? 13.5 : 16.0,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Transform.scale(
                          scale: isLandscape ? 0.8 : 0.9,
                          child: Switch(
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
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isLandscape ? 14.0 : 20.0),

                  // 3. Mushaf Colors Palette Title
                  Text(
                    l10n.themeMushafColor,
                    style: TextStyle(
                      fontSize: isLandscape ? 14.5 : 17.0,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: isLandscape ? 8.0 : 12.0),

                  // Mushaf Themes Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isLandscape ? 6 : 5,
                      mainAxisSpacing: isLandscape ? 8.0 : 14.0,
                      crossAxisSpacing: isLandscape ? 6.0 : 8.0,
                      childAspectRatio: isLandscape ? 0.92 : 0.85,
                    ),
                    itemCount: MushafTheme.values.length,
                    itemBuilder: (context, index) {
                      final theme = MushafTheme.values[index];
                      final isSelected = state.mushafTheme.id == theme.id;
                      final double circleSize = isLandscape ? 40.0 : 58.0;

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
                                  width: isSelected ? 2.5 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: theme.goldColor
                                              .withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check_rounded,
                                      color: theme.goldColor,
                                      size: isLandscape ? 18.0 : 24.0,
                                    )
                                  : null,
                            ),
                            SizedBox(height: isLandscape ? 4.0 : 6.0),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _getThemeName(context, theme.id),
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: isLandscape ? 11.5 : 13.5,
                                  color: isSelected
                                      ? theme.goldColor
                                      : AppColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
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
        padding: EdgeInsets.symmetric(vertical: isLandscape ? 8.0 : 12.0),
        decoration: BoxDecoration(
          color: isSelected
              ? activeGold.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(isLandscape ? 10.0 : 12.0),
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
                size: isLandscape ? 15.0 : 18.0,
                color: activeGold,
              ),
              SizedBox(width: isLandscape ? 4.0 : 6.0),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: isLandscape ? 14.0 : 16.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
