import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../../../core/utils/desktop_file_picker_helper.dart';

/// Helper service for picking and downloading custom background images.
class CustomImageService {
  const CustomImageService._();

  static final Map<String, ui.Image> _uiImageCache = {};
  static final Map<String, double> _luminanceCache = {};
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      headers: {
        if (!kIsWeb)
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    ),
  );

  /// Picks an image from the device gallery or native file system.
  static Future<String?> pickImageFromGallery() async {
    try {
      // On Desktop (Windows, macOS, Linux), use native file_selector directly to bypass mobile ImagePicker wrappers
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        try {
          const typeGroup = fs.XTypeGroup(
            label: 'Images',
            extensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
          );
          final file = await fs.openFile(acceptedTypeGroups: [typeGroup]);
          if (Platform.isWindows) {
            try {
              await windowManager.focus();
            } catch (_) {}
          }
          return file != null ? p.normalize(file.path) : null;
        } catch (e) {
          debugPrint('file_selector openFile failed: $e');
          if (Platform.isWindows) {
            final fallback = await DesktopFilePickerHelper.pickFileWindows(
              filter:
                  'Image Files (*.jpg;*.jpeg;*.png;*.webp;*.bmp)|*.jpg;*.jpeg;*.png;*.webp;*.bmp|All Files (*.*)|*.*',
              title: 'اختر صورة خلفية',
            );
            return fallback != null ? p.normalize(fallback) : null;
          }
          return null;
        }
      }

      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 3840,
        maxHeight: 3840,
        imageQuality: 95,
      );
      if (pickedFile == null) return null;

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        _evictOldestIfFull();
        _uiImageCache[pickedFile.path] = frame.image;
        return pickedFile.path;
      }

      return pickedFile.path;
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

    _evictOldestIfFull();

    if (kIsWeb) {
      _uiImageCache[cleanUrl] = image;
      return cleanUrl;
    }

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
      final cached = _uiImageCache[filePath];
      if (cached != null) return cached;
    }

    try {
      if (kIsWeb ||
          filePath.startsWith('http://') ||
          filePath.startsWith('https://') ||
          filePath.startsWith('blob:')) {
        final response = await _dio.get<List<int>>(
          filePath,
          options: Options(responseType: ResponseType.bytes),
        );
        if (response.data != null) {
          final bytes = Uint8List.fromList(response.data!);
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          final image = frame.image;
          _evictOldestIfFull();
          _uiImageCache[filePath] = image;
          return image;
        }
        return null;
      }

      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      _evictOldestIfFull();
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

  /// Calculates the relative perceived luminance (0.0 = pitch black, 1.0 = pure white) of a local image.
  /// Uses a tiny 40x40 thumbnail decode to eliminate high-resolution GPU readback memory overhead.
  static Future<double> calculateImageLuminance(String filePath) async {
    if (_luminanceCache.containsKey(filePath)) {
      return _luminanceCache[filePath]!;
    }

    try {
      Uint8List? bytes;
      if (kIsWeb ||
          filePath.startsWith('http://') ||
          filePath.startsWith('https://') ||
          filePath.startsWith('blob:')) {
        final response = await _dio.get<List<int>>(
          filePath,
          options: Options(responseType: ResponseType.bytes),
        );
        if (response.data != null) {
          bytes = Uint8List.fromList(response.data!);
        }
      } else {
        final file = File(filePath);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) return 0.5;

      // Decode a small 40x40 thumbnail specifically for ultra-fast, zero-overhead luminance calculation
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 40,
        targetHeight: 40,
      );
      final frame = await codec.getNextFrame();
      final thumbImage = frame.image;

      final byteData =
          await thumbImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      thumbImage.dispose();

      if (byteData == null) return 0.5;
      final rawBytes = byteData.buffer.asUint8List();
      if (rawBytes.isEmpty) return 0.5;

      int totalLuminance = 0;
      int sampleCount = 0;
      for (int i = 0; i < rawBytes.length - 3; i += 4) {
        final r = rawBytes[i];
        final g = rawBytes[i + 1];
        final b = rawBytes[i + 2];
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

  static String? _activeImagePath;

  /// Sets the currently active background image path to protect it from cache eviction.
  static void setActiveImagePath(String? path) {
    _activeImagePath = path;
  }

  /// Clears the cached instances and luminance calculations, disposing GPU resources.
  static void clearCache() {
    for (final img in _uiImageCache.values) {
      try {
        img.dispose();
      } catch (_) {}
    }
    _uiImageCache.clear();
    _luminanceCache.clear();
    _activeImagePath = null;
  }

  static void _evictOldestIfFull() {
    if (_uiImageCache.length >= 16) {
      String? keyToEvict;
      for (final key in _uiImageCache.keys) {
        if (key != _activeImagePath) {
          keyToEvict = key;
          break;
        }
      }
      if (keyToEvict != null) {
        final oldImage = _uiImageCache.remove(keyToEvict);
        try {
          oldImage?.dispose();
        } catch (_) {}
        _luminanceCache.remove(keyToEvict);
      }
    }
  }
}
