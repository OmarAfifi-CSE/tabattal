import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Helper service for picking and downloading custom background videos.
class CustomVideoService {
  const CustomVideoService._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        if (!kIsWeb)
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    ),
  );

  /// Picks a video file from the device gallery.
  static Future<String?> pickVideoFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: (!kIsWeb &&
                (Platform.isWindows ||
                    Platform.isLinux ||
                    Platform.isMacOS))
            ? null
            : const Duration(minutes: 10),
      );
      return pickedFile?.path;
    } catch (e) {
      debugPrint('Error picking video: $e');
      return null;
    }
  }

  /// Downloads a video from a direct URL and saves it to a local temporary file.
  static Future<String> downloadVideoFromUrl(
    String url, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      throw const FormatException('الرابط يجب أن يبدأ بـ http:// أو https://');
    }

    if (kIsWeb) {
      return cleanUrl;
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = 'custom_bg_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final filePath = p.join(tempDir.path, fileName);

    final response = await _dio.download(
      cleanUrl,
      filePath,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
      ),
    );

    if (response.statusCode != 200) {
      final file = File(filePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      throw HttpException('فشل تحميل الفيديو من الرابط (كود: ${response.statusCode})');
    }

    final file = File(filePath);
    if (!await file.exists() || await file.length() == 0) {
      throw const FormatException('ملف الفيديو المحمل فارغ أو غير صالح');
    }

    return filePath;
  }
}
