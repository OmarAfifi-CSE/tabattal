import 'package:flutter/material.dart';

class VideoThemePreset {
  final String id;
  final String nameArabic;
  final String nameEnglish;
  final List<Color> gradientColors;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color accentColor;
  final Color badgeBackgroundColor;
  final Color borderColor;
  final Color cardBackgroundColor;
  final Alignment beginAlignment;
  final Alignment endAlignment;

  const VideoThemePreset({
    required this.id,
    required this.nameArabic,
    required this.nameEnglish,
    required this.gradientColors,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.accentColor,
    required this.badgeBackgroundColor,
    this.borderColor = const Color(0xFFEAD8BA),
    this.cardBackgroundColor = const Color(0xFFF7F2E7),
    this.beginAlignment = Alignment.topCenter,
    this.endAlignment = Alignment.bottomCenter,
  });

  static const VideoThemePreset cream = VideoThemePreset(
    id: 'cream',
    nameArabic: 'كريمي',
    nameEnglish: 'Cream',
    gradientColors: [Color(0xFFFBF7F0), Color(0xFFF7F2E7)],
    primaryTextColor: Color(0xFF2C2520),
    secondaryTextColor: Color(0xFF5D4A3A),
    accentColor: Color(0xFFB59A53),
    badgeBackgroundColor: Color(0x22B59A53),
    borderColor: Color(0xFFEAD8BA),
    cardBackgroundColor: Color(0xFFF7F2E7),
  );

  static const VideoThemePreset white = VideoThemePreset(
    id: 'white',
    nameArabic: 'أبيض',
    nameEnglish: 'White',
    gradientColors: [Color(0xFFFFFFFF), Color(0xFFF8F9FA)],
    primaryTextColor: Color(0xFF111827),
    secondaryTextColor: Color(0xFF6B7280),
    accentColor: Color(0xFF374151),
    badgeBackgroundColor: Color(0x14374151),
    borderColor: Color(0xFFE5E7EB),
    cardBackgroundColor: Color(0xFFF8F9FA),
  );

  static const VideoThemePreset vintage = VideoThemePreset(
    id: 'vintage',
    nameArabic: 'عتيق',
    nameEnglish: 'Vintage',
    gradientColors: [Color(0xFFF5EBE0), Color(0xFFEFE3D3)],
    primaryTextColor: Color(0xFF3A2D21),
    secondaryTextColor: Color(0xFF6E5642),
    accentColor: Color(0xFF9C7A44),
    badgeBackgroundColor: Color(0x229C7A44),
    borderColor: Color(0xFFE3D4C1),
    cardBackgroundColor: Color(0xFFEFE3D3),
  );

  static const VideoThemePreset roseGold = VideoThemePreset(
    id: 'rose_gold',
    nameArabic: 'روز جولد',
    nameEnglish: 'Rose Gold',
    gradientColors: [Color(0xFFFDF8F5), Color(0xFFF7ECE7)],
    primaryTextColor: Color(0xFF38282A),
    secondaryTextColor: Color(0xFF6B5154),
    accentColor: Color(0xFFD89A88),
    badgeBackgroundColor: Color(0x22D89A88),
    borderColor: Color(0xFFF0DCD5),
    cardBackgroundColor: Color(0xFFF7ECE7),
  );

  static const VideoThemePreset mint = VideoThemePreset(
    id: 'mint',
    nameArabic: 'نعناعي',
    nameEnglish: 'Mint',
    gradientColors: [Color(0xFFF0F7F4), Color(0xFFE1EFEA)],
    primaryTextColor: Color(0xFF1B3B2B),
    secondaryTextColor: Color(0xFF436B56),
    accentColor: Color(0xFF5B8A72),
    badgeBackgroundColor: Color(0x225B8A72),
    borderColor: Color(0xFFD6E8DB),
    cardBackgroundColor: Color(0xFFE1EFEA),
  );

