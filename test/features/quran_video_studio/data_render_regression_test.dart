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
import 'package:tabattal/features/quran_video_studio/data/services/canvas_overlay_generator.dart';
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
}
