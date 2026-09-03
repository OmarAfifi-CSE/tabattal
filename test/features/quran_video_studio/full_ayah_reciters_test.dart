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

      // Check expanded list in مرتل
      expect(murattal.length, greaterThanOrEqualTo(30));
      final paths = murattal.map((r) => r['path']).toSet();

      // Modern reciters
      expect(paths.contains('Yasser_Ad-Dussary_128kbps'), isTrue);
      expect(paths.contains('MaherAlMuaiqly128kbps'), isTrue);
      expect(paths.contains('Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net'), isTrue);
      expect(paths.contains('Ghamadi_40kbps'), isTrue);
      expect(paths.contains('Nasser_Alqatami_128kbps'), isTrue);
      expect(paths.contains('Fares_Abbad_64kbps'), isTrue);
      expect(paths.contains('Abdullaah_3awwaad_Al-Juhaynee_128kbps'), isTrue);
      expect(paths.contains('Khaalid_Abdullaah_al-Qahtaanee_192kbps'), isTrue);

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
      expect(paths.contains('Yaser_Salamah_128kbps'), isTrue);
      expect(paths.contains('Ali_Hajjaj_AlSuesy_128kbps'), isTrue);
      expect(paths.contains('Akram_AlAlaqimy_128kbps'), isTrue);
      expect(paths.contains('Muhammad_AbdulKareem_128kbps'), isTrue);
      expect(paths.contains('Muhsin_Al_Qasim_192kbps'), isTrue);

      // Categories check
      expect(reciters.containsKey('مجود'), isTrue);
      expect(reciters.containsKey('المصحف المعلم'), isTrue);
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

      // Maher Al-Muaiqly
      expect(
        ReciterCatalog.isReciterSupportedForMode('MaherAlMuaiqly128kbps', VideoTextDisplayMode.staticFull),
        isTrue,
      );
      expect(
        ReciterCatalog.isReciterSupportedForMode('MaherAlMuaiqly128kbps', VideoTextDisplayMode.lineByLine),
        isFalse,
      );

      // Minshawy Murattal (supported in both)
      expect(
        ReciterCatalog.isReciterSupportedForMode('Minshawy_Murattal_128kbps', VideoTextDisplayMode.staticFull),
        isTrue,
      );
      expect(
        ReciterCatalog.isReciterSupportedForMode('Minshawy_Murattal_128kbps', VideoTextDisplayMode.lineByLine),
        isTrue,
      );
    });
  });
}