  static const VideoThemePreset olive = VideoThemePreset(
    id: 'olive',
    nameArabic: 'زيتوني',
    nameEnglish: 'Olive',
    gradientColors: [Color(0xFFF7F8F2), Color(0xFFECEFE5)],
    primaryTextColor: Color(0xFF252B1E),
    secondaryTextColor: Color(0xFF535C48),
    accentColor: Color(0xFF9A9D49),
    badgeBackgroundColor: Color(0x229A9D49),
    borderColor: Color(0xFFDFE3D1),
    cardBackgroundColor: Color(0xFFECEFE5),
  );

  static const VideoThemePreset iceBlue = VideoThemePreset(
    id: 'ice_blue',
    nameArabic: 'ثلجي',
    nameEnglish: 'Ice Blue',
    gradientColors: [Color(0xFFF4F8FA), Color(0xFFE5F0F5)],
    primaryTextColor: Color(0xFF1D2830),
    secondaryTextColor: Color(0xFF425A70),
    accentColor: Color(0xFF7B99AD),
    badgeBackgroundColor: Color(0x227B99AD),
    borderColor: Color(0xFFD6E4EE),
    cardBackgroundColor: Color(0xFFE5F0F5),
  );

  static const VideoThemePreset slate = VideoThemePreset(
    id: 'slate',
    nameArabic: 'رخامي',
    nameEnglish: 'Slate',
    gradientColors: [Color(0xFFF4F5F7), Color(0xFFE8ECF0)],
    primaryTextColor: Color(0xFF1E252B),
    secondaryTextColor: Color(0xFF4C5866),
    accentColor: Color(0xFF7D8C9E),
    badgeBackgroundColor: Color(0x227D8C9E),
    borderColor: Color(0xFFD8DFE8),
    cardBackgroundColor: Color(0xFFE8ECF0),
  );

  static const VideoThemePreset emerald = VideoThemePreset(
    id: 'emerald',
    nameArabic: 'زمردي',
    nameEnglish: 'Emerald',
    gradientColors: [Color(0xFF0A1F18), Color(0xFF06150C)],
    primaryTextColor: Color(0xFFFAF6F0),
    secondaryTextColor: Color(0xFFD0C3B0),
    accentColor: Color(0xFFD4AF37),
    badgeBackgroundColor: Color(0x22D4AF37),
    borderColor: Color(0xFF1D3B30),
    cardBackgroundColor: Color(0xFF132D24),
  );

  static const VideoThemePreset burgundy = VideoThemePreset(
    id: 'burgundy',
    nameArabic: 'عنابي',
    nameEnglish: 'Burgundy',
    gradientColors: [Color(0xFF1A0C14), Color(0xFF10050B)],
    primaryTextColor: Color(0xFFF8EEF2),
    secondaryTextColor: Color(0xFFC7A5B5),
    accentColor: Color(0xFFE0B36C),
    badgeBackgroundColor: Color(0x22E0B36C),
    borderColor: Color(0xFF331B28),
    cardBackgroundColor: Color(0xFF27131F),
  );

  static const VideoThemePreset night = VideoThemePreset(
    id: 'night',
    nameArabic: 'ليلي',
    nameEnglish: 'Dark',
    gradientColors: [Color(0xFF0D1117), Color(0xFF07090C)],
    primaryTextColor: Color(0xFFF0F6FC),
    secondaryTextColor: Color(0xFF8B949E),
    accentColor: Color(0xFFE2C044),
    badgeBackgroundColor: Color(0x22E2C044),
    borderColor: Color(0xFF30363D),
    cardBackgroundColor: Color(0xFF161B22),
  );

  static const List<VideoThemePreset> allPresets = [
    cream,
    white,
    vintage,
    roseGold,
    mint,
    olive,
    iceBlue,
    slate,
    emerald,
    burgundy,
    night,
  ];

  static VideoThemePreset getById(String id) {
    return allPresets.firstWhere(
      (p) => p.id == id,
      orElse: () => cream,
    );
  }
}
