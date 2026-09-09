import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tabattal/core/database/database_helper.dart';
import 'package:tabattal/features/quran_audio/data/models/surah_timing_model.dart';
import 'package:tabattal/features/quran_audio/data/services/surah_audio_timing_service.dart';

class _MockDioAdapter implements HttpClientAdapter {
  final Map<String, dynamic> responseData;
  final int statusCode;

  _MockDioAdapter(this.responseData, {this.statusCode = 200});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = utf8.encode(jsonEncode(responseData));
    return ResponseBody.fromBytes(
      bytes,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database testDb;

  setUp(() async {
    SurahAudioTimingService.clearMemoryCache();
    SharedPreferences.setMockInitialValues({});
    testDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.ensureAudioTimingsTable(testDb);
    DatabaseHelper.setTestDatabase(testDb);
  });

  tearDown(() async {
    DatabaseHelper.setTestDatabase(null);
    await testDb.close();
  });

  group('SurahAudioTimingService Tests', () {
    test('resolveRecitationId resolves known continuous reciters and returns null for non-timestamped/unknown reciters', () {
      expect(SurahAudioTimingService.resolveRecitationId('Minshawy_Murattal_128kbps'), 9);
      expect(SurahAudioTimingService.resolveRecitationId('Husary_128kbps'), 6);
      expect(SurahAudioTimingService.resolveRecitationId('Abdul_Basit_Mujawwad_128kbps'), 1);
      expect(SurahAudioTimingService.resolveRecitationId('Ghamadi_40kbps'), 13);
      expect(SurahAudioTimingService.resolveRecitationId('MaherAlMuaiqly128kbps'), 159);
      expect(SurahAudioTimingService.resolveRecitationId('Yasser_Ad-Dussary_128kbps'), 174);
      expect(SurahAudioTimingService.resolveRecitationId('Nasser_Alqatami_128kbps'), 104);
      // Non-timestamped reciters return null to trigger gapless EveryAyah playlist directly
      expect(SurahAudioTimingService.resolveRecitationId('Hudhaify_128kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Muhammad_Ayyoub_128kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Ibrahim_Akhdar_32kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Khaalid_Abdullaah_al-Qahtaanee_192kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Nabil_Rifa3i_48kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Yaser_Salamah_128kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Muhammad_AbdulKareem_128kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Ayman_Sowaid_64kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('warsh/warsh_ibrahim_aldosary_128kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Unknown_Reciter_999'), isNull);
    });

    test('Fetches from API, parses timestamps, and stores to SQLite surah_audio_timings cache', () async {
      final mockData = {
        'audio_file': {
          'audio_url': 'https://download.quranicaudio.com/quran/minshawi/001.mp3',
          'timestamps': [
            {
              'verse_key': '1:1',
              'timestamp_from': 0,
              'timestamp_to': 5000,
              'duration': 5000,
            },
            {
              'verse_key': '1:2',
              'timestamp_from': 5000,
              'timestamp_to': 11000,
              'duration': 6000,
            },
          ],
        },
      };

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter(mockData);

      final service = SurahAudioTimingService(dio: dio);

      final timings = await service.getSurahTimings(
        reciterPath: 'Minshawy_Murattal_128kbps',
        surahNumber: 1,
      );

      expect(timings, isNotNull);
      expect(timings!.surah, 1);
      expect(timings.audioUrl, 'https://download.quranicaudio.com/quran/minshawi/001.mp3');
      expect(timings.verseTimings.length, 2);
      expect(timings.verseTimings[0].ayah, 1);
      expect(timings.verseTimings[1].start, const Duration(seconds: 5));

      // Verify persistent cache in SQLite
      final rows = await testDb.query(
        'surah_audio_timings',
        where: 'reciter_path = ? AND surah_number = ?',
        whereArgs: ['Minshawy_Murattal_128kbps', 1],
      );
      expect(rows.isNotEmpty, isTrue);
      expect(rows.first['audio_url'], 'https://download.quranicaudio.com/quran/minshawi/001.mp3');
      expect((rows.first['verse_timings'] as String).contains('1:1'), isFalse); // JSON uses ayah/surah
      expect((rows.first['verse_timings'] as String).contains('"ayah":1'), isTrue);
    });

    test('Loads directly from SQLite surah_audio_timings cache without network request', () async {
      const existingTimings = SurahTimings(
        surah: 112,
        audioUrl: 'https://download.quranicaudio.com/quran/minshawi/112.mp3',
        verseTimings: [
          VerseTimestamp(surah: 112, ayah: 1, start: Duration.zero, end: Duration(seconds: 3)),
          VerseTimestamp(surah: 112, ayah: 2, start: Duration(seconds: 3), end: Duration(seconds: 6)),
          VerseTimestamp(surah: 112, ayah: 3, start: Duration(seconds: 6), end: Duration(seconds: 9)),
          VerseTimestamp(surah: 112, ayah: 4, start: Duration(seconds: 9), end: Duration(seconds: 13)),
        ],
      );

      await testDb.insert('surah_audio_timings', {
        'reciter_path': 'Minshawy_Murattal_128kbps',
        'surah_number': 112,
        'audio_url': existingTimings.audioUrl,
        'verse_timings': jsonEncode(existingTimings.verseTimings.map((e) => e.toJson()).toList()),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      // Dio that throws if fetch is attempted
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter({}, statusCode: 500);

      final service = SurahAudioTimingService(dio: dio);

      final result = await service.getSurahTimings(
        reciterPath: 'Minshawy_Murattal_128kbps',
        surahNumber: 112,
      );

      expect(result, isNotNull);
      expect(result!.surah, 112);
      expect(result.verseTimings.length, 4);
      expect(result.audioUrl, 'https://download.quranicaudio.com/quran/minshawi/112.mp3');
    });

    test('Seeds all 41 reciter paths across 114 surahs into SQLite and retrieves default URL', () async {
      await SurahAudioTimingService.seedAllSurahs(testDb);

      // Verify row count = 41 paths * 114 surahs = 4,674 records
      final rows = await testDb.rawQuery('SELECT COUNT(*) as cnt FROM surah_audio_timings');
      final count = rows.first['cnt'] as int;
      expect(count, 4674);

      // Non-timestamped reciter loads seeded URL directly from SQLite with 0 network calls
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter({}, statusCode: 500);
      final service = SurahAudioTimingService(dio: dio);

      final result = await service.getSurahTimings(
        reciterPath: 'Hudhaify_128kbps',
        surahNumber: 1,
      );
      expect(result, isNotNull);
      expect(result!.audioUrl, contains('huthayfi/001.mp3'));
    });
  });
}
