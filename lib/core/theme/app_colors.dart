import 'package:flutter/material.dart';
import 'mushaf_theme.dart';

class AppColors {
  static bool isDarkMode = false;
  static MushafTheme? currentMushafTheme;

  static MushafTheme get _theme {
    if (isDarkMode) return MushafTheme.dark;
    return currentMushafTheme ?? MushafTheme.cream;
  }

  static Color get background => _theme.backgroundColor;
  
  static Color get textPrimary => _theme.textColor;
  
  static Color get accentGold => _theme.goldColor; 
  static Color get accentGoldLight => _theme.goldColor.withValues(alpha: 0.6);
  static Color get accentGoldDark => _theme.goldColor;

  static Color get divider => _theme.innerBorderColor;

  static Color get surfaceCream => _theme.backgroundColor;
  static Color get cardCream => _theme.backgroundColor;
  static Color get inkBrown => _theme.textColor;
  
  static Color get bronzeIcon => _theme.goldColor;
  static Color get bronzeDark => _theme.goldColor;
  static Color get verseMarkerBrown => _theme.textColor.withValues(alpha: 0.6);
  static Color get verseMarkerGold => _theme.goldColor;
  
  static Color get borderInnerGold => _theme.innerBorderColor;
  static Color get borderLight => _theme.innerBorderColor.withValues(alpha: 0.3);
  static Color get borderMedium => _theme.innerBorderColor;
}
