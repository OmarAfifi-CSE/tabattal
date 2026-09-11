import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabattal/core/network/audio_download_manager.dart';
import 'package:tabattal/features/quran_audio/data/models/surah_timing_model.dart';
import 'package:tabattal/features/quran_audio/data/services/surah_audio_timing_service.dart';

class _FakeTimingService extends Fake implements SurahAudioTimingService {
  final String audioUrl = 'https://example.com/audio/001.mp3';

  @override
  Future<SurahTimings?> getSurahTimings({
    required String reciterPath,
    required int surahNumber,
  }) async {
    return SurahTimings(
      surah: surahNumber,
      audioUrl: audioUrl,
      verseTimings: const [],
    );
  }
}

class _TestHttpAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  _TestHttpAdapter(this.onFetch);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return onFetch(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Dio dio;
  late _FakeTimingService timingService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('download_mgr_test_');
    dio = Dio();
    timingService = _FakeTimingService();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AudioDownloadManager - Local File & Download Protection Tests', () {
    test('getLocalSurahPath and isSurahDownloaded ignore empty 0-byte files', () async {
      final manager = AudioDownloadManager(
        dio: dio,
        timingService: timingService,
        directoryProvider: () async => tempDir,
      );

      final reciterDir = await manager.getReciterDirectory('Murattal', 'Minshawy');
      final zeroByteFile = File('$reciterDir/001.mp3');
      await zeroByteFile.writeAsBytes([]);

      expect(await manager.getLocalSurahPath('Murattal', 'Minshawy', 1), isNull);
      expect(await manager.isSurahDownloaded('Murattal', 'Minshawy', 1, 7), isFalse);

      // Now write actual data
      await zeroByteFile.writeAsBytes([1, 2, 3, 4]);
      expect(await manager.getLocalSurahPath('Murattal', 'Minshawy', 1), zeroByteFile.path);
      expect(await manager.isSurahDownloaded('Murattal', 'Minshawy', 1, 7), isTrue);
    });

    test('downloadSurah never re-downloads if file already exists with length > 0', () async {
      int fetchCalls = 0;
      dio.httpClientAdapter = _TestHttpAdapter((options) async {
        fetchCalls++;
        return ResponseBody.fromBytes(Uint8List(100), 200);
      });

      final manager = AudioDownloadManager(
        dio: dio,
        timingService: timingService,
        directoryProvider: () async => tempDir,
      );

      final reciterDir = await manager.getReciterDirectory('Murattal', 'Minshawy');
      final completedFile = File('$reciterDir/001.mp3');
      await completedFile.writeAsBytes(List.filled(200, 1));

      double reportedProgress = 0.0;
      await manager.downloadSurah(
        'Murattal',
        'Minshawy',
        1,
        7,
        onProgress: (p) => reportedProgress = p,
      );

      expect(fetchCalls, 0, reason: 'Must not call HTTP when file is already downloaded');
      expect(reportedProgress, 1.0);
    });
  });

  group('AudioDownloadManager - Resumable Download & Range Header Tests', () {
    test('downloadSurah resumes partial download from disk via HTTP Range header', () async {
      final manager = AudioDownloadManager(
        dio: dio,
        timingService: timingService,
        directoryProvider: () async => tempDir,
      );

      final reciterDir = await manager.getReciterDirectory('Murattal', 'Minshawy');
      final tempFile = File('$reciterDir/001.mp3.temp');
      // Create initial 50 bytes
      await tempFile.writeAsBytes(List.generate(50, (i) => i));

      RequestOptions? recordedOptions;
      dio.httpClientAdapter = _TestHttpAdapter((options) async {
        recordedOptions = options;
        // Verify Range header
        if (options.headers['Range'] == 'bytes=50-') {
          return ResponseBody.fromBytes(
            Uint8List.fromList(List.generate(50, (i) => i + 50)),
            206,
            headers: {
              'content-range': ['bytes 50-99/100'],
              Headers.contentLengthHeader: ['50'],
            },
          );
        }
        return ResponseBody.fromBytes(Uint8List(100), 200);
      });

      final recordedProgress = <double>[];
      await manager.downloadSurah(
        'Murattal',
        'Minshawy',
        1,
        7,
        onProgress: (p) => recordedProgress.add(p),
      );

      expect(recordedOptions?.headers['Range'], 'bytes=50-');
      final finalFile = File('$reciterDir/001.mp3');
      expect(await finalFile.exists(), isTrue);
      expect(await finalFile.length(), 100);
      expect(await tempFile.exists(), isFalse, reason: 'Temp file must be renamed to final file');
      expect(recordedProgress.last, 1.0);
    });

    test('downloadSurah preserves partial temp file on failure or pause', () async {
      final manager = AudioDownloadManager(
        dio: dio,
        timingService: timingService,
        directoryProvider: () async => tempDir,
      );

      final reciterDir = await manager.getReciterDirectory('Murattal', 'Minshawy');
      final tempFile = File('$reciterDir/001.mp3.temp');
      await tempFile.writeAsBytes(List.generate(30, (i) => i));

      dio.httpClientAdapter = _TestHttpAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );
      });

      expect(
        () => manager.downloadSurah('Murattal', 'Minshawy', 1, 7),
        throwsA(isA<Exception>()),
      );

      // Verify tempFile is PRESERVED, not deleted
      expect(await tempFile.exists(), isTrue);
      expect(await tempFile.length(), 30);
    });

    test('deleteSurah deletes both .mp3 and .mp3.temp', () async {
      final manager = AudioDownloadManager(
        dio: dio,
        timingService: timingService,
        directoryProvider: () async => tempDir,
      );

      final reciterDir = await manager.getReciterDirectory('Murattal', 'Minshawy');
      final file = File('$reciterDir/001.mp3');
      final tempFile = File('$reciterDir/001.mp3.temp');
      await file.writeAsBytes([1, 2]);
      await tempFile.writeAsBytes([3, 4]);

      await manager.deleteSurah('Murattal', 'Minshawy', 1, 7);

      expect(await file.exists(), isFalse);
      expect(await tempFile.exists(), isFalse);
    });

    test('autoCacheSurah silently downloads surah in background if not downloaded', () async {
      final manager = AudioDownloadManager(
        dio: dio,
        timingService: timingService,
        directoryProvider: () async => tempDir,
      );

      dio.httpClientAdapter = _TestHttpAdapter((options) async {
        return ResponseBody.fromBytes(Uint8List(200), 200);
      });

      await manager.autoCacheSurah('Murattal', 'Minshawy', 1);

      final reciterDir = await manager.getReciterDirectory('Murattal', 'Minshawy');
      final finalFile = File('$reciterDir/001.mp3');
      expect(await finalFile.exists(), isTrue);
      expect(await finalFile.length(), 200);
    });

    test('getDownloadedSurahReciterPaths detects downloaded MP3Quran surahs efficiently', () async {
      final manager = AudioDownloadManager(
        dio: dio,
        timingService: timingService,
        directoryProvider: () async => tempDir,
      );

      // Initially empty
      final initial = await manager.getDownloadedSurahReciterPaths(1);
      expect(initial, isEmpty);

      // Create a downloaded surah for an MP3Quran reciter
      final reciterDir = Directory('${tempDir.path}/audio/mp3quran_test_reciter');
      await reciterDir.create(recursive: true);
      final surahFile = File('${reciterDir.path}/001.mp3');
      await surahFile.writeAsBytes([1, 2, 3]);

      // Create an empty file (0 bytes) for another surah
      final emptySurahFile = File('${reciterDir.path}/002.mp3');
      await emptySurahFile.writeAsBytes([]);

      // Create a non-mp3quran folder
      final otherDir = Directory('${tempDir.path}/audio/EveryAyah_reciter');
      await otherDir.create(recursive: true);
      await File('${otherDir.path}/001.mp3').writeAsBytes([1, 2, 3]);

      final resultSurah1 = await manager.getDownloadedSurahReciterPaths(1);
      expect(resultSurah1, contains('mp3quran_test_reciter'));
      expect(resultSurah1, isNot(contains('EveryAyah_reciter')));

      final resultSurah2 = await manager.getDownloadedSurahReciterPaths(2);
      expect(resultSurah2, isEmpty);
    });
  });
}
