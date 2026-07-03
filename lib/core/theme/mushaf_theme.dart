import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

class MushafTheme extends Equatable {
  final String id;
  final String name;
  final Color backgroundColor;
  final Color textColor;
  final Color goldColor;
  final Color innerBorderColor;

  const MushafTheme({
    required this.id,
    required this.name,
    required this.backgroundColor,
    required this.textColor,
    required this.goldColor,
    required this.innerBorderColor,
  });

  @override
  List<Object?> get props => [id, backgroundColor, textColor, goldColor, innerBorderColor];

  // The 4 color themes
  static const MushafTheme cream = MushafTheme(
    id: 'cream',
    name: 'كريمي',
    backgroundColor: Color(0xFFFBF7F0),
    textColor: Color(0xFF2C2520),
    goldColor: Color(0xFFB59A53),
    innerBorderColor: Color(0xFFEAD8BA),
  );

  static const MushafTheme white = MushafTheme(
    id: 'white',
    name: 'أبيض',
    backgroundColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF1E1E1E),
    goldColor: Color(0xFFC7A263),
    innerBorderColor: Color(0xFFF0E5D1),
  );

  static const MushafTheme mint = MushafTheme(
    id: 'mint',
    name: 'نعناعي',
    backgroundColor: Color(0xFFF2FAF5),
    textColor: Color(0xFF1E2E24),
    goldColor: Color(0xFF91A896),
    innerBorderColor: Color(0xFFD6E8DB),
  );

  static const MushafTheme iceBlue = MushafTheme(
    id: 'iceBlue',
    name: 'أزرق ثلجي',
    backgroundColor: Color(0xFFF4F8FA),
    textColor: Color(0xFF1D2830),
    goldColor: Color(0xFF7B99AD),
    innerBorderColor: Color(0xFFD6E4EE),
  );

  // Dark Mode override
  static const MushafTheme dark = MushafTheme(
    id: 'dark',
    name: 'ليلي',
    backgroundColor: Color(0xFF121212),
    textColor: Color(0xFFE0E0E0),
    goldColor: Color(0xFF6B6B6B),
    innerBorderColor: Color(0xFF2C2C2C),
  );

  static const List<MushafTheme> values = [cream, white, mint, iceBlue];

  static MushafTheme fromId(String id) {
    switch (id) {
      case 'white': return white;
      case 'mint': return mint;
      case 'iceBlue': return iceBlue;
      case 'dark': return dark;
      case 'cream':
      default:
        return cream;
    }
  }
}
