/// Centralized design tokens and dimension constants for the entire application.
/// Provides canonical `const` values to eliminate Magic Numbers and redundant allocations.
class AppDimensions {
  const AppDimensions._();

  // Standard Icon Sizes
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 28.0;
  static const double iconXl = 32.0;
  static const double iconXxl = 40.0;

  // Stroke & Border Widths
  static const double borderWidthThin = 1.0;
  static const double borderWidthStandard = 1.5;
  static const double borderWidthThick = 2.0;

  // Elevations & Shadows
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;
}

/// Standard spacing and margin constants.
class AppInsets {
  const AppInsets._();

  static const double p2 = 2.0;
  static const double p4 = 4.0;
  static const double p6 = 6.0;
  static const double p8 = 8.0;
  static const double p10 = 10.0;
  static const double p12 = 12.0;
  static const double p14 = 14.0;
  static const double p16 = 16.0;
  static const double p18 = 18.0;
  static const double p20 = 20.0;
  static const double p24 = 24.0;
  static const double p28 = 28.0;
  static const double p32 = 32.0;
  static const double p36 = 36.0;
  static const double p40 = 40.0;
  static const double p48 = 48.0;
}

/// Standard border radius constants.
class AppRadius {
  const AppRadius._();

  static const double r4 = 4.0;
  static const double r6 = 6.0;
  static const double r8 = 8.0;
  static const double r10 = 10.0;
  static const double r12 = 12.0;
  static const double r14 = 14.0;
  static const double r16 = 16.0;
  static const double r18 = 18.0;
  static const double r20 = 20.0;
  static const double r24 = 24.0;
  static const double r28 = 28.0;
  static const double r32 = 32.0;
  static const double rCircular = 999.0;
}

/// Standard animation durations across the app for silky smooth 120 FPS transitions.
class AppDurations {
  const AppDurations._();

  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration medium = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration pulse = Duration(milliseconds: 800);
  static const Duration sheetTransition = Duration(milliseconds: 300);
}
