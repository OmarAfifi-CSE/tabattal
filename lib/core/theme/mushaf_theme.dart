import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

class MushafTheme extends Equatable {
  final String id;
  final Color backgroundColor;
  final Color textColor;
  final Color goldColor;
  final Color innerBorderColor;

  const MushafTheme({
    required this.id,
    required this.backgroundColor,
    required this.textColor,
    required this.goldColor,
    required this.innerBorderColor,
  });

  @override
  List<Object?> get props => [
    id,
    backgroundColor,
    textColor,
    goldColor,
    innerBorderColor,
  ];

  /// Returns true if the theme background is dark (luminance < 0.45).
  bool get isDarkTheme => backgroundColor.computeLuminance() < 0.45;

  /// Slightly darker/richer accent color for verse numbers that have bookmarks.
  Color get bookmarkedMarkerColor {
    final hsl = HSLColor.fromColor(goldColor);
    if (isDarkTheme) {
      return hsl
          .withLightness((hsl.lightness * 0.88).clamp(0.0, 1.0))
          .toColor();
    } else {
      return hsl
          .withLightness((hsl.lightness * 0.78).clamp(0.0, 1.0))
          .toColor();
    }
  }

  // The 4 color themes
  static const MushafTheme cream = MushafTheme(
    id: 'cream',
    backgroundColor: Color(0xFFFBF7F0),
    textColor: Color(0xFF2C2520),
    goldColor: Color(0xFFB59A53),
    innerBorderColor: Color(0xFFEAD8BA),
  );

  static const MushafTheme white = MushafTheme(
    id: 'white',
    backgroundColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF1E1E1E),
    goldColor: Color(0xFFC7A263),
    innerBorderColor: Color(0xFFF0E5D1),
  );

  static const MushafTheme mint = MushafTheme(
    id: 'mint',
    backgroundColor: Color(0xFFF2FAF5),
    textColor: Color(0xFF1E2E24),
    goldColor: Color(0xFF91A896),
    innerBorderColor: Color(0xFFD6E8DB),
  );

  static const MushafTheme iceBlue = MushafTheme(
    id: 'iceBlue',
    backgroundColor: Color(0xFFF4F8FA),
    textColor: Color(0xFF1D2830),
    goldColor: Color(0xFF7B99AD),
    innerBorderColor: Color(0xFFD6E4EE),
  );

  static const MushafTheme parchment = MushafTheme(
    id: 'parchment',
    backgroundColor: Color(0xFFF5EBE0),
    textColor: Color(0xFF3A2D21),
    goldColor: Color(0xFF9C7A44),
    innerBorderColor: Color(0xFFE3D4C1),
  );

  static const MushafTheme roseGold = MushafTheme(
    id: 'roseGold',
    backgroundColor: Color(0xFFFDF8F5),
    textColor: Color(0xFF38282A),
    goldColor: Color(0xFFD89A88),
    innerBorderColor: Color(0xFFF0DCD5),
  );

  static const MushafTheme slate = MushafTheme(
    id: 'slate',
    backgroundColor: Color(0xFFF4F5F7),
    textColor: Color(0xFF1E252B),
    goldColor: Color(0xFF7D8C9E),
    innerBorderColor: Color(0xFFD8DFE8),
  );

  static const MushafTheme olive = MushafTheme(
    id: 'olive',
    backgroundColor: Color(0xFFF7F8F2),
    textColor: Color(0xFF252B1E),
    goldColor: Color(0xFF9A9D49),
    innerBorderColor: Color(0xFFDFE3D1),
  );

  static const MushafTheme emerald = MushafTheme(
    id: 'emerald',
    backgroundColor: Color(0xFF0A1F18),
    textColor: Color(0xFFF5F0E6),
    goldColor: Color(0xFFD4AF37),
    innerBorderColor: Color(0xFF1D3B30),
  );

  static const MushafTheme burgundy = MushafTheme(
    id: 'burgundy',
    backgroundColor: Color(0xFF1A0C14),
    textColor: Color(0xFFF8EEF2),
    goldColor: Color(0xFFE0B36C),
    innerBorderColor: Color(0xFF331B28),
  );

  // Dark Mode override
  static const MushafTheme dark = MushafTheme(
    id: 'dark',
    backgroundColor: Color(0xFF121212),
    textColor: Color(0xFFE0E0E0),
    goldColor: Color(0xFF6B6B6B),
    innerBorderColor: Color(0xFF2C2C2C),
  );

  static const List<MushafTheme> values = [
    cream,
    white,
    parchment,
    roseGold,
    mint,
    olive,
    iceBlue,
    slate,
    emerald,
    burgundy,
  ];

  static MushafTheme fromId(String id) {
    switch (id) {
      case 'white':
        return white;
      case 'mint':
        return mint;
      case 'iceBlue':
        return iceBlue;
      case 'parchment':
        return parchment;
      case 'roseGold':
        return roseGold;
      case 'slate':
        return slate;
      case 'olive':
        return olive;
      case 'emerald':
        return emerald;
      case 'burgundy':
        return burgundy;
      case 'dark':
        return dark;
      case 'cream':
      default:
        return cream;
    }
  }
}
