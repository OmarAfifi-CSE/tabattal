import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  setUp(() {
    SurahAudioTimingService.clearMemoryCache();
    SharedPreferences.setMockInitialValues({});
  });

  group('SurahAudioTimingService Tests', () {
    test('resolveRecitationId resolves known continuous reciters and returns null for non-timestamped/unknown reciters', () {
      expect(SurahAudioTimingService.resolveRecitationId('Minshawy_Murattal_128kbps'), 9);
      expect(SurahAudioTimingService.resolveRecitationId('Husary_128kbps'), 6);
      expect(SurahAudioTimingService.resolveRecitationId('Abdul_Basit_Mujawwad_128kbps'), 1);
      expect(SurahAudioTimingService.resolveRecitationId('Alafasy_128kbps'), 7);
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

    test('Fetches from API, parses timestamps, and stores to SharedPreferences cache', () async {
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

      // Verify persistent cache in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('surah_timings_9:1');
      expect(cachedStr, isNotNull);
      expect(cachedStr!.contains('001.mp3'), isTrue);
    });

    test('Loads directly from SharedPreferences cache without network request', () async {
      final prefs = await SharedPreferences.getInstance();
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
      await prefs.setString('surah_timings_9:112', jsonEncode(existingTimings.toJson()));

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
  });
}
