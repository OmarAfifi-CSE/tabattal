import 'package:shared_preferences/shared_preferences.dart';
import '../network/audio_download_manager.dart';

/// Persists audio playback preferences: reciter, category, speed, repeat.
class AudioPreferencesService {
  static const String _keyCategory = 'audio_category';
  static const String _keyReciter = 'audio_reciter';
  static const String _keyRepeatCount = 'audio_repeat_count';
  static const String _keyLastPage = 'last_read_page'; // For saving last page

  static const String defaultCategory = 'مرتل';
  static const String defaultReciter = 'محمود خليل الحصري';
  static const int defaultRepeatCount = 0; // 0 = continue reading, -1 = infinite, >0 = count

  final SharedPreferences _prefs;

  AudioPreferencesService._(this._prefs);

  static Future<AudioPreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AudioPreferencesService._(prefs);
  }

  String get category {
    final saved = _prefs.getString(_keyCategory) ?? defaultCategory;
    // Validate: make sure category still exists in reciterCategories
    if (AudioDownloadManager.reciterCategories.containsKey(saved)) return saved;
    return defaultCategory;
  }

  String get reciter {
    final saved = _prefs.getString(_keyReciter) ?? defaultReciter;
    // Validate: make sure reciter belongs to the saved category
    final cat = AudioDownloadManager.reciterCategories[category];
    if (cat != null && cat.containsKey(saved)) return saved;
    // fallback: first reciter in category
    return AudioDownloadManager.reciterCategories[category]!.keys.first;
  }

  int get repeatCount => _prefs.getInt(_keyRepeatCount) ?? defaultRepeatCount;
  int get lastReadPage => _prefs.getInt(_keyLastPage) ?? 1;

  Future<void> saveCategory(String category) async {
    await _prefs.setString(_keyCategory, category);
  }

  Future<void> saveReciter(String reciter) async {
    await _prefs.setString(_keyReciter, reciter);
  }

  Future<void> saveRepeatCount(int count) async {
    await _prefs.setInt(_keyRepeatCount, count);
  }

  Future<void> saveLastReadPage(int page) async {
    await _prefs.setInt(_keyLastPage, page);
  }
}
