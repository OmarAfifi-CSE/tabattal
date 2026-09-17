import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/reciter_catalog.dart';
import '../../../quran_audio/data/services/surah_audio_timing_service.dart';
import 'mp3_duration_parser.dart';

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
  final Dio _dio;
  final SurahAudioTimingService _timingService;
  CancelToken? _cancelToken;

  AudioTimelineService({
    Dio? dio,
    SurahAudioTimingService? timingService,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
              ),
            ),
        _timingService = timingService ?? SurahAudioTimingService(dio: dio);

  void cancel() {
    _cancelToken?.cancel('Cancelled by user');
    _cancelToken = null;
  }

  /// Extracts missing individual ayah files from an already downloaded local surah audio file using FFmpegKit.
  Future<void> _extractAyahsFromLocalSurah({
    required String reciterPath,
    required int surahNumber,
    required List<int> missingAyahs,
    required Directory audioDir,
    required Directory userDownloadedDir,
  }) async {
    if (missingAyahs.isEmpty) return;

    final surahStr = surahNumber.toString().padLeft(3, '0');
    File? fullSurahFile;

    // Check user downloaded surah file on disk
    final primaryFile = File('${userDownloadedDir.path}/$surahStr.mp3');
    final altFile = File('${userDownloadedDir.path}/$surahNumber.mp3');
    if (await primaryFile.exists() && await primaryFile.length() > 0) {
      fullSurahFile = primaryFile;
    } else if (await altFile.exists() && await altFile.length() > 0) {
      fullSurahFile = altFile;
    }

    // Windows legacy fallback check
    if (fullSurahFile == null && !kIsWeb && Platform.isWindows) {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final legacyFile = File('${docsDir.path}/audio/$reciterPath/$surahStr.mp3');
        final legacyAlt = File('${docsDir.path}/audio/$reciterPath/$surahNumber.mp3');
        if (await legacyFile.exists() && await legacyFile.length() > 0) {
          fullSurahFile = legacyFile;
        } else if (await legacyAlt.exists() && await legacyAlt.length() > 0) {
          fullSurahFile = legacyAlt;
        }
      } catch (_) {}
    }

    if (fullSurahFile == null) {
      throw Exception('السورة غير محملة محليًا على الجهاز للقارئ المحدد');
    }

    final timings = await _timingService.getSurahTimings(
      reciterPath: reciterPath,
      surahNumber: surahNumber,
    );

    if (timings == null || timings.verseTimings.isEmpty) {
      throw Exception('تعذر الحصول على توقيتات الآيات للقارئ المحدد');
    }

    for (final ayah in missingAyahs) {
      if (_cancelToken?.isCancelled ?? false) break;
      final vt = timings.getVerse(ayah);
      if (vt == null) continue;

      final ayahStr = ayah.toString().padLeft(3, '0');
      final targetPath = '${audioDir.path}/$surahStr$ayahStr.mp3';
      final targetFile = File(targetPath);
      if (await targetFile.exists() && await targetFile.length() > 0) continue;

      final startSec = (vt.start.inMilliseconds / 1000.0).toStringAsFixed(3);
      final toSec = (vt.end.inMilliseconds / 1000.0).toStringAsFixed(3);

      final sessionCompleter = Completer<void>();
      await FFmpegKit.executeWithArgumentsAsync([
        '-y',
        '-i',
        fullSurahFile.path,
        '-ss',
        startSec,
        '-to',
        toSec,
        '-c',
        'copy',
        targetPath,
      ], (session) {
        if (!sessionCompleter.isCompleted) {
          sessionCompleter.complete();
        }
      });
      await sessionCompleter.future;
    }
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

    final Directory readerBaseDir;
    if (!kIsWeb && Platform.isWindows) {
      readerBaseDir = await getApplicationSupportDirectory();
    } else {
      readerBaseDir = await getApplicationDocumentsDirectory();
    }
    final userDownloadedDir = Directory('${readerBaseDir.path}/audio/$reciterPath');

    final Map<int, String> verseFilePaths = {};
    final List<int> missingAyahs = [];

    for (int i = 0; i < totalAyahs; i++) {
      if (_cancelToken?.isCancelled ?? false) {
        throw Exception('Audio preparation cancelled');
      }

      final ayah = startAyah + i;
      final verseId = surahNumber * 1000 + ayah;

      // 1. Check if user already downloaded this verse in the Quran Reader
      final userDownloadedFile = File('${userDownloadedDir.path}/$verseId.mp3');
      if (await userDownloadedFile.exists() && await userDownloadedFile.length() > 0) {
        verseFilePaths[ayah] = userDownloadedFile.path;
        onProgress?.call((verseFilePaths.length) / totalAyahs);
        continue;
      }

      final surahStr = surahNumber.toString().padLeft(3, '0');
      final ayahStr = ayah.toString().padLeft(3, '0');
      final filePath = '${audioDir.path}/$surahStr$ayahStr.mp3';
      final file = File(filePath);

      // 2. Check if already extracted/cached locally
      if (await file.exists() && await file.length() > 0) {
        verseFilePaths[ayah] = filePath;
        onProgress?.call((verseFilePaths.length) / totalAyahs);
        continue;
      }

      missingAyahs.add(ayah);
    }

    if (missingAyahs.isNotEmpty) {
      if (!ReciterCatalog.isMp3QuranReciter(reciterPath)) {
        // Standard EveryAyah reciters: download only the exact requested verses directly
        for (final ayah in missingAyahs) {
          if (_cancelToken?.isCancelled ?? false) {
            throw Exception('Audio preparation cancelled');
          }
          final surahStr = surahNumber.toString().padLeft(3, '0');
          final ayahStr = ayah.toString().padLeft(3, '0');
          final filePath = '${audioDir.path}/$surahStr$ayahStr.mp3';
          final url = 'https://everyayah.com/data/$reciterPath/$surahStr$ayahStr.mp3';
          await _dio.download(
            url,
            filePath,
            cancelToken: _cancelToken,
          );
          verseFilePaths[ayah] = filePath;
          onProgress?.call(verseFilePaths.length / totalAyahs);
        }
      } else {
        // MP3Quran reciters: ONLY extract from the locally downloaded full surah file!
        await _extractAyahsFromLocalSurah(
          reciterPath: reciterPath,
          surahNumber: surahNumber,
          missingAyahs: missingAyahs,
          audioDir: audioDir,
          userDownloadedDir: userDownloadedDir,
        );

        for (final ayah in missingAyahs) {
          final surahStr = surahNumber.toString().padLeft(3, '0');
          final ayahStr = ayah.toString().padLeft(3, '0');
          final filePath = '${audioDir.path}/$surahStr$ayahStr.mp3';
          final file = File(filePath);
          if (await file.exists() && await file.length() > 0) {
            verseFilePaths[ayah] = filePath;
          }
        }
      }
    }

    final List<String> orderedFilePaths = [];
    for (int i = 0; i < totalAyahs; i++) {
      final ayah = startAyah + i;
      final path = verseFilePaths[ayah];
      if (path != null) {
        orderedFilePaths.add(path);
      }
    }
    return orderedFilePaths;
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
      final Directory readerBaseDir;
      if (!kIsWeb && Platform.isWindows) {
        readerBaseDir = await getApplicationSupportDirectory();
      } else {
        readerBaseDir = await getApplicationDocumentsDirectory();
      }
      final userDownloadedDir = Directory('${readerBaseDir.path}/audio/$reciterPath');
      final verseId = surahNumber * 1000 + ayahNumber;
      final userDownloadedFile = File('${userDownloadedDir.path}/$verseId.mp3');
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

      // 1. Check if already extracted locally
      if (await file.exists() && await file.length() > 0) {
        return filePath;
      }

      // 2. Direct download for EveryAyah reciters
      if (!ReciterCatalog.isMp3QuranReciter(reciterPath)) {
        await _dio.download(url, filePath, cancelToken: _cancelToken);
        if (await file.exists() && await file.length() > 0) {
          return filePath;
        }
      } else {
        // 3. Extract only from local surah file if downloaded
        await _extractAyahsFromLocalSurah(
          reciterPath: reciterPath,
          surahNumber: surahNumber,
          missingAyahs: [ayahNumber],
          audioDir: audioDir,
          userDownloadedDir: userDownloadedDir,
        );
        if (await file.exists() && await file.length() > 0) {
          return filePath;
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static final Map<String, Duration> _durationCache = {};

  /// Clears in-memory duration cache (useful for cache eviction and test isolation).
  static void clearDurationCache() {
    _durationCache.clear();
  }

  /// Measures exact duration of each audio file with in-memory caching
  /// for zero-jank instant response on both Web and Native platforms.
  ///
  /// Uses pure Dart MP3 parsing on local files to completely avoid native audio
  /// player instantiation, eliminating WinRT use-after-free and thread collisions.
  Future<List<Duration>> measureDurations({
    required List<String> audioFilePaths,
    int? firstAyahNumber,
  }) async {
    if (audioFilePaths.isEmpty) return [];

    // The paths are always ordered as startAyah..endAyah; the first index maps
    // to the real surah ayah number so failure messages never mislead the user.
    int ayahNumberAt(int idx) => (firstAyahNumber ?? 1) + idx;

    final List<Duration> results = List.filled(audioFilePaths.length, Duration.zero);
    final List<int> unmeasuredIndices = [];

    for (int i = 0; i < audioFilePaths.length; i++) {
      final path = audioFilePaths[i];
      if (_durationCache.containsKey(path) && _durationCache[path]! > Duration.zero) {
        results[i] = _durationCache[path]!;
        continue;
      }

      // 1. On non-web platforms, try the high-speed pure Dart MP3 parser first.
      // This bypasses native audio engine instantiation completely, eliminating
      // WinRT thread-contention and use-after-free access violations during rapid probing.
      if (!kIsWeb && !path.startsWith('http')) {
        final parsed = Mp3DurationParser.parse(File(path));
        if (parsed != null && parsed > Duration.zero) {
          _durationCache[path] = parsed;
          results[i] = parsed;
          continue;
        }
      }

      unmeasuredIndices.add(i);
    }

    if (unmeasuredIndices.isEmpty) {
      return results;
    }

    // 2. Web: probe all URLs in PARALLEL with one short-lived player per URL.
    // Sequential probing through a shared player is only needed on Windows to
    // avoid WinRT thread contention; on the web it multiplied every reciter /
    // verse-range load latency by the verse count (up to 4s per ayah), during
    // which any user interaction replayed or cancelled the pending load.
    if (kIsWeb) {
      await Future.wait(unmeasuredIndices.map((idx) async {
        final path = audioFilePaths[idx];
        final player = AudioPlayer();
        Duration? d;
        try {
          d = await player.setUrl(path).timeout(const Duration(seconds: 4));
          d ??= player.duration;
        } catch (_) {
          d = null;
        } finally {
          try {
            await player.dispose();
          } catch (_) {}
        }

        if (d != null && d > Duration.zero) {
          _durationCache[path] = d;
          results[idx] = d;
        } else {
          throw Exception(
            'تعذر قياس مدة المقطع الصوتي بدقة للآية ${ayahNumberAt(idx)}. يُرجى التحقق من الاتصال بالإنترنت أو توفر الملف الصوتي.',
          );
        }
      }));
      return results;
    }

    // 3. Safe sequential fallback for Windows native URLs or non-standard
    // formats. By using a single player sequentially, we avoid the WinRT /
    // native thread contention crash caused by concurrent player instances.
    final player = AudioPlayer();
    try {
      for (final idx in unmeasuredIndices) {
        final path = audioFilePaths[idx];
        Duration? d;
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
        }

        if (d != null && d > Duration.zero) {
          _durationCache[path] = d;
          results[idx] = d;
        } else {
          throw Exception(
            'تعذر قياس مدة المقطع الصوتي بدقة للآية ${ayahNumberAt(idx)}. يُرجى التحقق من الملف الصوتي أو الاتصال بالإنترنت.',
          );
        }
      }
    } finally {
      try {
        await player.dispose();
      } catch (_) {}
    }

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
