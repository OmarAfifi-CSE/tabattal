class QuranConstants {
  const QuranConstants._();

  static const int totalVerses = 6236;
  static const int totalSurahs = 114;
  static const int totalPages = 604;
  static const int linesPerPage = 15;

  static const Set<int> bundledTafsirIds = {16, 14, 91};
  static const Set<int> downloadableTafsirIds = {15, 90, 93, 94};
  static const int defaultTafsirId = 16;
  static const int defaultTranslationId = 20;

  static const int tafsirDownloadConcurrency = 2;
  static const int tafsirMaxRetries = 3;
  static const int tafsirPerPage = 20;
}
