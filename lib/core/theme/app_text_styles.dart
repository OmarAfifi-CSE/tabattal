import 'package:flutter/material.dart';
import 'app_colors.dart';

import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  static TextStyle quranText = GoogleFonts.amiriQuran(
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
