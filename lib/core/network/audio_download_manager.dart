import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/quran_metadata.dart';
import '../constants/reciter_catalog.dart';
import '../../features/quran_audio/data/services/surah_audio_timing_service.dart';

class ActiveSurahDownloadTask {
  final String key;
  final CancelToken cancelToken;
  double progress;
  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  Stream<double> get progressStream => _progressController.stream;

  ActiveSurahDownloadTask({
    required this.key,
    required this.cancelToken,
    this.progress = 0.0,
  });
}

class AudioDownloadManager {
  final Dio _dio;
  final SurahAudioTimingService _timingService;
  final Future<Directory> Function()? _directoryProvider;

  // Cached total audio sizes per surah (bytes) to compute accurate progress
  final Map<String, int> _surahTotalSizes = {};

  // Centralized active ongoing surah download tasks across the app lifecycle
  static final Map<String, ActiveSurahDownloadTask> _activeSurahDownloads = {};

  static bool isSurahDownloadingStatic(
    String category,
    String reciterKey,
    int surah,
  ) =>
      _activeSurahDownloads.containsKey('$category|$reciterKey|$surah');

  bool isSurahDownloading(String category, String reciterKey, int surah) =>
      _activeSurahDownloads.containsKey(_surahKey(category, reciterKey, surah));

  double getActiveSurahDownloadProgress(
    String category,
    String reciterKey,
    int surah,
  ) =>
      _activeSurahDownloads[_surahKey(category, reciterKey, surah)]?.progress ??
      0.0;

  Stream<double>? getSurahDownloadProgressStream(
    String category,
    String reciterKey,
    int surah,
  ) =>
      _activeSurahDownloads[_surahKey(category, reciterKey, surah)]
          ?.progressStream;

  void cancelSurahDownload(String category, String reciterKey, int surah) {
    final key = _surahKey(category, reciterKey, surah);
    final task = _activeSurahDownloads[key];
    if (task != null) {
      if (!task.cancelToken.isCancelled) {
        task.cancelToken.cancel();
      }
      _activeSurahDownloads.remove(key);
    }
  }

  static CancelToken? _activeBatchCancelToken;
  static String? _activeBatchCategory;
  static String? _activeBatchReciter;
  static bool _isBatchRunning = false;

  static bool isBatchDownloadingStatic(String category, String reciterKey) =>
      _isBatchRunning &&
      _activeBatchCategory == category &&
      _activeBatchReciter == reciterKey;

  bool isBatchDownloading(String category, String reciterKey) =>
      _isBatchRunning &&
      _activeBatchCategory == category &&
      _activeBatchReciter == reciterKey;

  void cancelBatchDownload() {
    _activeBatchCancelToken?.cancel('Batch download cancelled');
    _activeBatchCancelToken = null;
    _isBatchRunning = false;
    _activeBatchCategory = null;
    _activeBatchReciter = null;
  }

  Future<void> startBatchDownload(
    String category,
    String reciterKey, {
    void Function(int surah, double progress)? onSurahProgress,
    void Function(bool success, int failedCount)? onCompleted,
  }) async {
    if (kIsWeb) {
      onCompleted?.call(false, 0);
      return;
    }
    if (_isBatchRunning) return;

    _isBatchRunning = true;
    _activeBatchCategory = category;
    _activeBatchReciter = reciterKey;
    final batchToken = CancelToken();
    _activeBatchCancelToken = batchToken;

    int failedCount = 0;
    try {
      for (int surah = 1; surah <= 114; surah++) {
        if (batchToken.isCancelled || !_isBatchRunning) break;

        final numAyahs = QuranMetadata.surahLengths[surah - 1];
        final isDownloaded = await isSurahDownloaded(
          category,
          reciterKey,
          surah,
          numAyahs,
        );
        if (isDownloaded) continue;

        try {
          await downloadSurah(
            category,
            reciterKey,
            surah,
            numAyahs,
            cancelToken: batchToken,
            onProgress: (p) => onSurahProgress?.call(surah, p),
          );
        } catch (e) {
          if (batchToken.isCancelled) break;
          failedCount++;
        }
      }
    } finally {
      final wasCancelled = batchToken.isCancelled;
      _isBatchRunning = false;
      _activeBatchCategory = null;
      _activeBatchReciter = null;
      _activeBatchCancelToken = null;
      onCompleted?.call(!wasCancelled, failedCount);
    }
  }

