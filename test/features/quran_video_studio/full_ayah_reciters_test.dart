import 'package:flutter_test/flutter_test.dart';
import 'package:tabattal/core/constants/reciter_catalog.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_enums.dart';

void main() {
  group('Full Ayah Video Reciters Mode Tests', () {
    test('getVideoRecitersByCategory returns 6 verified reciters in مرتل for lineByLine mode', () {
      final reciters = ReciterCatalog.getVideoRecitersByCategory(VideoTextDisplayMode.lineByLine);
      final murattal = reciters['مرتل']!;

      expect(murattal.length, 6);
      final paths = murattal.map((r) => r['path']).toSet();
      expect(paths.contains('Minshawy_Murattal_128kbps'), isTrue);
      expect(paths.contains('Husary_128kbps'), isTrue);
      expect(paths.contains('Abdul_Basit_Murattal_192kbps'), isTrue);
      expect(paths.contains('Abu_Bakr_Ash-Shaatree_128kbps'), isTrue);
      expect(paths.contains('Saood_ash-Shuraym_128kbps'), isTrue);
      expect(paths.contains('Hani_Rifai_192kbps'), isTrue);

      // Yasser Al-Dossari must NOT be in lineByLine mode to prevent desync
      expect(paths.contains('Yasser_Ad-Dussary_128kbps'), isFalse);
    });

    test('getVideoRecitersByCategory returns extended reciter catalog for staticFull mode', () {
      final reciters = ReciterCatalog.getVideoRecitersByCategory(VideoTextDisplayMode.staticFull);
      final murattal = reciters['مرتل']!;

      // Check expanded list in مرتل (EveryAyah reciters by default)
      expect(murattal.length, greaterThanOrEqualTo(25));
      final paths = murattal.map((r) => r['path']).toSet();

      // MP3Quran reciters must NOT be included by default (to prevent network errors in video studio)
      expect(paths.contains('mp3quran_6_128kbps'), isFalse);
      expect(paths.contains('Khalid_AlJaleel_128kbps'), isFalse);

      // When downloadedMp3QuranPaths includes a reciter, it is included
      final recitersWithDownloaded = ReciterCatalog.getVideoRecitersByCategory(
        VideoTextDisplayMode.staticFull,
        downloadedMp3QuranPaths: {'mp3quran_6_128kbps', 'Khalid_AlJaleel_128kbps'},
      );
      final murattalWithDownloaded = recitersWithDownloaded['مرتل']!;
      final pathsWithDownloaded = murattalWithDownloaded.map((r) => r['path']).toSet();
      expect(pathsWithDownloaded.contains('mp3quran_6_128kbps'), isTrue);
      expect(pathsWithDownloaded.contains('Khalid_AlJaleel_128kbps'), isTrue);

      // Modern reciters
      expect(paths.contains('Yasser_Ad-Dussary_128kbps'), isTrue);
      expect(paths.contains('Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net'), isTrue);
      expect(paths.contains('Ghamadi_40kbps'), isTrue);
      expect(paths.contains('Nasser_Alqatami_128kbps'), isTrue);
      expect(paths.contains('Fares_Abbad_64kbps'), isTrue);
      expect(paths.contains('Abdullaah_3awwaad_Al-Juhaynee_128kbps'), isTrue);

      // Globally untimed reciters must be excluded by the safety valve
      expect(paths.contains('MaherAlMuaiqly128kbps'), isFalse);
      expect(paths.contains('Minshawy_Mujawwad_192kbps'), isFalse);
      expect(paths.contains('Yaser_Salamah_128kbps'), isFalse);
      expect(paths.contains('Ayman_Sowaid_64kbps'), isFalse);

      // Senior and classic reciters
      expect(paths.contains('mahmoud_ali_al_banna_32kbps'), isTrue);
      expect(paths.contains('Mohammad_al_Tablaway_128kbps'), isTrue);
      expect(paths.contains('Hudhaify_128kbps'), isTrue);
      expect(paths.contains('Ali_Jaber_64kbps'), isTrue);
      expect(paths.contains('Muhammad_Ayyoub_128kbps'), isTrue);
      expect(paths.contains('Ibrahim_Akhdar_32kbps'), isTrue);
      expect(paths.contains('Abdullah_Matroud_128kbps'), isTrue);
      expect(paths.contains('Muhammad_Jibreel_128kbps'), isTrue);
      expect(paths.contains('Abdullah_Basfar_192kbps'), isTrue);
      expect(paths.contains('Salaah_AbdulRahman_Bukhatir_128kbps'), isTrue);
      expect(paths.contains('Nabil_Rifa3i_48kbps'), isTrue);
      expect(paths.contains('Sahl_Yassin_128kbps'), isTrue);
      expect(paths.contains('Ali_Hajjaj_AlSuesy_128kbps'), isTrue);
      expect(paths.contains('Akram_AlAlaqimy_128kbps'), isTrue);
      expect(paths.contains('Muhammad_AbdulKareem_128kbps'), isTrue);
      expect(paths.contains('Muhsin_Al_Qasim_192kbps'), isTrue);

      // Categories check
      expect(reciters.containsKey('مجود'), isTrue);
      expect(reciters.containsKey('المصحف المعلم'), isTrue);
    });

    test('getVideoRecitersByCategory filters out surah-specific untimed reciters', () {
      // Nabil Al-Rifai in Surah 1 vs Surah 27 (An-Naml)
      final s1Reciters = ReciterCatalog.getVideoRecitersByCategory(
        VideoTextDisplayMode.staticFull,
        surahNumber: 1,
      );
      final s1Paths = s1Reciters['مرتل']!.map((r) => r['path']).toSet();
      expect(s1Paths.contains('Nabil_Rifa3i_48kbps'), isTrue);

      final s27Reciters = ReciterCatalog.getVideoRecitersByCategory(
        VideoTextDisplayMode.staticFull,
        surahNumber: 27,
      );
      final s27Paths = s27Reciters['مرتل']!.map((r) => r['path']).toSet();
      expect(s27Paths.contains('Nabil_Rifa3i_48kbps'), isFalse);

      // Abdullaah Awad Al-Juhaynee in Surah 1 vs Surah 4 (An-Nisa)
      expect(s1Paths.contains('Abdullaah_3awwaad_Al-Juhaynee_128kbps'), isTrue);
      final s4Reciters = ReciterCatalog.getVideoRecitersByCategory(
        VideoTextDisplayMode.staticFull,
        surahNumber: 4,
      );
      final s4Paths = s4Reciters['مرتل']!.map((r) => r['path']).toSet();
      expect(s4Paths.contains('Abdullaah_3awwaad_Al-Juhaynee_128kbps'), isFalse);

      // Minshawy, Abdul-Basit, and Shuraym ARE supported in Surah 9 (At-Tawbah) via Quran.com fallback
      final s9Reciters = ReciterCatalog.getVideoRecitersByCategory(
        VideoTextDisplayMode.staticFull,
        surahNumber: 9,
      );
      final s9Paths = s9Reciters['مرتل']!.map((r) => r['path']).toSet();
      expect(s9Paths.contains('Minshawy_Murattal_128kbps'), isTrue);
      expect(s9Paths.contains('Saood_ash-Shuraym_128kbps'), isTrue);
      expect(s9Paths.contains('Abdul_Basit_Murattal_192kbps'), isTrue);
      expect(s9Reciters['مجود']!.any((r) => r['path'] == 'Abdul_Basit_Mujawwad_128kbps'), isTrue);
    });

    test('isReciterSupportedForMode correctly validates reciter availability', () {
      // Yasser Al-Dossari
      expect(
        ReciterCatalog.isReciterSupportedForMode('Yasser_Ad-Dussary_128kbps', VideoTextDisplayMode.staticFull),
        isTrue,
      );
      expect(
        ReciterCatalog.isReciterSupportedForMode('Yasser_Ad-Dussary_128kbps', VideoTextDisplayMode.lineByLine),
        isFalse,
      );

      // Maher Al-Muaiqly (globally untimed)
      expect(
        ReciterCatalog.isReciterSupportedForMode('MaherAlMuaiqly128kbps', VideoTextDisplayMode.staticFull),
        isFalse,
      );
      expect(
        ReciterCatalog.isReciterSupportedForMode('MaherAlMuaiqly128kbps', VideoTextDisplayMode.lineByLine),
        isFalse,
      );

      // Nabil Al-Rifai (surah-specific)
      expect(
        ReciterCatalog.isReciterSupportedForMode('Nabil_Rifa3i_48kbps', VideoTextDisplayMode.staticFull, surahNumber: 1),
        isTrue,
      );
      expect(
        ReciterCatalog.isReciterSupportedForMode('Nabil_Rifa3i_48kbps', VideoTextDisplayMode.staticFull, surahNumber: 27),
        isFalse,
      );

      // Minshawy Murattal (supported in both, including Surah 9)
      expect(
        ReciterCatalog.isReciterSupportedForMode('Minshawy_Murattal_128kbps', VideoTextDisplayMode.staticFull, surahNumber: 9),
        isTrue,
      );
      expect(
        ReciterCatalog.isReciterSupportedForMode('Minshawy_Murattal_128kbps', VideoTextDisplayMode.lineByLine, surahNumber: 9),
        isTrue,
      );
    });
  });
}
