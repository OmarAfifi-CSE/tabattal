import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/settings/bloc/settings_bloc.dart';
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
    pageTransitionsTheme: _appPageTransitionsTheme,
    appBarTheme: const AppBarTheme(
      scrolledUnderElevation: 0.0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
    ),
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
    pageTransitionsTheme: _appPageTransitionsTheme,
    appBarTheme: const AppBarTheme(
      scrolledUnderElevation: 0.0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
    ),
  );
}

/// A high-performance horizontal page transitions builder that opens screens with a
/// pure opaque slide-over transition from right to left without shifting or squashing
/// the underlying Quran page, and with zero text ghosting / opacity artifacts during pop navigation.
class NoPushPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoPushPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const beginOffset = Offset(1.0, 0.0);

    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: beginOffset,
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: child,
    );
  }
}

const _appPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: NoPushPageTransitionsBuilder(),
    TargetPlatform.iOS: NoPushPageTransitionsBuilder(),
    TargetPlatform.macOS: NoPushPageTransitionsBuilder(),
    TargetPlatform.windows: NoPushPageTransitionsBuilder(),
    TargetPlatform.linux: NoPushPageTransitionsBuilder(),
    TargetPlatform.fuchsia: NoPushPageTransitionsBuilder(),
  },
);

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
  final isDarkStatusBar = effectiveTheme.isDarkTheme;

  AppColors.isDarkMode = settingsState.themeMode == ThemeMode.dark;
  AppColors.currentMushafTheme = effectiveTheme;

  final overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarIconBrightness: isDarkStatusBar ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDarkStatusBar ? Brightness.dark : Brightness.light,
    systemNavigationBarIconBrightness: isDarkStatusBar
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );

  // Force the System UI to update instantly rather than waiting for a route change/scroll
  Future.microtask(() => SystemChrome.setSystemUIOverlayStyle(overlayStyle));

  return AnnotatedRegion<SystemUiOverlayStyle>(
    value: overlayStyle,
    child: Directionality(textDirection: TextDirection.rtl, child: child!),
  );
}