  String _surahKey(String category, String reciterKey, int surah) =>
      '$category|$reciterKey|$surah';

  AudioDownloadManager({
    Dio? dio,
    SurahAudioTimingService? timingService,
    this._directoryProvider,
  })  : _dio = dio ?? Dio(),
        _timingService = timingService ?? SurahAudioTimingService(dio: dio);

  // Active prefetch tasks to avoid duplicate downloads.
  // Keyed by category + reciter + verse: the same verseId exists under every
  // reciter directory with different bytes, so keying by verseId alone would
  // hand reciter B the file downloaded for reciter A.
  final Map<String, Future<String>> _activePrefetches = {};

  String _prefetchKey(String category, String reciterKey, int verseId) =>
      '$category|$reciterKey|$verseId';

  /// Grouped Mapping of recitation styles to backend paths
  static Map<String, Map<String, String>> get reciterCategories =>
      ReciterCatalog.reciterCategories;

  /// Helper to get the flat reciter path from any category
  static String getReciterPath(String categoryName, String reciterName) =>
      ReciterCatalog.getReciterPath(categoryName, reciterName);

  /// Returns the base directory for a specific reciter
  Future<String> getReciterDirectory(String category, String reciterKey) async {
    if (kIsWeb) return ''; // Not supported on web
    final Directory dir;
    final provider = _directoryProvider;
    if (provider != null) {
      dir = await provider();
    } else if (!kIsWeb && Platform.isWindows) {
      dir = await getApplicationSupportDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    final reciterPath = getReciterPath(category, reciterKey);
    final targetDir = Directory('${dir.path}/audio/$reciterPath');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir.path;
  }

  /// Returns the local path for a specific verse if it exists, otherwise null
  Future<String?> getLocalVersePath(
    String category,
    String reciterKey,
    int verseId,
  ) async {
    if (kIsWeb) return null;
    final dirPath = await getReciterDirectory(category, reciterKey);
    final file = File('$dirPath/$verseId.mp3');
    if (await file.exists() && (await file.length()) > 0) {
      return file.path;
    }
    // Backward-compatibility fallback for Windows: check previous documents location if not found in AppData
    if (Platform.isWindows && _directoryProvider == null) {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final reciterPath = getReciterPath(category, reciterKey);
        final legacyFile =
            File('${docsDir.path}/audio/$reciterPath/$verseId.mp3');
        if (await legacyFile.exists() && (await legacyFile.length()) > 0) {
          try {
            await legacyFile.copy(file.path);
            await legacyFile.delete();
            return file.path;
          } catch (_) {
            return legacyFile.path;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Returns the local path for a full surah audio file if it exists, otherwise null
  Future<String?> getLocalSurahPath(
    String category,
    String reciterKey,
    int surah,
  ) async {
    if (kIsWeb) return null;
    final dirPath = await getReciterDirectory(category, reciterKey);
    final surahStr = surah.toString().padLeft(3, '0');
    final file = File('$dirPath/$surahStr.mp3');
    if (await file.exists() && (await file.length()) > 0) {
      return file.path;
    }
    final fileAlt = File('$dirPath/$surah.mp3');
    if (await fileAlt.exists() && (await fileAlt.length()) > 0) {
      return fileAlt.path;
    }
    return null;
  }

  /// Retrieves or precaches a surah audio file into the local fast streaming cache.
  /// For short surahs (or already cached surahs), this eliminates audio stutter/discontinuity
  /// on ExoPlayer/Android by converting small remote HTTP streams into local FileDataSources.
  Future<String?> getOrPrecacheStreamingSurah({
    required String category,
    required String reciterKey,
    required int surahNumber,
    required String remoteUrl,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (kIsWeb) return null;

    // 1. Fast Bailout: Only genuinely tiny surahs (< 1.2 MB: Surah 1 and Surahs 90-114)
    // require pre-caching to eliminate ExoPlayer's EOF discontinuity race.
    // Medium and long surahs (Surahs 2-89, even those with <50 ayahs like Qaf or Al-Hujurat)
    // are 8-15 MB long; they stream directly via HTTP and start playback instantly (<1s)
    // while continuing to buffer seamlessly in the background.
    final isTinySurah =
        surahNumber == 1 || (surahNumber >= 90 && surahNumber <= 114);
    if (!isTinySurah) return null;

    File? tempFile;
    try {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.path.isEmpty || cacheDir.path == '.') return null;

      final streamingDir = Directory('${cacheDir.path}/streaming_cache');
      if (!await streamingDir.exists()) {
        await streamingDir.create(recursive: true);
      }

      final surahStr = surahNumber.toString().padLeft(3, '0');
      final recPath = getReciterPath(category, reciterKey);
      final sanitizedRec = recPath.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final cachedFilePath =
          '${streamingDir.path}/${sanitizedRec}_$surahStr.mp3';
      final cachedFile = File(cachedFilePath);

      // 2. If already cached and valid (>1KB), return immediately
      if (await cachedFile.exists() && (await cachedFile.length()) > 1024) {
        return cachedFilePath;
      }

      // 3. Isolated download with unique timestamp to prevent race collisions on rapid taps
      final tempSavePath =
          '$cachedFilePath.${DateTime.now().microsecondsSinceEpoch}.temp';
      tempFile = File(tempSavePath);

      await _dio.download(
        remoteUrl,
        tempSavePath,
        options: Options(
          receiveTimeout: timeout,
          sendTimeout: timeout,
        ),
      );

      if (await tempFile.exists()) {
        final len = await tempFile.length();
        if (len > 1024) {
          if (await cachedFile.exists()) {
            try {
              await cachedFile.delete();
            } catch (_) {}
          }
          await tempFile.rename(cachedFilePath);
          return cachedFilePath;
        } else {
          try {
            await tempFile.delete();
          } catch (_) {}
        }
      }
    } catch (_) {
      // Pre-cache failed or timed out; fall back seamlessly to remote streaming
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
    return null;
  }


  /// Constructs the EveryAyah backend URL for a verse or Basmalah.
  static String getEveryAyahUrl(
    String category,
    String reciterKey,
    int surah,
    int ayah,
  ) {
    final reciterPath = getReciterPath(category, reciterKey);

    // Basmalah for any reciter (represented as ayah == 0):
    if (ayah == 0) {
      return 'https://everyayah.com/data/$reciterPath/001001.mp3';
    }

    final surahStr = surah.toString().padLeft(3, '0');
    final ayahStr = ayah.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$reciterPath/$surahStr$ayahStr.mp3';
  }

  /// Returns the local path for a specific verse if it exists, otherwise null
  Future<String> getVerseAudioPath(
    String category,
    String reciterKey,
    int surah,
    int ayah,
  ) async {
    final url = getEveryAyahUrl(category, reciterKey, surah, ayah);

    if (kIsWeb) return url;

    final dirPath = await getReciterDirectory(category, reciterKey);
    final verseId = surah * 1000 + ayah;
    final savePath = '$dirPath/$verseId.mp3';
    final file = File(savePath);

    if (await file.exists() && (await file.length()) > 0) {
      return savePath;
    }

    return url;
  }

  /// Downloads a specific verse audio file
  Future<String> downloadVerse(
    String category,
    String reciterKey,
    int surah,
    int ayah,
    Function(double)? onProgress, {
    CancelToken? cancelToken,
  }) async {
    final url = getEveryAyahUrl(category, reciterKey, surah, ayah);

    if (kIsWeb) return url;

    final dirPath = await getReciterDirectory(category, reciterKey);
    final verseId = surah * 1000 + ayah;
    final savePath = '$dirPath/$verseId.mp3';
    final tempPath = '$savePath.temp';

    // If it already exists and is not a temp file, return
    final saveFile = File(savePath);
    if (await saveFile.exists() && (await saveFile.length()) > 0) {
      if (onProgress != null) onProgress(1.0);
      return savePath;
    }

    if (cancelToken?.isCancelled == true) {
      throw DioException(
        requestOptions: RequestOptions(path: url),
        type: DioExceptionType.cancel,
      );
    }

    // Check if we are already downloading this exact verse file
    final prefetchKey = _prefetchKey(category, reciterKey, verseId);
    if (_activePrefetches.containsKey(prefetchKey)) {
      final existing = await _activePrefetches[prefetchKey]!;
      // A background prefetch swallows its own errors into ''; never hand
      // that back as a path — fall through to a real download attempt below.
      if (existing.isNotEmpty) return existing;
    }

    // Register active download. Attach a silent error handler immediately so
    // a failure with no second waiter yet never surfaces as an unhandled
    // async error (Dart reports completeError futures without any listener).
    // Real waiters still receive the error normally through their own await.
    final completer = Completer<String>();
    _activePrefetches[prefetchKey] = completer.future;
    // ignore: discarded_futures
    _activePrefetches[prefetchKey]!.then((_) {}, onError: (_) {});

    try {
      await _dio.download(
        url,
        tempPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      // Rename temp file to actual file atomically
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.rename(savePath);
      }

      _activePrefetches.remove(prefetchKey);
      completer.complete(savePath);
      return savePath;
    } catch (e) {
      // Clean up partial temp file if download failed
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      _activePrefetches.remove(prefetchKey);
      completer.completeError(e);
      if (e is DioException && CancelToken.isCancel(e)) {
        rethrow;
      }
      throw Exception(
        'Failed to download audio for Surah $surah Ayah $ayah: $e',
      );
    }
  }

  /// Checks if an entire Surah is already downloaded locally
  Future<bool> isSurahDownloaded(
    String category,
    String reciterKey,
    int surah,
    int numAyahs,
  ) async {
    if (kIsWeb) return false;
    final path = await getLocalSurahPath(category, reciterKey, surah);
    return path != null;
  }

  /// Deletes all downloaded audio for a specific surah
  Future<void> deleteSurah(
    String category,
    String reciterKey,
    int surah,
    int numAyahs,
  ) async {
    if (kIsWeb) return;
    final dirPath = await getReciterDirectory(category, reciterKey);
    final surahStr = surah.toString().padLeft(3, '0');
    final file = File('$dirPath/$surahStr.mp3');
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    final tempFile = File('$dirPath/$surahStr.mp3.temp');
    if (await tempFile.exists()) {
      try {
        await tempFile.delete();
      } catch (_) {}
    }
    final fileAlt = File('$dirPath/$surah.mp3');
    if (await fileAlt.exists()) {
      try {
        await fileAlt.delete();
      } catch (_) {}
    }
    final tempFileAlt = File('$dirPath/$surah.mp3.temp');
    if (await tempFileAlt.exists()) {
      try {
        await tempFileAlt.delete();
      } catch (_) {}
    }
    _surahTotalSizes.remove(_surahKey(category, reciterKey, surah));

    // Clean up any matching streaming cache file
    try {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.path.isNotEmpty && cacheDir.path != '.') {
        final recPath = getReciterPath(category, reciterKey);
        final sanitizedRec = recPath.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final cachedFile = File(
            '${cacheDir.path}/streaming_cache/${sanitizedRec}_$surahStr.mp3');
        if (await cachedFile.exists()) {
          try {
            await cachedFile.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}

    // Backward-compatibility: delete legacy per-ayah files if any exist
    for (int ayah = 1; ayah <= numAyahs; ayah++) {
      final verseId = surah * 1000 + ayah;
      final verseFile = File('$dirPath/$verseId.mp3');
      if (await verseFile.exists()) {
        try {
          await verseFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Returns download progress for a surah (0.0 to 1.0).
  Future<double> getSurahDownloadProgress(
    String category,
    String reciterKey,
    int surah,
    int numAyahs,
  ) async {
    if (kIsWeb) return 0.0;
    final path = await getLocalSurahPath(category, reciterKey, surah);
    if (path != null) return 1.0;

    final dirPath = await getReciterDirectory(category, reciterKey);
    final surahStr = surah.toString().padLeft(3, '0');
    final tempFile = File('$dirPath/$surahStr.mp3.temp');
    if (await tempFile.exists()) {
      final tempLen = await tempFile.length();
      if (tempLen > 0) {
        final cacheKey = _surahKey(category, reciterKey, surah);
        int? total = _surahTotalSizes[cacheKey];
        if (total == null || total <= 0) {
          try {
            final reciterPath = getReciterPath(category, reciterKey);
            final timings = await _timingService.getSurahTimings(
              reciterPath: reciterPath,
              surahNumber: surah,
            );
            if (timings != null && timings.audioUrl.isNotEmpty) {
              final headRes = await _dio.head<void>(
                timings.audioUrl,
                options: Options(
                  validateStatus: (s) => s != null && s < 400,
                  sendTimeout: const Duration(seconds: 4),
                  receiveTimeout: const Duration(seconds: 4),
                ),
              );
              final cl = headRes.headers.value(Headers.contentLengthHeader);
              if (cl != null) {
                total = int.tryParse(cl);
                if (total != null && total > 0) {
                  _surahTotalSizes[cacheKey] = total;
                }
              }
            }
          } catch (_) {}
        }
        if (total != null && total > 0) {
          return (tempLen / total).clamp(0.01, 0.99);
        }
        return 0.05;
      }
    }
    return 0.0;
  }

  /// Downloads an entire Surah as a single continuous audio stream matching SurahAudioTimingService.
  /// Supports resuming partial downloads from disk using HTTP Range headers.
  Future<void> downloadSurah(
    String category,
    String reciterKey,
    int surah,
    int numAyahs, {
    Function(double)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (kIsWeb) return;

    final dirPath = await getReciterDirectory(category, reciterKey);
    final surahStr = surah.toString().padLeft(3, '0');
    final savePath = '$dirPath/$surahStr.mp3';
    final tempPath = '$savePath.temp';

    // 1. If already completely downloaded, NEVER re-download!
    final saveFile = File(savePath);
    if (await saveFile.exists() && (await saveFile.length()) > 0) {
      if (onProgress != null) onProgress(1.0);
      return;
    }

    final cacheKey = _surahKey(category, reciterKey, surah);

    // If already downloading in background, attach listener and wait
    if (_activeSurahDownloads.containsKey(cacheKey)) {
      final existingTask = _activeSurahDownloads[cacheKey]!;
      if (onProgress != null) {
        onProgress(existingTask.progress);
        final sub = existingTask.progressStream.listen(onProgress);
        try {
          await existingTask.progressStream.last;
        } catch (_) {}
        await sub.cancel();
      }
      return;
    }

    final effectiveCancelToken = cancelToken ?? CancelToken();
    if (effectiveCancelToken.isCancelled) {
      throw DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.cancel,
      );
    }

    final task = ActiveSurahDownloadTask(
      key: cacheKey,
      cancelToken: effectiveCancelToken,
    );
    _activeSurahDownloads[cacheKey] = task;

    void notifyProgress(double p) {
      task.progress = p;
      if (!task._progressController.isClosed) {
        task._progressController.add(p);
      }
      onProgress?.call(p);
    }

    try {
      final reciterPath = getReciterPath(category, reciterKey);
      final timings = await _timingService.getSurahTimings(
        reciterPath: reciterPath,
        surahNumber: surah,
      );

      if (timings == null || timings.audioUrl.isEmpty) {
        throw Exception(
          'Audio stream URL not found for Surah $surah ($reciterPath)',
        );
      }

      final url = timings.audioUrl;
      final tempFile = File(tempPath);
      int existingBytes = 0;
      if (await tempFile.exists()) {
        existingBytes = await tempFile.length();
      }

      Response<ResponseBody> response;
      try {
        response = await _dio.get<ResponseBody>(
          url,
          options: Options(
            responseType: ResponseType.stream,
            headers:
                existingBytes > 0 ? {'Range': 'bytes=$existingBytes-'} : null,
            validateStatus: (status) =>
                status != null &&
                ((status >= 200 && status < 300) || status == 416),
          ),
          cancelToken: effectiveCancelToken,
        );
      } catch (e) {
        if (e is DioException && CancelToken.isCancel(e)) {
          rethrow;
        }
        throw Exception('Failed to download audio for Surah $surah: $e');
      }

      // If server responded with 416 (Range Not Satisfiable), existing bytes are invalid/corrupt.
      if (response.statusCode == 416) {
        if (await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) {}
        }
        existingBytes = 0;
        try {
          response = await _dio.get<ResponseBody>(
            url,
            options: Options(
              responseType: ResponseType.stream,
              validateStatus: (status) =>
                  status != null && (status >= 200 && status < 300),
            ),
            cancelToken: effectiveCancelToken,
          );
        } catch (e) {
          if (e is DioException && CancelToken.isCancel(e)) {
            rethrow;
          }
          throw Exception('Failed to restart download for Surah $surah: $e');
        }
      }

      final isPartial = response.statusCode == 206;
      int totalBytes = 0;

      if (isPartial) {
        final contentRange = response.headers.value('content-range');
        if (contentRange != null) {
          final match = RegExp(r'/(\d+)').firstMatch(contentRange);
          if (match != null) {
            totalBytes = int.tryParse(match.group(1)!) ?? 0;
          }
        }
        if (totalBytes <= 0) {
          final cl = response.data?.contentLength ?? -1;
          if (cl > 0) {
            totalBytes = existingBytes + cl;
          } else if (_surahTotalSizes.containsKey(cacheKey)) {
            totalBytes = _surahTotalSizes[cacheKey]!;
          }
        }
      } else {
        // Full content from byte 0
        existingBytes = 0;
        final cl = response.data?.contentLength ?? -1;
        if (cl > 0) {
          totalBytes = cl;
        }
      }

      if (totalBytes > 0) {
        _surahTotalSizes[cacheKey] = totalBytes;
      }

      IOSink? sink;
      try {
        sink = tempFile.openWrite(
          mode: isPartial && existingBytes > 0 ? FileMode.append : FileMode.write,
        );

        int currentBytes = isPartial ? existingBytes : 0;
        if (totalBytes > 0) {
          notifyProgress((currentBytes / totalBytes).clamp(0.0, 1.0));
        }

        final stream = response.data!.stream;
        await for (final chunk in stream) {
          if (effectiveCancelToken.isCancelled) {
            throw DioException(
              requestOptions: RequestOptions(path: url),
              type: DioExceptionType.cancel,
            );
          }
          sink.add(chunk);
          currentBytes += chunk.length;
          if (totalBytes > 0) {
            notifyProgress((currentBytes / totalBytes).clamp(0.0, 1.0));
          }
        }

        await sink.flush();
        await sink.close();
        sink = null;

        if (await tempFile.exists()) {
          await tempFile.rename(savePath);
        }
        notifyProgress(1.0);
      } catch (e) {
        if (sink != null) {
          try {
            await sink.flush();
            await sink.close();
          } catch (_) {}
        }
        // CRITICAL: Preserve tempFile so user can resume download anytime!
        if (e is DioException && CancelToken.isCancel(e)) {
          rethrow;
        }
        throw Exception('Failed to download audio for Surah $surah: $e');
      }
    } finally {
      _activeSurahDownloads.remove(cacheKey);
      if (!task._progressController.isClosed) {
        task._progressController.close();
      }
    }
  }

  /// Automatically caches a surah audio stream in the background when played.
  /// Runs completely silently without interrupting playback or throwing unhandled errors.
  Future<void> autoCacheSurah(
    String category,
    String reciterKey,
    int surah,
  ) async {
    if (kIsWeb) return;
    try {
      final isDownloaded = await isSurahDownloaded(category, reciterKey, surah, 0);
      if (isDownloaded) return;

      final prefetchKey = 'surah_cache|$category|$reciterKey|$surah';
      if (_activePrefetches.containsKey(prefetchKey)) {
        await _activePrefetches[prefetchKey];
        return;
      }

      final completer = Completer<String>();
      _activePrefetches[prefetchKey] = completer.future;

      try {
        final numAyahs = QuranMetadata.surahLengthOf(surah);
        await downloadSurah(category, reciterKey, surah, numAyahs);
        completer.complete('');
      } catch (_) {
        completer.complete('');
      } finally {
        _activePrefetches.remove(prefetchKey);
      }
    } catch (_) {}
  }

  /// Constructs the streaming URL for a verse
  String getStreamingUrl(
    String category,
    String reciterKey,
    int surah,
    int ayah,
  ) {
    return getEveryAyahUrl(category, reciterKey, surah, ayah);
  }

  /// Predictive Prefetching Queue Engine (Anti-Stuttering)
  /// Instantly fires background downloads for N+1, N+2...
  Future<void> prefetchVerses(
    String category,
    String reciterKey,
    int currentSurah,
    int currentAyah, {
    int lookaheadCount = 3,
  }) async {
    if (kIsWeb) return;
    int surah = currentSurah;
    int ayah = currentAyah;

    for (int i = 0; i < lookaheadCount; i++) {
      ayah++;

      // Use QuranMetadata for accurate bound checking
      final maxAyah = QuranMetadata.surahLengthOf(surah);
      if (ayah > maxAyah) {
        surah++;
        ayah = 1;
      }
      if (surah > 114) break;

      final verseId = surah * 1000 + ayah;
      final prefetchKey = _prefetchKey(category, reciterKey, verseId);

      // If we are already prefetching this verse, skip
      if (_activePrefetches.containsKey(prefetchKey)) continue;

      // Check if file already exists locally
      final localPath = await getLocalVersePath(category, reciterKey, verseId);
      if (localPath != null) continue;

      // Launch background download task and catch errors silently since it's just prefetching
      final downloadTask =
          downloadVerse(
            category,
            reciterKey,
            surah,
            ayah,
            null,
          ).catchError((_) => '').whenComplete(() {
            _activePrefetches.remove(prefetchKey);
          });

      _activePrefetches[prefetchKey] = downloadTask;
    }
  }
}
