import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';

class AppTextStyles {
  const AppTextStyles._();

  static TextStyle get quranText => TextStyle(
    fontFamily: 'KFGQPC HAFS Uthmanic Script Regular',
    color: AppColors.textPrimary,
    fontSize: kIsWeb ? 26 : 26.sp,
    height: 1.9,
  );

  static TextStyle get headerText => TextStyle(
    color: AppColors.textPrimary,
    fontSize: kIsWeb ? 16 : 16.sp,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get menuItemText => TextStyle(
    color: AppColors.textPrimary,
    fontSize: kIsWeb ? 16 : 16.sp,
    fontWeight: FontWeight.w500,
  );
}
