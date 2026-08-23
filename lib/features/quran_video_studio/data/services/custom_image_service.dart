import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Helper service for picking and downloading custom background images.
class CustomImageService {
  const CustomImageService._();

  static final Map<String, ui.Image> _uiImageCache = {};
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    ),
  );

  /// Picks an image from the device gallery.
  static Future<String?> pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 3840,
        maxHeight: 3840,
        imageQuality: 95,
      );
      return pickedFile?.path;
    } catch (_) {
      return null;
    }
  }

  /// Downloads an image from a URL and saves it to a local temporary file.
  static Future<String> downloadImageFromUrl(String url) async {
    final cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      throw const FormatException('الرابط يجب أن يبدأ بـ http:// أو https://');
    }

    final response = await _dio.get<List<int>>(
      cleanUrl,
      options: Options(responseType: ResponseType.bytes),
    );

    if (response.statusCode != 200 || response.data == null) {
      throw HttpException('فشل تحميل الصورة من الرابط (كود: ${response.statusCode})');
    }

    final bytes = Uint8List.fromList(response.data!);
    if (bytes.isEmpty) {
      throw const FormatException('الصورة المحملة فارغة');
    }

    // Verify it is a valid decodable image
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final tempDir = await getTemporaryDirectory();
    final fileName = 'custom_bg_${DateTime.now().millisecondsSinceEpoch}.png';
    final filePath = p.join(tempDir.path, fileName);

    final file = File(filePath);
    await file.writeAsBytes(bytes);

    // Cache the decoded ui.Image for immediate painting
    _uiImageCache[filePath] = image;

    return filePath;
  }

  /// Loads and decodes a local image file into a [ui.Image] for Canvas painting.
  static Future<ui.Image?> loadUiImage(String filePath) async {
    if (_uiImageCache.containsKey(filePath)) {
      return _uiImageCache[filePath];
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      _uiImageCache[filePath] = image;
      return image;
    } catch (_) {
      return null;
    }
  }

  /// Synchronously gets a cached [ui.Image] if available.
  static ui.Image? getCachedUiImage(String filePath) {
    return _uiImageCache[filePath];
  }

  static final Map<String, double> _luminanceCache = {};

  /// Calculates the relative perceived luminance (0.0 = pitch black, 1.0 = pure white) of a local image.
  static Future<double> calculateImageLuminance(String filePath) async {
    if (_luminanceCache.containsKey(filePath)) {
      return _luminanceCache[filePath]!;
    }

    try {
      final uiImage = await loadUiImage(filePath);
      if (uiImage == null) return 0.5;

      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return 0.5;

      final bytes = byteData.buffer.asUint8List();
      if (bytes.isEmpty) return 0.5;

      // Sample up to 250 evenly distributed pixels
      int totalLuminance = 0;
      int sampleCount = 0;
      final totalPixels = bytes.length ~/ 4;
      final step = (totalPixels / 250).clamp(1.0, 1000.0).round() * 4;

      for (int i = 0; i < bytes.length - 3; i += step) {
        final r = bytes[i];
        final g = bytes[i + 1];
        final b = bytes[i + 2];
        // Standard perceived luminance formula (ITU-R BT.709)
        final lum = (0.2126 * r + 0.7152 * g + 0.0722 * b).round();
        totalLuminance += lum;
        sampleCount++;
      }

      if (sampleCount == 0) return 0.5;
      final avgLuminance = (totalLuminance / sampleCount) / 255.0;
      _luminanceCache[filePath] = avgLuminance;
      return avgLuminance;
    } catch (_) {
      return 0.5;
    }
  }

  /// Synchronously gets cached luminance or default fallback (0.5).
  static double getCachedLuminance(String filePath) {
    return _luminanceCache[filePath] ?? 0.5;
  }

  /// Clears the cached instances and luminance calculations.
  static void clearCache() {
    _uiImageCache.clear();
    _luminanceCache.clear();
  }
}
