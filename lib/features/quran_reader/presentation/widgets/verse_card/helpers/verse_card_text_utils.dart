import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/verse_card_theme.dart';

/// Pure text and style helper methods for the Verse Card Generator.
class VerseCardTextUtils {
  const VerseCardTextUtils._();

  /// Converts standard digits to Arabic-Indic numeral glyphs.
  static String toArabicDigits(int number) {
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String str = number.toString();
    for (int i = 0; i < englishDigits.length; i++) {
      str = str.replaceAll(englishDigits[i], arabicDigits[i]);
    }
    return str;
  }

  /// Cleans raw text for sharing by removing non-essential diacritics and multiple spaces.
  static String cleanTextForSharing(String text) {
    return text
        .replaceAll('ٱ', 'ا')
        .replaceAll(RegExp(r'[\u06D6-\u06ED]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Dynamically computes optimal font size and line height based on exact character length.
  static TextStyle getDynamicVerseTextStyle({
    required bool hasQcfFont,
    required String verseText,
    required VerseCardTheme theme,
  }) {
    const isWeb = kIsWeb;
    final int length = verseText.length;
    double fontSize;
    double lineHeight;

    if (length <= 100) {
      fontSize = hasQcfFont ? (isWeb ? 38 : 34.sp) : (isWeb ? 34 : 30.sp);
      lineHeight = 1.90;
    } else if (length <= 180) {
      fontSize = hasQcfFont ? (isWeb ? 33 : 29.sp) : (isWeb ? 29 : 26.sp);
      lineHeight = 1.85;
    } else if (length <= 300) {
      fontSize = hasQcfFont ? (isWeb ? 28 : 25.sp) : (isWeb ? 25 : 22.sp);
      lineHeight = 1.80;
    } else if (length <= 480) {
      fontSize = hasQcfFont ? (isWeb ? 23 : 21.sp) : (isWeb ? 21 : 19.sp);
      lineHeight = 1.75;
    } else if (length <= 750) {
      fontSize = hasQcfFont ? (isWeb ? 19 : 17.sp) : (isWeb ? 17 : 15.sp);
      lineHeight = 1.70;
    } else if (length <= 1050) {
      fontSize = hasQcfFont ? (isWeb ? 17 : 15.sp) : (isWeb ? 15 : 13.5.sp);
      lineHeight = 1.65;
    } else {
      fontSize = hasQcfFont ? (isWeb ? 15 : 13.5.sp) : (isWeb ? 13.5 : 12.sp);
      lineHeight = 1.60;
    }

    return TextStyle(
      fontFamily: 'Amiri',
      fontSize: fontSize,
      height: lineHeight,
      fontWeight: hasQcfFont ? FontWeight.normal : FontWeight.bold,
      color: theme.primaryTextColor,
    );
  }
}
