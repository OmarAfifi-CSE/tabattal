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
      expect(SurahAudioTimingService.resolveRecitationId('Husary_Muallim_128kbps'), 12);
      expect(SurahAudioTimingService.resolveRecitationId('Minshawy_Teacher_128kbps'), 168);
      expect(SurahAudioTimingService.resolveRecitationId('mahmoud_ali_al_banna_32kbps'), 129);
      expect(SurahAudioTimingService.resolveRecitationId('English/Sahih_Intnl_Ibrahim_Walk_192kbps'), 58);
      // Reciters with MP3Quran human-annotated polygon reads return null for Quran.com to use MP3Quran directly
      expect(SurahAudioTimingService.resolveRecitationId('Minshawy_Murattal_128kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Husary_128kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Abdul_Basit_Mujawwad_128kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Ghamadi_40kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('MaherAlMuaiqly128kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Yasser_Ad-Dussary_128kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Nasser_Alqatami_128kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Hudhaify_128kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Muhammad_Ayyoub_128kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Ibrahim_Akhdar_32kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Khaalid_Abdullaah_al-Qahtaanee_192kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Nabil_Rifa3i_48kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Yaser_Salamah_128kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Muhammad_AbdulKareem_128kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('mp3quran_232_128kbps'), isNull);
      expect(SurahAudioTimingService.resolveRecitationId('Unknown_Reciter_999'), isNull);
    });

    test('Fetches from API, parses timestamps, and stores to SQLite surah_audio_timings cache', () async {
      final mockData = {
        'audio_file': {
          'audio_url': 'https://download.quranicaudio.com/qdc/khalil_al_husary/muallim/1.mp3',
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
        reciterPath: 'Husary_Muallim_128kbps',
        surahNumber: 1,
      );

      expect(timings, isNotNull);
      expect(timings!.surah, 1);
      expect(timings.audioUrl, 'https://download.quranicaudio.com/qdc/khalil_al_husary/muallim/1.mp3');
      expect(timings.verseTimings.length, 2);
      expect(timings.verseTimings[0].ayah, 1);
      expect(timings.verseTimings[1].start, const Duration(seconds: 5));

      // Verify persistent cache in SQLite
      final rows = await testDb.query(
        'surah_audio_timings',
        where: 'reciter_path = ? AND surah_number = ?',
        whereArgs: ['Husary_Muallim_128kbps', 1],
      );
      expect(rows.isNotEmpty, isTrue);
      expect(rows.first['audio_url'], 'https://download.quranicaudio.com/qdc/khalil_al_husary/muallim/1.mp3');
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

    test('Seeds all reciter paths across 114 surahs into SQLite and retrieves default URL', () async {
      await SurahAudioTimingService.seedAllSurahs(testDb);

      final rows = await testDb.rawQuery('SELECT COUNT(*) as cnt FROM surah_audio_timings');
      final count = rows.first['cnt'] as int;
      expect(count, greaterThan(4000));

      // Fallback reciter loads seeded URL directly from SQLite when network is unavailable
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter({}, statusCode: 500);
      final service = SurahAudioTimingService(dio: dio);

      final result = await service.getSurahTimings(
        reciterPath: 'Ali_Jaber_64kbps',
        surahNumber: 1,
      );
      expect(result, isNotNull);
      expect(result!.audioUrl, contains('001.mp3'));
    });

    test('Fetches and parses real MP3Quran verse timestamps correctly for Muhammad AbdulKareem', () async {
      final mockResponse = {
        'value': [
          {
            'ayah': 0,
            'start_time': 0,
            'end_time': 3820,
          },
          {
            'ayah': 1,
            'start_time': 3820,
            'end_time': 6500,
          },
          {
            'ayah': 2,
            'start_time': 6500,
            'end_time': 10360,
          }
        ],
        'Count': 3
      };

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter(mockResponse);
      final service = SurahAudioTimingService(dio: dio);

      final result = await service.getSurahTimings(
        reciterPath: 'Muhammad_AbdulKareem_128kbps',
        surahNumber: 1,
      );

      expect(result, isNotNull);
      expect(result!.surah, 1);
      expect(result.verseTimings.length, 2);
      expect(result.verseTimings[0].ayah, 1);
      expect(result.verseTimings[0].start.inMilliseconds, 3820);
      expect(result.verseTimings[0].end.inMilliseconds, 6500);
      expect(result.audioUrl, 'https://server12.mp3quran.net/m_krm/001.mp3');
    });

    test('Normalizes Surah 1 for Mahmoud Khalil Al-Husary (0..6 mapped to 1..7) with unaltered timestamps', () async {
      final mockResponse = {
        'value': [
          {'ayah': 0, 'start_time': 0, 'end_time': 11705},
          {'ayah': 1, 'start_time': 11705, 'end_time': 18048},
          {'ayah': 2, 'start_time': 18048, 'end_time': 22513},
          {'ayah': 3, 'start_time': 22513, 'end_time': 27115},
          {'ayah': 4, 'start_time': 27115, 'end_time': 33956},
          {'ayah': 5, 'start_time': 33956, 'end_time': 39337},
          {'ayah': 6, 'start_time': 39337, 'end_time': 54260},
        ],
        'Count': 7,
      };

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter(mockResponse);
      final service = SurahAudioTimingService(dio: dio);

      final result = await service.getSurahTimings(
        reciterPath: 'Husary_128kbps',
        surahNumber: 1,
      );

      expect(result, isNotNull);
      expect(result!.surah, 1);
      expect(result.verseTimings.length, 7);
      expect(result.verseTimings[0].ayah, 1);
      expect(result.verseTimings[0].start, Duration.zero);
      expect(result.verseTimings[0].end.inMilliseconds, 11705);
      expect(result.verseTimings[1].ayah, 2);
      expect(result.verseTimings[1].start.inMilliseconds, 11705);
      expect(result.verseTimings[6].ayah, 7);
      expect(result.verseTimings[6].end.inMilliseconds, 54260);
    });

    test('Normalizes Surah 1 for Muhammad Siddiq Al-Minshawy skipping recorded Isti\'adhah (ayah 0)', () async {
      final mockResponse = {
        'value': [
          {'ayah': 0, 'start_time': 0, 'end_time': 4500}, // Isti'adhah
          {'ayah': 1, 'start_time': 4500, 'end_time': 12000}, // Basmalah
          {'ayah': 2, 'start_time': 12000, 'end_time': 18000},
          {'ayah': 3, 'start_time': 18000, 'end_time': 24000},
          {'ayah': 4, 'start_time': 24000, 'end_time': 30000},
          {'ayah': 5, 'start_time': 30000, 'end_time': 36000},
          {'ayah': 6, 'start_time': 36000, 'end_time': 42000},
          {'ayah': 7, 'start_time': 42000, 'end_time': 55000},
        ],
        'Count': 8,
      };

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter(mockResponse);
      final service = SurahAudioTimingService(dio: dio);

      final result = await service.getSurahTimings(
        reciterPath: 'Minshawy_Murattal_128kbps',
        surahNumber: 1,
      );

      expect(result, isNotNull);
      expect(result!.surah, 1);
      expect(result.verseTimings.length, 7);
      // Recorded Isti'adhah (ayah 0) is omitted; Ayah 1 is Basmalah with unaltered timing
      expect(result.verseTimings[0].ayah, 1);
      expect(result.verseTimings[0].start.inMilliseconds, 4500);
      expect(result.verseTimings[0].end.inMilliseconds, 12000);
      expect(result.verseTimings[6].ayah, 7);
      expect(result.verseTimings[6].end.inMilliseconds, 55000);
    });

    test('Normalizes Surah 2 skipping introductory Basmalah (ayah 0) with unaltered timestamps', () async {
      final mockResponse = {
        'value': [
          {'ayah': 0, 'start_time': 0, 'end_time': 5000}, // Intro Basmalah
          {'ayah': 1, 'start_time': 5000, 'end_time': 12000},
          {'ayah': 2, 'start_time': 12000, 'end_time': 20000},
        ],
        'Count': 3,
      };

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter(mockResponse);
      final service = SurahAudioTimingService(dio: dio);

      final result = await service.getSurahTimings(
        reciterPath: 'Mohammad_al_Tablaway_128kbps',
        surahNumber: 2,
      );

      expect(result, isNotNull);
      expect(result!.surah, 2);
      expect(result.verseTimings.length, 2);
      expect(result.verseTimings[0].ayah, 1);
      expect(result.verseTimings[0].start.inMilliseconds, 5000);
      expect(result.verseTimings[0].end.inMilliseconds, 12000);
      expect(result.verseTimings[1].ayah, 2);
      expect(result.verseTimings[1].start.inMilliseconds, 12000);
      expect(result.verseTimings[1].end.inMilliseconds, 20000);
    });

    test('Corrects verified upstream database typos for Ibrahim Al-Akhdar in Surah 19, 36, and 93', () async {
      // Surah 19 Maryam with source typo on Ayah 98
      final mockResponse19 = {
        'value': [
          {'ayah': 97, 'start_time': 1342617, 'end_time': 1364764},
          {'ayah': 98, 'start_time': 1364764, 'end_time': 962137}, // Typo: 962137 < 1364764
        ],
      };

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter(mockResponse19);
      final service = SurahAudioTimingService(dio: dio);

      final result19 = await service.getSurahTimings(
        reciterPath: 'Ibrahim_Akhdar_32kbps',
        surahNumber: 19,
      );

      expect(result19, isNotNull);
      expect(result19!.verseTimings.length, 2);
      expect(result19.verseTimings[1].ayah, 98);
      expect(result19.verseTimings[1].start.inMilliseconds, 1364764);
      expect(result19.verseTimings[1].end.inMilliseconds, 1379809); // Corrected to audio track end

      // Surah 36 Ya-Sin with source typo on Ayah 83
      final mockResponse36 = {
        'value': [
          {'ayah': 82, 'start_time': 1200000, 'end_time': 1228110},
          {'ayah': 83, 'start_time': 1228110, 'end_time': 487305}, // Typo: 487305 < 1228110
        ],
      };
      final dio36 = Dio();
      dio36.httpClientAdapter = _MockDioAdapter(mockResponse36);
      final service36 = SurahAudioTimingService(dio: dio36);

      final result36 = await service36.getSurahTimings(
        reciterPath: 'Ibrahim_Akhdar_32kbps',
        surahNumber: 36,
      );

      expect(result36, isNotNull);
      expect(result36!.verseTimings[1].ayah, 83);
      expect(result36.verseTimings[1].end.inMilliseconds, 1241255); // Corrected to audio track end

      // Surah 93 Ad-Duha with source duplicate on Ayahs 10 & 11
      final mockResponse93 = {
        'value': [
          {'ayah': 9, 'start_time': 48719, 'end_time': 54906},
          {'ayah': 10, 'start_time': 54906, 'end_time': 54906}, // 0ms duration
          {'ayah': 11, 'start_time': 54906, 'end_time': 69434},
        ],
      };
      final dio93 = Dio();
      dio93.httpClientAdapter = _MockDioAdapter(mockResponse93);
      final service93 = SurahAudioTimingService(dio: dio93);

      final result93 = await service93.getSurahTimings(
        reciterPath: 'Ibrahim_Akhdar_32kbps',
        surahNumber: 93,
      );

      expect(result93, isNotNull);
      expect(result93!.verseTimings.length, 3);
      expect(result93.verseTimings[1].ayah, 10);
      expect(result93.verseTimings[1].end.inMilliseconds, 62000);
      expect(result93.verseTimings[2].ayah, 11);
      expect(result93.verseTimings[2].start.inMilliseconds, 62000);
      expect(result93.verseTimings[2].end.inMilliseconds, 69454);
    });

    test('Timing Integrity Gate rejects chronologically inverted or negative verse intervals', () async {
      final corruptedResponse = {
        'value': [
          {'ayah': 1, 'start_time': 10000, 'end_time': 5000}, // Inverted
        ],
      };

      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter(corruptedResponse);
      final service = SurahAudioTimingService(dio: dio);

      final result = await service.getSurahTimings(
        reciterPath: 'Akram_AlAlaqimy_128kbps',
        surahNumber: 10,
      );

      expect(result, isNotNull);
      // Integrity gate should zero out verseTimings so it falls back to continuous playback
      expect(result!.verseTimings, isEmpty);
    });
  });
}
