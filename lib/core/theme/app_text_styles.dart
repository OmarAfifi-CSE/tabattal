import 'package:flutter/material.dart';
import 'app_colors.dart';


class AppTextStyles {
  static const TextStyle quranText = TextStyle(
    fontFamily: 'AmiriQuran',
    color: AppColors.textPrimary,
    fontSize: 26,
    height: 1.9,
  );

  static const TextStyle headerText = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  
  static const TextStyle menuItemText = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );
}
