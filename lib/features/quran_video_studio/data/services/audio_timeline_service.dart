import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class AudioTimelineItem {
  final int ayahNumber;
  final String audioPath;
  final Duration duration;
  final Duration startTime;
  final Duration endTime;

  const AudioTimelineItem({
    required this.ayahNumber,
    required this.audioPath,
    required this.duration,
    required this.startTime,
    required this.endTime,
  });
}

class AudioTimelineService {
  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  void cancel() {
    _cancelToken?.cancel('Cancelled by user');
    _cancelToken = null;
  }

  /// Downloads and caches all verse MP3s for a given reciter and verse range.
  Future<List<String>> prepareAudioFiles({
    required String reciterPath,
    required int surahNumber,
    required int startAyah,
    required int endAyah,
    void Function(double progress)? onProgress,
  }) async {
    final totalAyahs = endAyah - startAyah + 1;

    if (kIsWeb) {
      final List<String> webUrls = [];
      for (int i = 0; i < totalAyahs; i++) {
        final ayah = startAyah + i;
        final surahStr = surahNumber.toString().padLeft(3, '0');
        final ayahStr = ayah.toString().padLeft(3, '0');
        final url = 'https://everyayah.com/data/$reciterPath/$surahStr$ayahStr.mp3';
        webUrls.add(url);
        onProgress?.call((i + 1) / totalAyahs);
      }
      return webUrls;
    }

    _cancelToken = CancelToken();
    final tempDir = await getTemporaryDirectory();
    final audioDir = Directory('${tempDir.path}/video_studio_audio/$reciterPath');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final userDownloadedDir = Directory('${docsDir.path}/audio/$reciterPath');

    final List<String> localFilePaths = [];

    for (int i = 0; i < totalAyahs; i++) {
      if (_cancelToken?.isCancelled ?? false) {
        throw Exception('Audio preparation cancelled');
      }

      final ayah = startAyah + i;
      final verseId = surahNumber * 1000 + ayah;
      final userDownloadedFile = File('${userDownloadedDir.path}/$verseId.mp3');

      // Check if user already downloaded this verse in the Quran Reader
      if (await userDownloadedFile.exists() && await userDownloadedFile.length() > 0) {
        localFilePaths.add(userDownloadedFile.path);
        onProgress?.call((i + 1) / totalAyahs);
        continue;
      }

      final surahStr = surahNumber.toString().padLeft(3, '0');
      final ayahStr = ayah.toString().padLeft(3, '0');
      final url = 'https://everyayah.com/data/$reciterPath/$surahStr$ayahStr.mp3';
      final filePath = '${audioDir.path}/$surahStr$ayahStr.mp3';
      final file = File(filePath);

      if (!await file.exists() || await file.length() == 0) {
        await _dio.download(
          url,
          filePath,
          cancelToken: _cancelToken,
        );
      }

      localFilePaths.add(filePath);
      onProgress?.call((i + 1) / totalAyahs);
    }

    return localFilePaths;
  }

  /// Downloads and caches a single ayah audio MP3.
  Future<String?> getAyahAudioPath({
    required int surahNumber,
    required int ayahNumber,
    required String reciterPath,
  }) async {
    final surahStr = surahNumber.toString().padLeft(3, '0');
    final ayahStr = ayahNumber.toString().padLeft(3, '0');
    final url = 'https://everyayah.com/data/$reciterPath/$surahStr$ayahStr.mp3';

    if (kIsWeb) return url;

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final verseId = surahNumber * 1000 + ayahNumber;
      final userDownloadedFile = File('${docsDir.path}/audio/$reciterPath/$verseId.mp3');
      if (await userDownloadedFile.exists() && await userDownloadedFile.length() > 0) {
        return userDownloadedFile.path;
      }

      final tempDir = await getTemporaryDirectory();
      final audioDir = Directory('${tempDir.path}/video_studio_audio/$reciterPath');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }
      final filePath = '${audioDir.path}/$surahStr$ayahStr.mp3';
      final file = File(filePath);
      if (!await file.exists()) {
        await _dio.download(url, filePath, cancelToken: _cancelToken);
      }
      return filePath;
    } catch (_) {
      return null;
    }
  }

  static final Map<String, Duration> _durationCache = {};

  /// Measures exact duration of each audio file in parallel with in-memory caching
  /// for zero-jank instant response on both Web and Native platforms.
  Future<List<Duration>> measureDurations({
    required List<String> audioFilePaths,
  }) async {
    if (audioFilePaths.isEmpty) return [];

    final futures = audioFilePaths.map((path) async {
      if (_durationCache.containsKey(path) && _durationCache[path]! > Duration.zero) {
        return _durationCache[path]!;
      }

      Duration? d;
      final player = AudioPlayer();
      try {
        if (path.startsWith('http') || kIsWeb) {
          d = await player.setUrl(path).timeout(const Duration(seconds: 4));
          d ??= player.duration;
        } else {
          d = await player.setFilePath(path).timeout(const Duration(seconds: 3));
          d ??= player.duration;
        }
      } catch (_) {
        d = null;
      } finally {
        try {
          await player.dispose();
        } catch (_) {}
      }

      final resolved = (d != null && d > Duration.zero) ? d : const Duration(seconds: 4);
      _durationCache[path] = resolved;
      return resolved;
    });

    final results = await Future.wait(futures);
    return results;
  }

  /// Builds a sequential timeline with exact start and end timestamps per ayah.
  List<AudioTimelineItem> buildTimeline({
    required int startAyah,
    required List<String> audioFilePaths,
    required List<Duration> durations,
  }) {
    final List<AudioTimelineItem> items = [];
    Duration currentOffset = Duration.zero;

    for (int i = 0; i < audioFilePaths.length; i++) {
      if (i >= durations.length) {
        throw Exception('قائمة مدد الآيات غير مكتملة');
      }
      final duration = durations[i];
      final startTime = currentOffset;
      final endTime = startTime + duration;

      items.add(
        AudioTimelineItem(
          ayahNumber: startAyah + i,
          audioPath: audioFilePaths[i],
          duration: duration,
          startTime: startTime,
          endTime: endTime,
        ),
      );

      currentOffset = endTime;
    }

    return items;
  }
}
