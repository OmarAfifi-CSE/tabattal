import 'package:dio/dio.dart';
import 'dart:io';
import '../../../../core/error/exceptions.dart';
import '../models/verse_model.dart';
import '../models/tafsir_model.dart';
import '../models/translation_model.dart';

abstract class QuranRemoteDataSource {
  Future<List<VerseModel>> getVersesBySurah(int surahId);
  Future<List<VerseModel>> getVersesByPage(int pageNumber);
  Future<TafsirModel> getTafsirByVerse(String verseKey, {int tafsirId = 169});
  Future<TranslationModel> getTranslationByVerse(String verseKey, {int translationId = 131});
}

class QuranRemoteDataSourceImpl implements QuranRemoteDataSource {
  final Dio dio;

  QuranRemoteDataSourceImpl({required this.dio}) {
    dio.options.connectTimeout = const Duration(seconds: 10);
    dio.options.receiveTimeout = const Duration(seconds: 10);
  }

  Exception _handleException(dynamic e) {
    if (e is SocketException) {
      return NetworkException('No Internet Connection');
    } else if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        return NetworkException('Connection Timeout');
      } else if (e.type == DioExceptionType.connectionError) {
        return NetworkException('Failed to connect to server. Check your connection.');
      }
      return ServerException('Server Error: ${e.response?.statusCode ?? 'Unknown'}');
    }
    return ServerException('Unexpected Error Occurred');
  }

  @override
  Future<List<VerseModel>> getVersesBySurah(int surahId) async {
    try {
      final response = await dio.get('https://api.quran.com/api/v4/verses/by_chapter/$surahId', queryParameters: {
        'words': true,
        'word_fields': 'text_uthmani,line_number,char_type_name,verse_key',
        'fields': 'text_uthmani',
      });
      
      if (response.statusCode == 200) {
        final List verses = response.data['verses'] ?? [];
        return verses.map((json) => VerseModel.fromJson(json, '')).toList();
      } else {
        throw ServerException('Failed to load verses');
      }
    } catch (e) {
      throw _handleException(e);
    }
  }

  @override
  Future<List<VerseModel>> getVersesByPage(int pageNumber) async {
    try {
      final response = await dio.get('https://api.quran.com/api/v4/verses/by_page/$pageNumber', queryParameters: {
        'words': true,
        'word_fields': 'text_uthmani,line_number,char_type_name,verse_key',
        'fields': 'text_uthmani',
      });
      
      if (response.statusCode == 200) {
        final List verses = response.data['verses'] ?? [];
        return verses.map((json) => VerseModel.fromJson(json, '')).toList();
      } else {
        throw ServerException('Failed to load verses');
      }
    } catch (e) {
      throw _handleException(e);
    }
  }

  @override
  Future<TafsirModel> getTafsirByVerse(String verseKey, {int tafsirId = 169}) async {
    try {
      final response = await dio.get('https://api.quran.com/api/v4/tafsirs/$tafsirId/by_verse/$verseKey');
      
      if (response.statusCode == 200) {
        return TafsirModel.fromJson(response.data['tafsir'] ?? {});
      } else {
        throw ServerException('Failed to load tafsir');
      }
    } catch (e) {
      throw _handleException(e);
    }
  }

  @override
  Future<TranslationModel> getTranslationByVerse(String verseKey, {int translationId = 131}) async {
    try {
      final response = await dio.get('https://api.quran.com/api/v4/quran/translations/$translationId', queryParameters: {
        'verse_key': verseKey,
      });
      
      if (response.statusCode == 200) {
        final List translations = response.data['translations'] ?? [];
        if (translations.isNotEmpty) {
          return TranslationModel.fromJson(translations.first);
        }
        throw ServerException('Translation empty');
      } else {
        throw ServerException('Failed to load translation');
      }
    } catch (e) {
      throw _handleException(e);
    }
  }
}
