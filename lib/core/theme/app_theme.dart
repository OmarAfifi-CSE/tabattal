import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/settings/presentation/bloc/settings_bloc.dart';
import 'app_colors.dart';

ThemeData appTheme() {
  return ThemeData(
    fontFamily: 'Amiri',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accentGold,
      surface: AppColors.background,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
  );
}

ThemeData appThemeDark() {
  return ThemeData(
    fontFamily: 'Amiri',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accentGold,
      surface: const Color(0xFF121212),
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF121212),
  );
}

const SystemUiOverlayStyle systemUiOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
  systemStatusBarContrastEnforced: false,
);

Widget appDirectionalityBuilder(BuildContext context, Widget? child) {
  final settingsState = context.watch<SettingsBloc>().state;
  final effectiveTheme = settingsState.effectiveMushafTheme;
  final isDarkMode = effectiveTheme.id == 'dark';

  AppColors.isDarkMode = isDarkMode;
  AppColors.currentMushafTheme = effectiveTheme;
  
  final overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
    systemNavigationBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );

  // Force the System UI to update instantly rather than waiting for a route change/scroll
  Future.microtask(() => SystemChrome.setSystemUIOverlayStyle(overlayStyle));

  return AnnotatedRegion<SystemUiOverlayStyle>(
    value: overlayStyle,
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: child!,
    ),
  );
}
