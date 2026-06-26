import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

ThemeData appTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accentGold,
      surface: AppColors.background,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
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
  return Directionality(
    textDirection: TextDirection.rtl,
    child: child!,
  );
}
