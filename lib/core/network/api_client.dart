import 'package:dio/dio.dart';
import '../error/exceptions.dart';

class ApiClient {
  final Dio dio;

  ApiClient({required this.dio}) {
    dio.options.connectTimeout = const Duration(seconds: 10);
    dio.options.receiveTimeout = const Duration(seconds: 10);
  }

  static const String kQuranApiBase = 'https://api.quran.com/api/v4';

  Future<T> getJson<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Map<String, dynamic>) parse,
  }) async {
    try {
      final response = await dio.get(
        path.startsWith('http') ? path : '$kQuranApiBase$path',
        queryParameters: query,
      );

      if (response.statusCode == 200) {
        if (response.data is Map<String, dynamic>) {
          return parse(response.data);
        } else {
          throw ServerException('Invalid JSON format');
        }
      } else {
        throw ServerException('Failed with status: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw NetworkException(e.message ?? 'Network connection error');
      }
      throw ServerException(e.message ?? 'Server error');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
