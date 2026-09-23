class QuranConstants {
  const QuranConstants._();

  static const int totalVerses = 6236;
  static const int totalSurahs = 114;
  static const int totalPages = 604;
  static const int linesPerPage = 15;

  /// Max verses to look backward when searching for a grouped tafsir entry.
  /// Must be > 20 to handle Ibn Kathir EN groups (e.g. 2:177→2:197 = 20 gap).
  static const int tafsirGroupLookbackWindow = 50;

  static const Set<int> bundledTafsirIds = {16}; // Muyassar bundled
  static const Set<int> downloadableTafsirIds = {
    14,
    91,
    15,
    90,
    93,
    94,
    169,
    812,
    171,
  }; // 14 & 91 moved to downloadable
  static const int defaultTafsirId = 16;
  static const int defaultTranslationId = 20; // Saheeh International (EN)
  static const int indonesianKemenagTranslationId = 33; // Kemenag (ID)
  static const int indonesianComplexTranslationId = 134; // King Fahad Complex (ID)
  static const int defaultIndonesianTranslationId = 33;
  static const String preferredTranslationIdKey = 'preferred_translation_id';

  /// Returns the appropriate default translation resource ID based on active language code.
  static int defaultTranslationIdForLocale(String languageCode) {
    if (languageCode == 'id') return defaultIndonesianTranslationId;
    return defaultTranslationId;
  }

  /// Returns the appropriate default tafsir resource ID based on active language code.
  static int defaultTafsirIdForLocale(String languageCode) {
    if (languageCode == 'en') return 169;
    return defaultTafsirId;
  }

  static const int tafsirDownloadConcurrency = 2;
  static const int tafsirMaxRetries = 3;
  static const int tafsirPerPage = 20;
}
