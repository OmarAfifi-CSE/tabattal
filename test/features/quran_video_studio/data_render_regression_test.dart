// Audit reproductions; fixtures only, no real user database or remote requests.
// ignore_for_file: depend_on_referenced_packages, invalid_use_of_visible_for_testing_member
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tabattal/core/database/database_helper.dart';
import 'package:tabattal/core/network/tafsir_download_service.dart';
import 'package:tabattal/features/quran_reader/data/datasources/quran_local_data_source.dart';
import 'package:tabattal/features/quran_reader/data/datasources/quran_remote_data_source.dart';
import 'package:tabattal/features/quran_reader/data/models/verse_model.dart';
import 'dart:ui' as ui;
import 'package:tabattal/features/quran_video_studio/data/services/canvas_overlay_generator.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/word_timing_segment.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_enums.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_project_config.dart';

class AuditDatabase extends Fake implements DatabaseHelper {
  AuditDatabase(this.db);
  final Database db;
  @override
  Future<Database> get database async => db;
}
class AuditRemote extends Fake implements QuranRemoteDataSource {
  final chapters = <int>[];
  @override
  Future<Map<String, dynamic>> getTafsirByChapter(int resourceId, int chapterNumber, {int page = 1, int perPage = 50}) async {
    chapters.add(chapterNumber);
    return {'tafsirs': [{'verse_key': '$chapterNumber:1', 'text': 'fixture'}], 'pagination': {'next_page': null}};
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  setUpAll(() async {
    await (FontLoader('Amiri')..addFont(rootBundle.load('assets/fonts/Amiri-Regular.ttf'))).load();
    await (FontLoader('KFGQPC HAFS Uthmanic Script Regular')..addFont(rootBundle.load('assets/fonts/KFGQPC HAFS Uthmanic Script Regular.ttf'))).load();
  });
  late Database db;
  late QuranLocalDataSourceImpl local;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE tafsir (verse_key TEXT, resource_id INTEGER, text TEXT, UNIQUE(verse_key, resource_id))');
    local = QuranLocalDataSourceImpl(databaseHelper: AuditDatabase(db));
  });
  tearDown(() async => db.close());
  test('Only chapter 114 present must not report complete tafsir', () async {
    await local.insertTafsirs([{'verse_key': '114:1', 'resource_id': 14, 'text': 'fixture'}]);
    expect(await local.getTafsirDownloadProgress(14), lessThan(1.0));
  });
  test('Bulk tafsir download after viewing chapter 100 must fetch earlier missing chapters', () async {
    await local.insertTafsirs([{'verse_key': '100:1', 'resource_id': 14, 'text': 'fixture'}]);
    final remote = AuditRemote();
    await TafsirDownloadService(localDataSource: local, remoteDataSource: remote).downloadTafsir(14).toList();
    expect(remote.chapters, contains(1), reason: 'Chapter one is absent but completion was reported.');
  });
  test('Cold crop must contain the same text bounds as warm crop', () async {
    const config = VideoProjectConfig(surahNumber: 2, startAyah: 282, endAyah: 282,
      textDisplayMode: VideoTextDisplayMode.staticFull, showTafsir: true, showEnglishTranslation: true,
      videoQuality: VideoQuality.hd720p);
    final verse = VerseModel(id: 282, verseNumber: 282, verseKey: '2:282', juzNumber: 3,
      textUthmani: List.filled(60, 'كلمة للاختبار').join(' '), words: const [],
      tafsir: List.filled(40, 'نص تفسير للاختبار').join(' '), translation: List.filled(40, 'Translation fixture').join(' '));
    CanvasOverlayGenerator.clearLayoutCache();
    const generator = CanvasOverlayGenerator();
    final cold = (await generator.generateVerseOverlayCrop(verse: verse, config: config, pageNumber: 48))!;
    final warm = (await generator.generateVerseOverlayCrop(verse: verse, config: config, pageNumber: 48))!;
    expect(cold.cropHeight, warm.cropHeight, reason: 'cold=${cold.cropHeight} at ${cold.cropY}; warm=${warm.cropHeight} at ${warm.cropY}');
  });
  test('Dynamic content bounds quarantine center text and exclude badge area', () {
    const configWithBadge = VideoProjectConfig(
      surahNumber: 1,
      startAyah: 1,
      endAyah: 7,
      showSurahBadge: true,
      aspectRatio: VideoAspectRatio.portrait9x16,
    );
    final verse = VerseModel(
      id: 1,
      verseNumber: 1,
      verseKey: '1:1',
      juzNumber: 1,
      textUthmani: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
      words: const [],
    );
    const size = Size(1080, 1920);
    final bounds = CanvasOverlayGenerator.computeDynamicContentBounds(
      size,
      verse: verse,
      config: configWithBadge,
      pageNumber: 1,
    );

    // Dynamic content is quarantined to the card center and does not stretch to the top badge
    expect(bounds.top, greaterThanOrEqualTo(1920 * 0.25));
  });
  test('generateSurahBadgeOverlayPng generates distinct non-fading overlays for different ayahs', () async {
    const config = VideoProjectConfig(
      surahNumber: 1,
      startAyah: 1,
      endAyah: 2,
      showSurahBadge: true,
      aspectRatio: VideoAspectRatio.portrait9x16,
      videoQuality: VideoQuality.hd720p,
    );
    final verse1 = VerseModel(
      id: 1,
      verseNumber: 1,
      verseKey: '1:1',
      juzNumber: 1,
      textUthmani: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
      words: const [],
    );
    final verse2 = VerseModel(
      id: 2,
      verseNumber: 2,
      verseKey: '1:2',
      juzNumber: 1,
      textUthmani: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
      words: const [],
    );
    const generator = CanvasOverlayGenerator();
    final badge1 = (await generator.generateSurahBadgeOverlayPng(config: config, verse: verse1))!;
    final badge2 = (await generator.generateSurahBadgeOverlayPng(config: config, verse: verse2))!;
    expect(badge1, isNot(equals(badge2)));
    expect(badge1.length, greaterThan(0));
    expect(badge2.length, greaterThan(0));
  });

  test('Line-by-line mode with Tafsir and Translation renders smoothly across line boundaries', () {
    const config = VideoProjectConfig(
      surahNumber: 1,
      startAyah: 1,
      endAyah: 1,
      textDisplayMode: VideoTextDisplayMode.lineByLine,
      showTafsir: true,
      showEnglishTranslation: true,
    );

    final verse = VerseModel(
      id: 1,
      verseNumber: 1,
      verseKey: '1:1',
      juzNumber: 1,
      textUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
      words: const [
        WordModel(id: 1, textUthmani: 'بِسْمِ', codeV2: 'بِسْمِ', lineNumber: 1, charTypeName: 'word', verseKey: '1:1', pageNumber: 1),
        WordModel(id: 2, textUthmani: 'ٱللَّهِ', codeV2: 'ٱللَّهِ', lineNumber: 1, charTypeName: 'word', verseKey: '1:1', pageNumber: 1),
        WordModel(id: 3, textUthmani: 'ٱلرَّحْمَٰنِ', codeV2: 'ٱلرَّحْمَٰنِ', lineNumber: 2, charTypeName: 'word', verseKey: '1:1', pageNumber: 1),
        WordModel(id: 4, textUthmani: 'ٱلرَّحِيمِ', codeV2: 'ٱلرَّحِيمِ', lineNumber: 2, charTypeName: 'word', verseKey: '1:1', pageNumber: 1),
      ],
      tafsir: 'تفسير الآية الكريمة',
      translation: 'In the name of Allah, the Entirely Merciful, the Especially Merciful.',
    );

    final timings = [
      const WordTimingSegment(wordPosition: 1, startMs: 0, endMs: 1000),
      const WordTimingSegment(wordPosition: 2, startMs: 1000, endMs: 2000),
      const WordTimingSegment(wordPosition: 3, startMs: 2000, endMs: 3000),
      const WordTimingSegment(wordPosition: 4, startMs: 3000, endMs: 4000),
    ];

    const size = Size(1080, 1920);

    // Test line 1 active, line transition, line 2 active, and end of ayah
    for (final pos in [0, 500, 1950, 2050, 3500, 3950]) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      expect(
        () => CanvasOverlayGenerator.paintDynamicContent(
          canvas,
          size,
          verse: verse,
          config: config,
          pageNumber: 1,
          playbackPositionMs: pos,
          totalDurationMs: 4000,
          isPlaying: true,
          wordTimings: timings,
        ),
        returnsNormally,
      );

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    }
  });

  test('Decoupled line-by-line export generates separate verse-only and tafsir-only crops accurately', () async {
    const generator = CanvasOverlayGenerator();
    const config = VideoProjectConfig(
      surahNumber: 2,
      startAyah: 1,
      endAyah: 1,
      textDisplayMode: VideoTextDisplayMode.lineByLine,
      showTafsir: true,
      showEnglishTranslation: true,
      showSurahBadge: true,
    );

    final verse = VerseModel(
      id: 2,
      verseNumber: 1,
      verseKey: '2:1',
      juzNumber: 1,
      textUthmani: 'الۤمۤ',
      words: const [
        WordModel(id: 1, textUthmani: 'الۤمۤ', codeV2: 'الۤمۤ', lineNumber: 1, charTypeName: 'word', verseKey: '2:1', pageNumber: 2),
      ],
      tafsir: 'تفسير سورة البقرة الآية الأولى',
      translation: 'Alif, Lam, Meem.',
    );

    // 1. Full content bounds
    final fullBounds = CanvasOverlayGenerator.computeDynamicContentBounds(
      const Size(1080, 1920),
      verse: verse,
      config: config,
      pageNumber: 2,
      translationText: verse.translation,
      tafsirText: verse.tafsir,
      overrideLineIndex: 0,
      renderVerseText: true,
      renderTafsirAndTranslation: true,
    );
    expect(fullBounds.height, greaterThan(0));

    // 2. Verse-only bounds
    final verseOnlyBounds = CanvasOverlayGenerator.computeDynamicContentBounds(
      const Size(1080, 1920),
      verse: verse,
      config: config,
      pageNumber: 2,
      translationText: verse.translation,
      tafsirText: verse.tafsir,
      overrideLineIndex: 0,
      renderVerseText: true,
      renderTafsirAndTranslation: false,
    );
    expect(verseOnlyBounds.height, greaterThan(0));
    expect(verseOnlyBounds.height, lessThan(fullBounds.height));

    // 3. Tafsir-only bounds
    final tafsirOnlyBounds = CanvasOverlayGenerator.computeDynamicContentBounds(
      const Size(1080, 1920),
      verse: verse,
      config: config,
      pageNumber: 2,
      translationText: verse.translation,
      tafsirText: verse.tafsir,
      overrideLineIndex: 0,
      renderVerseText: false,
      renderTafsirAndTranslation: true,
    );
    expect(tafsirOnlyBounds.height, greaterThan(0));
    expect(tafsirOnlyBounds.top, equals(verseOnlyBounds.top + verseOnlyBounds.height));

    // 4. Crop generations
    final verseCrop = await generator.generateVerseOverlayCrop(
      verse: verse,
      config: config,
      pageNumber: 2,
      translationText: verse.translation,
      tafsirText: verse.tafsir,
      overrideLineIndex: 0,
      renderVerseText: true,
      renderTafsirAndTranslation: false,
    );
    expect(verseCrop, isNotNull);
    expect(verseCrop!.bytes.length, greaterThan(0));

    final tafsirCrop = await generator.generateVerseOverlayCrop(
      verse: verse,
      config: config,
      pageNumber: 2,
      translationText: verse.translation,
      tafsirText: verse.tafsir,
      overrideLineIndex: 0,
      renderVerseText: false,
      renderTafsirAndTranslation: true,
    );
    expect(tafsirCrop, isNotNull);
    expect(tafsirCrop!.bytes.length, greaterThan(0));
    expect(tafsirCrop.cropY, greaterThan(verseCrop.cropY));
  });
}


