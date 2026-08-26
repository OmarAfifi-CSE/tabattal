import 'package:flutter/material.dart';

/// Global registry for the current Quran page repaint boundary key.
class QuranPageRepaintRegistry {
  QuranPageRepaintRegistry._();
  static GlobalKey? currentPageKey;
}

/// Supported share formats in the generator modal.
enum ShareFormat { video, image, text, fullPage }

/// Represents a color theme for the Verse Card.
class VerseCardTheme {
  final String id;
  final String name;
  final String nameEn;
  final Color backgroundColor;
  final Color cardBackground;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color accentColor;
  final Color borderColor;

  const VerseCardTheme({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.backgroundColor,
    required this.cardBackground,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.accentColor,
    required this.borderColor,
  });

  String getLocalizedName(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'en' ? nameEn : name;
  }

  static const List<VerseCardTheme> themes = [
    VerseCardTheme(
      id: 'cream',
      name: 'كريمي',
      nameEn: 'Cream',
      backgroundColor: Color(0xFFFBF7F0),
      cardBackground: Color(0xFFF7F2E7),
      primaryTextColor: Color(0xFF2C2520),
      secondaryTextColor: Color(0xFF5D4A3A),
      accentColor: Color(0xFFB59A53),
      borderColor: Color(0xFFEAD8BA),
    ),
    VerseCardTheme(
      id: 'white',
      name: 'أبيض',
      nameEn: 'White',
      backgroundColor: Color(0xFFFFFFFF),
      cardBackground: Color(0xFFF7F7F7),
      primaryTextColor: Color(0xFF1E1E1E),
      secondaryTextColor: Color(0xFF555555),
      accentColor: Color(0xFFC7A263),
      borderColor: Color(0xFFF0E5D1),
    ),
    VerseCardTheme(
      id: 'parchment',
      name: 'عتيق',
      nameEn: 'Vintage',
      backgroundColor: Color(0xFFF5EBE0),
      cardBackground: Color(0xFFEFE3D3),
      primaryTextColor: Color(0xFF3A2D21),
      secondaryTextColor: Color(0xFF6E5642),
      accentColor: Color(0xFF9C7A44),
      borderColor: Color(0xFFE3D4C1),
    ),
    VerseCardTheme(
      id: 'roseGold',
      name: 'روز جولد',
      nameEn: 'Rose Gold',
      backgroundColor: Color(0xFFFDF8F5),
      cardBackground: Color(0xFFF7ECE7),
      primaryTextColor: Color(0xFF38282A),
      secondaryTextColor: Color(0xFF6B5154),
      accentColor: Color(0xFFD89A88),
      borderColor: Color(0xFFF0DCD5),
    ),
    VerseCardTheme(
      id: 'mint',
      name: 'نعناعي',
      nameEn: 'Mint',
      backgroundColor: Color(0xFFF0F7F4),
      cardBackground: Color(0xFFE1EFEA),
      primaryTextColor: Color(0xFF1B3B2B),
      secondaryTextColor: Color(0xFF436B56),
      accentColor: Color(0xFF5B8A72),
      borderColor: Color(0xFFD6E8DB),
    ),
    VerseCardTheme(
      id: 'olive',
      name: 'زيتوني',
      nameEn: 'Olive',
      backgroundColor: Color(0xFFF7F8F2),
      cardBackground: Color(0xFFECEFE5),
      primaryTextColor: Color(0xFF252B1E),
      secondaryTextColor: Color(0xFF535C48),
      accentColor: Color(0xFF9A9D49),
      borderColor: Color(0xFFDFE3D1),
    ),
    VerseCardTheme(
      id: 'iceBlue',
      name: 'ثلجي',
      nameEn: 'Ice',
      backgroundColor: Color(0xFFF4F8FA),
      cardBackground: Color(0xFFE5F0F5),
      primaryTextColor: Color(0xFF1D2830),
      secondaryTextColor: Color(0xFF425A70),
      accentColor: Color(0xFF7B99AD),
      borderColor: Color(0xFFD6E4EE),
    ),
    VerseCardTheme(
      id: 'slate',
      name: 'رخامي',
      nameEn: 'Marble',
      backgroundColor: Color(0xFFF4F5F7),
      cardBackground: Color(0xFFE8ECF0),
      primaryTextColor: Color(0xFF1E252B),
      secondaryTextColor: Color(0xFF4C5866),
      accentColor: Color(0xFF7D8C9E),
      borderColor: Color(0xFFD8DFE8),
    ),
    VerseCardTheme(
      id: 'emerald',
      name: 'زمردي',
      nameEn: 'Emerald',
      backgroundColor: Color(0xFF0A1F18),
      cardBackground: Color(0xFF132D24),
      primaryTextColor: Color(0xFFFAF6F0),
      secondaryTextColor: Color(0xFFD0C3B0),
      accentColor: Color(0xFFD4AF37),
      borderColor: Color(0xFF1D3B30),
    ),
    VerseCardTheme(
      id: 'burgundy',
      name: 'عنابي',
      nameEn: 'Burgundy',
      backgroundColor: Color(0xFF1A0C14),
      cardBackground: Color(0xFF27131F),
      primaryTextColor: Color(0xFFF8EEF2),
      secondaryTextColor: Color(0xFFC7A5B5),
      accentColor: Color(0xFFE0B36C),
      borderColor: Color(0xFF331B28),
    ),
    VerseCardTheme(
      id: 'dark',
      name: 'ليلي',
      nameEn: 'Midnight',
      backgroundColor: Color(0xFF0D1117),
      cardBackground: Color(0xFF161B22),
      primaryTextColor: Color(0xFFF0F6FC),
      secondaryTextColor: Color(0xFF8B949E),
      accentColor: Color(0xFFE2C044),
      borderColor: Color(0xFF30363D),
    ),
  ];
}
