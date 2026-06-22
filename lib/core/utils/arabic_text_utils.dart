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
    const Map<String, String> englishToArabic = {
      '0': '٠', '1': '١', '2': '٢', '3': '٣', '4': '٤',
      '5': '٥', '6': '٦', '7': '٧', '8': '٨', '9': '٩',
    };
    String result = number.toString();
    englishToArabic.forEach((key, value) {
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
