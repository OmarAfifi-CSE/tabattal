class ArabicTextUtils {
  const ArabicTextUtils._();

  static String normalizeArabicDiacritics(String text) {
    if (text.isEmpty) return text;
    final Map<String, String> diacritics = {
      'َ': '', 'ً': '', 'ُ': '', 'ٌ': '', 'ِ': '', 'ٍ': '', 'ّ': '', 'ْ': '',
      'ـ': '', 'ٰ': '', 'ٔ': '', 'ٕ': '', 'آ': 'ا', 'أ': 'ا', 'إ': 'ا', 'ٱ': 'ا',
      'ة': 'ه', 'ي': 'ى'
    };
    String result = text;
    diacritics.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    return result;
  }

  /// Removes or downgrades extended Uthmanic characters (like open tanween) 
  /// that are not supported by some fonts (e.g. KFGQPC HAFS) and appear as black circles.
  static String removeExtendedUthmaniChars(String text) {
    return text
        .replaceAll('\u08F0', '\u064B') // Open Fathatan -> Fathatan
        .replaceAll('\u08F1', '\u064C') // Open Dammatan -> Dammatan
        .replaceAll('\u08F2', '\u064D') // Open Kasratan -> Kasratan
        .replaceAll('\u08D6', '\u06E2') // Small meem for Iqlab
        .replaceAll('\u08D7', '\u06E8') // Small noon
        .replaceAll('\u08F3', '')
        .replaceAll('\u08D4', '')
        .replaceAll('\u08D5', '')
        .replaceAll('\u08D8', '')
        .replaceAll('\u08D9', '')
        .replaceAll('\u08DA', '')
        .replaceAll('\u08DB', '')
        .replaceAll('\u08DC', '')
        .replaceAll('\u08DD', '')
        .replaceAll('\u08DE', '')
        .replaceAll('\u08DF', '')
        .replaceAll('\u08E0', '')
        .replaceAll('\u08E1', '')
        .replaceAll('\u08E2', '')
        .replaceAll('\u06ED', '') // Removes Arabic Small Low Meem / formatting circle
        .replaceAll('\u06DF', '\u0652') // Small High Rounded Zero -> standard Sukun
        .replaceAll('\u06E0', '') // Small High Upright Rectangular Zero
        .replaceAll('\u06E1', '\u0652'); // Dotless Head of Khah -> standard Sukun
  }

  static const Map<String, String> _englishToArabicDigits = {
    '0': '٠', '1': '١', '2': '٢', '3': '٣', '4': '٤',
    '5': '٥', '6': '٦', '7': '٧', '8': '٨', '9': '٩',
  };

  static String normalizeArabicDigits(String text) {
    const Map<String, String> arabicToEnglish = {
      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
      '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    };
    String result = text;
    arabicToEnglish.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    return result;
  }

  static String toArabicDigits(int number) {
    return convertEnglishToArabicDigits(number.toString());
  }

  static String convertEnglishToArabicDigits(String text) {
    String result = text;
    _englishToArabicDigits.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    return result;
  }
  
  static String toEnglishDigits(String text) {
    return normalizeArabicDigits(text);
  }


  static String stripHtml(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  static ({int surah, int ayah})? parseVerseKey(String key) {
    final parts = key.split(':');
    if (parts.length != 2) return null;
    final surah = int.tryParse(parts[0]);
    final ayah = int.tryParse(parts[1]);
    if (surah == null || ayah == null) return null;
    return (surah: surah, ayah: ayah);
  }

  static int verseKeyToVerseId(String key) {
    final parts = parseVerseKey(key);
    if (parts == null) return 0;
    return parts.surah * 1000 + parts.ayah;
  }

  static String verseIdToVerseKey(int id) {
    final surah = id ~/ 1000;
    final ayah = id % 1000;
    return '$surah:$ayah';
  }
}

extension ArabicDigitsStringX on String {
  /// Converts all English digits in a string to Arabic-Indic digits.
  String get toArabicDigits => ArabicTextUtils.convertEnglishToArabicDigits(this);
}

extension ArabicDigitsIntX on int {
  /// Converts the integer to a string with Arabic-Indic digits.
  String get toArabicDigits => ArabicTextUtils.toArabicDigits(this);
}
