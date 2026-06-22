import '../../../../core/network/api_client.dart';
import '../../../../core/error/exceptions.dart';
import '../models/tafsir_model.dart';
import '../models/translation_model.dart';

abstract class QuranRemoteDataSource {
  Future<Map<String, dynamic>> getTafsirByVerse(int resourceId, String verseKey);
  Future<TranslationModel> getTranslationByVerse(String verseKey, {int translationId = 20});
  Future<List<TafsirModel>> getTafsirsByChapter(int chapterId, {int tafsirId = 16, int page = 1});
  Future<List<TranslationModel>> getTranslationsByChapter(int chapterId, {int translationId = 20});
  Future<Map<String, dynamic>> getTafsirByChapter(int resourceId, int chapterId, {int page = 1, int perPage = 300});
}

class QuranRemoteDataSourceImpl implements QuranRemoteDataSource {
  final ApiClient apiClient;

  QuranRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<Map<String, dynamic>> getTafsirByVerse(int resourceId, String verseKey) {
    return apiClient.getJson(
      '/tafsirs/$resourceId/by_ayah/$verseKey',
      parse: (json) => json,
    );
  }

  @override
  Future<TranslationModel> getTranslationByVerse(String verseKey, {int translationId = 20}) {
    return apiClient.getJson(
      '/quran/translations/$translationId',
      query: {'verse_key': verseKey},
      parse: (json) {
        final List translations = json['translations'] ?? [];
        if (translations.isNotEmpty) return TranslationModel.fromJson(translations.first);
        throw ServerException('Translation empty');
      },
    );
  }

  @override
  Future<List<TafsirModel>> getTafsirsByChapter(int chapterId, {int tafsirId = 16, int page = 1}) {
    return apiClient.getJson(
      '/tafsirs/$tafsirId/by_chapter/$chapterId',
      query: {'per_page': 300, 'page': page},
      parse: (json) => (json['tafsirs'] as List? ?? []).map((t) => TafsirModel.fromJson(t)).toList(),
    );
  }

  @override
  Future<List<TranslationModel>> getTranslationsByChapter(int chapterId, {int translationId = 20}) {
    return apiClient.getJson(
      '/quran/translations/$translationId',
      query: {'chapter_number': chapterId},
      parse: (json) => (json['translations'] as List? ?? []).map((t) => TranslationModel.fromJson(t)).toList(),
    );
  }

  @override
  Future<Map<String, dynamic>> getTafsirByChapter(int resourceId, int chapterId, {int page = 1, int perPage = 300}) {
    return apiClient.getJson(
      '/tafsirs/$resourceId/by_chapter/$chapterId',
      query: {'per_page': perPage, 'page': page},
      parse: (json) => json,
    );
  }
}
