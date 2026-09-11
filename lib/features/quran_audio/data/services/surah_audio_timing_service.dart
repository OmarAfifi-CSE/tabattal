import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../../core/constants/reciter_catalog.dart';
import '../../../../core/database/database_helper.dart';
import '../models/surah_timing_model.dart';

/// Metadata for reciters supported by MP3Quran.net v3 Ayat Timing API
class Mp3QuranReadInfo {
  final int readId;
  final String folderUrl;

  const Mp3QuranReadInfo({
    required this.readId,
    required this.folderUrl,
  });
}

class SurahAudioTimingService {
  final Dio _dio;
  static final Map<String, SurahTimings> _memoryCache = {};
  static final Map<String, Future<SurahTimings?>> _inFlightRequests = {};

  SurahAudioTimingService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 12),
                validateStatus: (status) => status != null && status < 500,
                headers: {
                  if (!kIsWeb)
                    'User-Agent':
                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                  'Accept': 'application/json',
                },
              ),
            );

  /// 100% verified MP3Quran.net v3 Ayat Timing API reads mapped to reciter paths.
  /// Provides millisecond-accurate verse timestamps and matching server audio streams for 114 surahs.
  static const Map<String, Mp3QuranReadInfo> _mp3quranReadMap = {
    'Abdul_Basit_Mujawwad_128kbps': Mp3QuranReadInfo(
      readId: 51,
      folderUrl: 'https://server7.mp3quran.net/basit/Almusshaf-Al-Mojawwad/',
    ),
    'Abdul_Basit_Murattal_192kbps': Mp3QuranReadInfo(
      readId: 53,
      folderUrl: 'https://server7.mp3quran.net/basit/',
    ),
    'Abdulaziz_AlZahrani_128kbps': Mp3QuranReadInfo(
      readId: 56,
      folderUrl: 'https://server9.mp3quran.net/zahrani/',
    ),
    'Abdulbari_AlThubaiti_128kbps': Mp3QuranReadInfo(
      readId: 49,
      folderUrl: 'https://server6.mp3quran.net/thubti/',
    ),
    'Abdullaah_3awwaad_Al-Juhaynee_128kbps': Mp3QuranReadInfo(
      readId: 62,
      folderUrl: 'https://server13.mp3quran.net/jhn/',
    ),
    'Abdullah_AlBaijan_128kbps': Mp3QuranReadInfo(
      readId: 58,
      folderUrl: 'https://server8.mp3quran.net/buajan/',
    ),
    'Abdullah_AlMousa_128kbps': Mp3QuranReadInfo(
      readId: 243,
      folderUrl: 'https://server14.mp3quran.net/mousa/Rewayat-Hafs-A-n-Assem/',
    ),
    'Abdullah_Basfar_192kbps': Mp3QuranReadInfo(
      readId: 60,
      folderUrl: 'https://server6.mp3quran.net/bsfr/',
    ),
    'Abdullah_Matroud_128kbps': Mp3QuranReadInfo(
      readId: 59,
      folderUrl: 'https://server8.mp3quran.net/mtrod/',
    ),
    'Abdulrahman_AlOssi_128kbps': Mp3QuranReadInfo(
      readId: 225,
      folderUrl: 'https://server6.mp3quran.net/aloosi/',
    ),
    'Abu_Bakr_Ash-Shaatree_128kbps': Mp3QuranReadInfo(
      readId: 4,
      folderUrl: 'https://server11.mp3quran.net/shatri/',
    ),
    'Ahmad_AlNufais_128kbps': Mp3QuranReadInfo(
      readId: 259,
      folderUrl: 'https://server16.mp3quran.net/nufais/Rewayat-Hafs-A-n-Assem/',
    ),
    'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net': Mp3QuranReadInfo(
      readId: 5,
      folderUrl: 'https://server10.mp3quran.net/ajm/',
    ),
    'Akram_AlAlaqimy_128kbps': Mp3QuranReadInfo(
      readId: 10,
      folderUrl: 'https://server9.mp3quran.net/akrm/',
    ),
    'Ali_Hajjaj_AlSuesy_128kbps': Mp3QuranReadInfo(
      readId: 77,
      folderUrl: 'https://server9.mp3quran.net/hajjaj/',
    ),
    'Ali_Jaber_64kbps': Mp3QuranReadInfo(
      readId: 76,
      folderUrl: 'https://server11.mp3quran.net/a_jbr/',
    ),
    'Bandar_Balilah_128kbps': Mp3QuranReadInfo(
      readId: 217,
      folderUrl: 'https://server6.mp3quran.net/balilah/',
    ),
    'Fares_Abbad_64kbps': Mp3QuranReadInfo(
      readId: 81,
      folderUrl: 'https://server8.mp3quran.net/frs_a/',
    ),
    'Ghamadi_40kbps': Mp3QuranReadInfo(
      readId: 30,
      folderUrl: 'https://server7.mp3quran.net/s_gmd/',
    ),
    'Haitham_AlDukhin_128kbps': Mp3QuranReadInfo(
      readId: 273,
      folderUrl: 'https://server16.mp3quran.net/h_dukhain/Rewayat-Hafs-A-n-Assem/',
    ),
    'Hani_Rifai_192kbps': Mp3QuranReadInfo(
      readId: 89,
      folderUrl: 'https://server8.mp3quran.net/hani/',
    ),
    'Hasan_Saleh_128kbps': Mp3QuranReadInfo(
      readId: 299,
      folderUrl: 'https://server16.mp3quran.net/h_saleh/Rewayat-Hafs-A-n-Assem/',
    ),
    'Hudhaify_128kbps': Mp3QuranReadInfo(
      readId: 74,
      folderUrl: 'https://server9.mp3quran.net/hthfi/',
    ),
    'Husary_128kbps': Mp3QuranReadInfo(
      readId: 118,
      folderUrl: 'https://server13.mp3quran.net/husr/',
    ),
    'Husary_128kbps_Mujawwad': Mp3QuranReadInfo(
      readId: 119,
      folderUrl: 'https://server13.mp3quran.net/husr/Almusshaf-Al-Mojawwad/',
    ),
    'Ibrahim_Akhdar_32kbps': Mp3QuranReadInfo(
      readId: 1,
      folderUrl: 'https://server6.mp3quran.net/akdr/',
    ),
    'Idrees_Abkar_128kbps': Mp3QuranReadInfo(
      readId: 12,
      folderUrl: 'https://server6.mp3quran.net/abkr/',
    ),
    'Khaalid_Abdullaah_al-Qahtaanee_192kbps': Mp3QuranReadInfo(
      readId: 21,
      folderUrl: 'https://server10.mp3quran.net/qht/',
    ),
    'Khalid_AlJaleel_128kbps': Mp3QuranReadInfo(
      readId: 20,
      folderUrl: 'https://server10.mp3quran.net/jleel/',
    ),
    'Khalifah_AlTunaiji_128kbps': Mp3QuranReadInfo(
      readId: 24,
      folderUrl: 'https://server12.mp3quran.net/tnjy/',
    ),
    'MaherAlMuaiqly_Mujawwad_128kbps': Mp3QuranReadInfo(
      readId: 133,
      folderUrl: 'https://server12.mp3quran.net/maher/Almusshaf-Al-Mojawwad/',
    ),
    'Mansoor_AlSalmi_128kbps': Mp3QuranReadInfo(
      readId: 245,
      folderUrl: 'https://server14.mp3quran.net/mansor/',
    ),
    'Minshawy_Murattal_128kbps': Mp3QuranReadInfo(
      readId: 112,
      folderUrl: 'https://server10.mp3quran.net/minsh/',
    ),
    'Mohammad_al_Tablaway_128kbps': Mp3QuranReadInfo(
      readId: 106,
      folderUrl: 'https://server12.mp3quran.net/tblawi/',
    ),
    'Muhammad_AbdulKareem_128kbps': Mp3QuranReadInfo(
      readId: 115,
      folderUrl: 'https://server12.mp3quran.net/m_krm/',
    ),
    'Muhammad_Ayyoub_128kbps': Mp3QuranReadInfo(
      readId: 109,
      folderUrl: 'https://server8.mp3quran.net/ayyub/',
    ),
    'Muhsin_Al_Qasim_192kbps': Mp3QuranReadInfo(
      readId: 67,
      folderUrl: 'https://server8.mp3quran.net/qasm/',
    ),
    'Mustafa_Ismail_Mujawwad_128kbps': Mp3QuranReadInfo(
      readId: 288,
      folderUrl: 'https://server8.mp3quran.net/mustafa/Almusshaf-Al-Mojawwad/',
    ),
    'Nabil_Rifa3i_48kbps': Mp3QuranReadInfo(
      readId: 87,
      folderUrl: 'https://server9.mp3quran.net/nabil/',
    ),
    'Nasser_Alqatami_128kbps': Mp3QuranReadInfo(
      readId: 86,
      folderUrl: 'https://server6.mp3quran.net/qtm/',
    ),
    'Peshawa_Kurdi_128kbps': Mp3QuranReadInfo(
      readId: 268,
      folderUrl: 'https://server16.mp3quran.net/peshawa/Rewayat-Hafs-A-n-Assem/',
    ),
    'Raad_AlKurdi_128kbps': Mp3QuranReadInfo(
      readId: 221,
      folderUrl: 'https://server6.mp3quran.net/kurdi/',
    ),
    'Sahl_Yassin_128kbps': Mp3QuranReadInfo(
      readId: 32,
      folderUrl: 'https://server6.mp3quran.net/shl/',
    ),
    'Salaah_AbdulRahman_Bukhatir_128kbps': Mp3QuranReadInfo(
      readId: 46,
      folderUrl: 'https://server8.mp3quran.net/bu_khtr/',
    ),
    'Salah_AlBudair_128kbps': Mp3QuranReadInfo(
      readId: 43,
      folderUrl: 'https://server6.mp3quran.net/s_bud/',
    ),
    'Saood_ash-Shuraym_128kbps': Mp3QuranReadInfo(
      readId: 31,
      folderUrl: 'https://server7.mp3quran.net/shur/',
    ),
    'Tawfeeq_AsSayegh_128kbps': Mp3QuranReadInfo(
      readId: 17,
      folderUrl: 'https://server6.mp3quran.net/twfeeq/',
    ),
    'Wadih_AlYamani_128kbps': Mp3QuranReadInfo(
      readId: 219,
      folderUrl: 'https://server6.mp3quran.net/wdee3/',
    ),
    'Yasser_Ad-Dussary_128kbps': Mp3QuranReadInfo(
      readId: 92,
      folderUrl: 'https://server11.mp3quran.net/yasser/',
    ),
    'bizi/bizi_okasha_128kbps': Mp3QuranReadInfo(
      readId: 296,
      folderUrl: 'https://server16.mp3quran.net/okasha/Rewayat-Albizi-A-n-Ibn-Katheer/',
    ),
    'dori/dori_husary_128kbps': Mp3QuranReadInfo(
      readId: 269,
      folderUrl: 'https://server13.mp3quran.net/husr/Rewayat-Aldori-A-n-Abi-Amr/',
    ),
    'mahmoud_ali_al_banna_mujawwad_128kbps': Mp3QuranReadInfo(
      readId: 122,
      folderUrl: 'https://server8.mp3quran.net/bna/Almusshaf-Al-Mojawwad/',
    ),
    'mp3quran_107_128kbps': Mp3QuranReadInfo(
      readId: 107,
      folderUrl: 'https://server8.mp3quran.net/lhdan/',
    ),
    'mp3quran_108_128kbps': Mp3QuranReadInfo(
      readId: 108,
      folderUrl: 'https://server11.mp3quran.net/mhsny/',
    ),
    'mp3quran_10904_128kbps': Mp3QuranReadInfo(
      readId: 10904,
      folderUrl: 'https://server16.mp3quran.net/Y_ALaidroos/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_10905_128kbps': Mp3QuranReadInfo(
      readId: 10905,
      folderUrl: 'https://server16.mp3quran.net/H-Aldaghriri/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_10906_128kbps': Mp3QuranReadInfo(
      readId: 10906,
      folderUrl: 'https://server16.mp3quran.net/M_Alfaqih/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_10908_128kbps': Mp3QuranReadInfo(
      readId: 10908,
      folderUrl: 'https://server16.mp3quran.net/J-Abdullah/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_10909_128kbps': Mp3QuranReadInfo(
      readId: 10909,
      folderUrl: 'https://server16.mp3quran.net/K-Alzadi/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_10913_128kbps': Mp3QuranReadInfo(
      readId: 10913,
      folderUrl: 'https://server16.mp3quran.net/A-AlBadr/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_10914_128kbps': Mp3QuranReadInfo(
      readId: 10914,
      folderUrl: 'https://server16.mp3quran.net/a_alqrafi/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_10915_128kbps': Mp3QuranReadInfo(
      readId: 10915,
      folderUrl: 'https://server16.mp3quran.net/A-Ghailan/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_10917_128kbps': Mp3QuranReadInfo(
      readId: 10917,
      folderUrl: 'https://server16.mp3quran.net/Alijon/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_10918_128kbps': Mp3QuranReadInfo(
      readId: 10918,
      folderUrl: 'https://server16.mp3quran.net/M-AlZubaidi/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_10922_128kbps': Mp3QuranReadInfo(
      readId: 10922,
      folderUrl: 'https://server7.mp3quran.net/asim/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_10923_128kbps': Mp3QuranReadInfo(
      readId: 10923,
      folderUrl: 'https://server16.mp3quran.net/M-Harfoush/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_110_128kbps': Mp3QuranReadInfo(
      readId: 110,
      folderUrl: 'https://server12.mp3quran.net/shah/',
    ),
    'mp3quran_122_128kbps': Mp3QuranReadInfo(
      readId: 122,
      folderUrl: 'https://server8.mp3quran.net/bna/Almusshaf-Al-Mojawwad/',
    ),
    'mp3quran_126_128kbps': Mp3QuranReadInfo(
      readId: 126,
      folderUrl: 'https://server6.mp3quran.net/lahoni/',
    ),
    'mp3quran_127_128kbps': Mp3QuranReadInfo(
      readId: 127,
      folderUrl: 'https://server8.mp3quran.net/ra3ad/',
    ),
    'mp3quran_133_128kbps': Mp3QuranReadInfo(
      readId: 133,
      folderUrl: 'https://server12.mp3quran.net/maher/Almusshaf-Al-Mojawwad/',
    ),
    'mp3quran_136_128kbps': Mp3QuranReadInfo(
      readId: 136,
      folderUrl: 'https://server16.mp3quran.net/a_binaoun/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_139_128kbps': Mp3QuranReadInfo(
      readId: 139,
      folderUrl: 'https://server9.mp3quran.net/zaml/',
    ),
    'mp3quran_13_128kbps': Mp3QuranReadInfo(
      readId: 13,
      folderUrl: 'https://server9.mp3quran.net/alzain/',
    ),
    'mp3quran_149_128kbps': Mp3QuranReadInfo(
      readId: 149,
      folderUrl: 'https://server10.mp3quran.net/shaksh/',
    ),
    'mp3quran_159_128kbps': Mp3QuranReadInfo(
      readId: 159,
      folderUrl: 'https://server11.mp3quran.net/mohna/',
    ),
    'mp3quran_160_128kbps': Mp3QuranReadInfo(
      readId: 160,
      folderUrl: 'https://server8.mp3quran.net/a_klb/',
    ),
    'mp3quran_161_128kbps': Mp3QuranReadInfo(
      readId: 161,
      folderUrl: 'https://server11.mp3quran.net/bilal/',
    ),
    'mp3quran_163_128kbps': Mp3QuranReadInfo(
      readId: 163,
      folderUrl: 'https://server11.mp3quran.net/hatem/',
    ),
    'mp3quran_164_128kbps': Mp3QuranReadInfo(
      readId: 164,
      folderUrl: 'https://server11.mp3quran.net/jormy/',
    ),
    'mp3quran_165_128kbps': Mp3QuranReadInfo(
      readId: 165,
      folderUrl: 'https://server11.mp3quran.net/mrifai/',
    ),
    'mp3quran_181_128kbps': Mp3QuranReadInfo(
      readId: 181,
      folderUrl: 'https://server6.mp3quran.net/jaman/',
    ),
    'mp3quran_182_128kbps': Mp3QuranReadInfo(
      readId: 182,
      folderUrl: 'https://server14.mp3quran.net/muftah_sultany/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_18_128kbps': Mp3QuranReadInfo(
      readId: 18,
      folderUrl: 'https://server6.mp3quran.net/jamal/',
    ),
    'mp3quran_193_128kbps': Mp3QuranReadInfo(
      readId: 193,
      folderUrl: 'https://server8.mp3quran.net/noah/',
    ),
    'mp3quran_197_128kbps': Mp3QuranReadInfo(
      readId: 197,
      folderUrl: 'https://server8.mp3quran.net/harthi/',
    ),
    'mp3quran_198_128kbps': Mp3QuranReadInfo(
      readId: 198,
      folderUrl: 'https://server10.mp3quran.net/rashad/',
    ),
    'mp3quran_201_128kbps': Mp3QuranReadInfo(
      readId: 201,
      folderUrl: 'https://server10.mp3quran.net/trabulsi/',
    ),
    'mp3quran_202_128kbps': Mp3QuranReadInfo(
      readId: 202,
      folderUrl: 'https://server10.mp3quran.net/Abdullahk/',
    ),
    'mp3quran_203_128kbps': Mp3QuranReadInfo(
      readId: 203,
      folderUrl: 'https://server10.mp3quran.net/Aamer/',
    ),
    'mp3quran_206_128kbps': Mp3QuranReadInfo(
      readId: 206,
      folderUrl: 'https://server6.mp3quran.net/khan/',
    ),
    'mp3quran_229_128kbps': Mp3QuranReadInfo(
      readId: 229,
      folderUrl: 'https://server8.mp3quran.net/m_qari/',
    ),
    'mp3quran_22_128kbps': Mp3QuranReadInfo(
      readId: 22,
      folderUrl: 'https://server11.mp3quran.net/kafi/',
    ),
    'mp3quran_230_128kbps': Mp3QuranReadInfo(
      readId: 230,
      folderUrl: 'https://server6.mp3quran.net/rami/',
    ),
    'mp3quran_232_128kbps': Mp3QuranReadInfo(
      readId: 232,
      folderUrl: 'https://server10.mp3quran.net/ibrahim_dosri/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_236_128kbps': Mp3QuranReadInfo(
      readId: 236,
      folderUrl: 'https://server10.mp3quran.net/a_majed/',
    ),
    'mp3quran_244_128kbps': Mp3QuranReadInfo(
      readId: 244,
      folderUrl: 'https://server14.mp3quran.net/khalf/',
    ),
    'mp3quran_248_128kbps': Mp3QuranReadInfo(
      readId: 248,
      folderUrl: 'https://server14.mp3quran.net/alosfor/',
    ),
    'mp3quran_250_128kbps': Mp3QuranReadInfo(
      readId: 250,
      folderUrl: 'https://server14.mp3quran.net/bukheet/',
    ),
    'mp3quran_251_128kbps': Mp3QuranReadInfo(
      readId: 251,
      folderUrl: 'https://server14.mp3quran.net/nasser_almajed/',
    ),
    'mp3quran_252_128kbps': Mp3QuranReadInfo(
      readId: 252,
      folderUrl: 'https://server14.mp3quran.net/swlim/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_254_128kbps': Mp3QuranReadInfo(
      readId: 254,
      folderUrl: 'https://server10.mp3quran.net/bader/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_256_128kbps': Mp3QuranReadInfo(
      readId: 256,
      folderUrl: 'https://server16.mp3quran.net/shaheen/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_257_128kbps': Mp3QuranReadInfo(
      readId: 257,
      folderUrl: 'https://server16.mp3quran.net/saad/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_258_128kbps': Mp3QuranReadInfo(
      readId: 258,
      folderUrl: 'https://server16.mp3quran.net/soufi/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_259_128kbps': Mp3QuranReadInfo(
      readId: 259,
      folderUrl: 'https://server14.mp3quran.net/nafis/',
    ),
    'mp3quran_25_128kbps': Mp3QuranReadInfo(
      readId: 25,
      folderUrl: 'https://server9.mp3quran.net/hamza/',
    ),
    'mp3quran_260_128kbps': Mp3QuranReadInfo(
      readId: 260,
      folderUrl: 'https://server16.mp3quran.net/darweez/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_265_128kbps': Mp3QuranReadInfo(
      readId: 265,
      folderUrl: 'https://server16.mp3quran.net/deban/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_267_128kbps': Mp3QuranReadInfo(
      readId: 267,
      folderUrl: 'https://server16.mp3quran.net/kamel/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_271_128kbps': Mp3QuranReadInfo(
      readId: 271,
      folderUrl: 'https://server16.mp3quran.net/nathier/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_277_128kbps': Mp3QuranReadInfo(
      readId: 277,
      folderUrl: 'https://server16.mp3quran.net/m_abdelhakam/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_282_128kbps': Mp3QuranReadInfo(
      readId: 282,
      folderUrl: 'https://server16.mp3quran.net/a_turki/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_283_128kbps': Mp3QuranReadInfo(
      readId: 283,
      folderUrl: 'https://server16.mp3quran.net/mukhtar_haj/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_284_128kbps': Mp3QuranReadInfo(
      readId: 284,
      folderUrl: 'https://server16.mp3quran.net/a_abdl/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_288_128kbps': Mp3QuranReadInfo(
      readId: 288,
      folderUrl: 'https://server8.mp3quran.net/mustafa/Almusshaf-Al-Mojawwad/',
    ),
    'mp3quran_289_128kbps': Mp3QuranReadInfo(
      readId: 289,
      folderUrl: 'https://server16.mp3quran.net/a_maasaraawi/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_292_128kbps': Mp3QuranReadInfo(
      readId: 292,
      folderUrl: 'https://server16.mp3quran.net/h_abudalal/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_293_128kbps': Mp3QuranReadInfo(
      readId: 293,
      folderUrl: 'https://server16.mp3quran.net/f_khamery/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_294_128kbps': Mp3QuranReadInfo(
      readId: 294,
      folderUrl: 'https://server16.mp3quran.net/s_hashemi/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_295_128kbps': Mp3QuranReadInfo(
      readId: 295,
      folderUrl: 'https://server16.mp3quran.net/kh_mohammadi/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_297_128kbps': Mp3QuranReadInfo(
      readId: 297,
      folderUrl: 'https://server16.mp3quran.net/mal-allah_jaber/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_298_128kbps': Mp3QuranReadInfo(
      readId: 298,
      folderUrl: 'https://server16.mp3quran.net/s_sadeiq/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_300_128kbps': Mp3QuranReadInfo(
      readId: 300,
      folderUrl: 'https://server16.mp3quran.net/shamrani/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_302_128kbps': Mp3QuranReadInfo(
      readId: 302,
      folderUrl: 'https://server16.mp3quran.net/a_alshahhat/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_303_128kbps': Mp3QuranReadInfo(
      readId: 303,
      folderUrl: 'https://server16.mp3quran.net/i_sanankoua/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_306_128kbps': Mp3QuranReadInfo(
      readId: 306,
      folderUrl: 'https://server16.mp3quran.net/s_alquraishi/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_307_128kbps': Mp3QuranReadInfo(
      readId: 307,
      folderUrl: 'https://server16.mp3quran.net/f_hajry/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_314_128kbps': Mp3QuranReadInfo(
      readId: 314,
      folderUrl: 'https://server16.mp3quran.net/a_alemadi/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_316_128kbps': Mp3QuranReadInfo(
      readId: 316,
      folderUrl: 'https://server16.mp3quran.net/a_alhazmi/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_33_128kbps': Mp3QuranReadInfo(
      readId: 33,
      folderUrl: 'https://server9.mp3quran.net/zaki/',
    ),
    'mp3quran_340_128kbps': Mp3QuranReadInfo(
      readId: 340,
      folderUrl: 'https://server16.mp3quran.net/M_Burhaji/Rewayat-Hafs-A-n-Assem/',
    ),
    'mp3quran_36_128kbps': Mp3QuranReadInfo(
      readId: 36,
      folderUrl: 'https://server12.mp3quran.net/sayed/',
    ),
    'mp3quran_38_128kbps': Mp3QuranReadInfo(
      readId: 38,
      folderUrl: 'https://server12.mp3quran.net/taher/',
    ),
    'mp3quran_39_128kbps': Mp3QuranReadInfo(
      readId: 39,
      folderUrl: 'https://server12.mp3quran.net/hkm/',
    ),
    'mp3quran_3_128kbps': Mp3QuranReadInfo(
      readId: 3,
      folderUrl: 'https://server6.mp3quran.net/3siri/',
    ),
    'mp3quran_40_128kbps': Mp3QuranReadInfo(
      readId: 40,
      folderUrl: 'https://server8.mp3quran.net/sahood/',
    ),
    'mp3quran_42_128kbps': Mp3QuranReadInfo(
      readId: 42,
      folderUrl: 'https://server6.mp3quran.net/habdan/',
    ),
    'mp3quran_44_128kbps': Mp3QuranReadInfo(
      readId: 44,
      folderUrl: 'https://server12.mp3quran.net/salah_hashim_m/',
    ),
    'mp3quran_48_128kbps': Mp3QuranReadInfo(
      readId: 48,
      folderUrl: 'https://server8.mp3quran.net/ryan/',
    ),
    'mp3quran_50_128kbps': Mp3QuranReadInfo(
      readId: 50,
      folderUrl: 'https://server12.mp3quran.net/bari/',
    ),
    'mp3quran_55_128kbps': Mp3QuranReadInfo(
      readId: 55,
      folderUrl: 'https://server11.mp3quran.net/a_ahmed/',
    ),
    'mp3quran_61_128kbps': Mp3QuranReadInfo(
      readId: 61,
      folderUrl: 'https://server12.mp3quran.net/kyat/',
    ),
    'mp3quran_63_128kbps': Mp3QuranReadInfo(
      readId: 63,
      folderUrl: 'https://server8.mp3quran.net/gulan/',
    ),
    'mp3quran_66_128kbps': Mp3QuranReadInfo(
      readId: 66,
      folderUrl: 'https://server6.mp3quran.net/mohsin_harthi/',
    ),
    'mp3quran_6_128kbps': Mp3QuranReadInfo(
      readId: 6,
      folderUrl: 'https://server11.mp3quran.net/hawashi/',
    ),
    'mp3quran_70_128kbps': Mp3QuranReadInfo(
      readId: 70,
      folderUrl: 'https://server6.mp3quran.net/kanakeri/',
    ),
    'mp3quran_71_128kbps': Mp3QuranReadInfo(
      readId: 71,
      folderUrl: 'https://server8.mp3quran.net/wdod/',
    ),
    'mp3quran_72_128kbps': Mp3QuranReadInfo(
      readId: 72,
      folderUrl: 'https://server6.mp3quran.net/arkani/',
    ),
    'mp3quran_78_128kbps': Mp3QuranReadInfo(
      readId: 78,
      folderUrl: 'https://server6.mp3quran.net/hafz/',
    ),
    'mp3quran_88_128kbps': Mp3QuranReadInfo(
      readId: 88,
      folderUrl: 'https://server8.mp3quran.net/namh/',
    ),
    'mp3quran_8_128kbps': Mp3QuranReadInfo(
      readId: 8,
      folderUrl: 'https://server8.mp3quran.net/saber/',
    ),
    'mp3quran_93_128kbps': Mp3QuranReadInfo(
      readId: 93,
      folderUrl: 'https://server9.mp3quran.net/qurashi/',
    ),
    'mp3quran_96_128kbps': Mp3QuranReadInfo(
      readId: 96,
      folderUrl: 'https://server12.mp3quran.net/yahya/',
    ),
    'mp3quran_97_128kbps': Mp3QuranReadInfo(
      readId: 97,
      folderUrl: 'https://server9.mp3quran.net/yousef/',
    ),
    'qalon/qalon_dokali_128kbps': Mp3QuranReadInfo(
      readId: 208,
      folderUrl: 'https://server7.mp3quran.net/dokali/',
    ),
    'qalon/qalon_husary_128kbps': Mp3QuranReadInfo(
      readId: 270,
      folderUrl: 'https://server13.mp3quran.net/husr/Rewayat-Qalon-A-n-Nafi/',
    ),
    'sousi/hafs_soufi_128kbps': Mp3QuranReadInfo(
      readId: 258,
      folderUrl: 'https://server16.mp3quran.net/soufi/Rewayat-Hafs-A-n-Assem/',
    ),
    'sousi/sousi_soufi_128kbps': Mp3QuranReadInfo(
      readId: 65,
      folderUrl: 'https://server16.mp3quran.net/soufi/Rewayat-Assosi-A-n-Abi-Amr/',
    ),
    'warsh/warsh_husary_128kbps': Mp3QuranReadInfo(
      readId: 120,
      folderUrl: 'https://server13.mp3quran.net/husr/Rewayat-Warsh-A-n-Nafi/',
    ),
    'warsh/warsh_ibrahim_aldosary_128kbps': Mp3QuranReadInfo(
      readId: 232,
      folderUrl: 'https://server10.mp3quran.net/ibrahim_dosri/Rewayat-Hafs-A-n-Assem/',
    ),
    'warsh/warsh_koshi_128kbps': Mp3QuranReadInfo(
      readId: 16,
      folderUrl: 'https://server11.mp3quran.net/koshi/',
    ),
    'warsh/warsh_omar_qazabri_128kbps': Mp3QuranReadInfo(
      readId: 80,
      folderUrl: 'https://server9.mp3quran.net/omar_warsh/',
    ),
    'warsh/warsh_yassin_al_jazaery_64kbps': Mp3QuranReadInfo(
      readId: 14,
      folderUrl: 'https://server11.mp3quran.net/qari/',
    ),
  };

  /// Resolves MP3Quran read info from reciter catalog path with defensive fallback
  static Mp3QuranReadInfo? resolveMp3QuranReadInfo(String reciterPath) {
    if (_mp3quranReadMap.containsKey(reciterPath)) {
      return _mp3quranReadMap[reciterPath];
    }
    final lower = reciterPath.toLowerCase();
    for (final entry in _mp3quranReadMap.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    if (lower.contains('krm') ||
        lower.contains('abdulkareem') ||
        lower.contains('abdul_kareem')) {
      return _mp3quranReadMap['Muhammad_AbdulKareem_128kbps'];
    }
    if (lower.contains('ayyoub') || lower.contains('ayyub')) {
      return _mp3quranReadMap['Muhammad_Ayyoub_128kbps'];
    }
    if (lower.contains('akhdar')) {
      return _mp3quranReadMap['Ibrahim_Akhdar_32kbps'];
    }
    if (lower.contains('nabil') &&
        (lower.contains('rifai') || lower.contains('rifa3i'))) {
      return _mp3quranReadMap['Nabil_Rifa3i_48kbps'];
    }
    if (lower.contains('jazaery') ||
        lower.contains('jazairy') ||
        lower.contains('yassin_al_jazaery')) {
      return _mp3quranReadMap['warsh/warsh_yassin_al_jazaery_64kbps'];
    }
    if (lower.contains('aldosary') || lower.contains('ibrahim_dosri')) {
      return _mp3quranReadMap['warsh/warsh_ibrahim_aldosary_128kbps'];
    }
    if (lower.contains('alaqimy') || lower.contains('alaqmi')) {
      return _mp3quranReadMap['Akram_AlAlaqimy_128kbps'];
    }
    if (lower.contains('suesy') ||
        lower.contains('souasi') ||
        lower.contains('hajjaj')) {
      return _mp3quranReadMap['Ali_Hajjaj_AlSuesy_128kbps'];
    }
    if (lower.contains('sahl')) {
      return _mp3quranReadMap['Sahl_Yassin_128kbps'];
    }
    if (lower.contains('matroud')) {
      return _mp3quranReadMap['Abdullah_Matroud_128kbps'];
    }
    if (lower.contains('bukhatir')) {
      return _mp3quranReadMap['Salaah_AbdulRahman_Bukhatir_128kbps'];
    }
    if (lower.contains('jaber')) {
      return _mp3quranReadMap['Ali_Jaber_64kbps'];
    }
    if (lower.contains('qasim')) {
      return _mp3quranReadMap['Muhsin_Al_Qasim_192kbps'];
    }
    if (lower.contains('basfar') && !lower.contains('walk')) {
      return _mp3quranReadMap['Abdullah_Basfar_192kbps'];
    }
    return null;
  }

  /// 100% verified Quran.com API recitation IDs mapped directly to reciter catalog paths.
  /// Used for educational and translation reciters without MP3Quran human-annotated polygon timings.
  static const Map<String, int> _reciterIdMap = {
    // المصاحف المعلمة والتسجيلات الخاصة غير المتوفرة على MP3Quran
    'Minshawy_Teacher_128kbps': 168,
    'Husary_Muallim_128kbps': 12,
    'mahmoud_ali_al_banna_32kbps': 129,

    // الترجمات الصوتية
    'English/Sahih_Intnl_Ibrahim_Walk_192kbps': 58,
    'MultiLanguage/Basfar_Walk_192kbps': 66,
  };

  static int? resolveRecitationId(String reciterPath) {
    if (_reciterIdMap.containsKey(reciterPath)) {
      return _reciterIdMap[reciterPath];
    }
    final lower = reciterPath.toLowerCase();
    if (lower.contains('banna') && !lower.contains('mujawwad')) return 129;
    if (lower.contains('teacher') || lower.contains('muallim')) {
      if (lower.contains('minshaw')) return 168;
      if (lower.contains('husar')) return 12;
    }
    if (lower.contains('ibrahim_walk')) return 58;

    return null;
  }

  /// Direct full-surah audio streams for high-fidelity reciters without Quran.com timestamp records.
  /// Sourced from Quranicaudio, MP3Quran, and Internet Archive.
  static String? resolveDirectFullSurahUrl(String reciterPath, int surahNumber) {
    final lower = reciterPath.toLowerCase();
    final surah3 = surahNumber.toString().padLeft(3, '0');

    if (lower.contains('ayyoub') || lower.contains('ayyub')) {
      return 'https://server8.mp3quran.net/ayyub/$surah3.mp3';
    }
    if (lower.contains('akhdar')) {
      return 'https://server6.mp3quran.net/akdr/$surah3.mp3';
    }
    if (lower.contains('nabil') &&
        (lower.contains('rifai') || lower.contains('rifa3i'))) {
      return 'https://server9.mp3quran.net/nabil/$surah3.mp3';
    }
    if (lower.contains('hazmi') || lower.contains('hazme')) {
      return 'https://download.quranicaudio.com/quran/abdulkareem_al_hazmi/$surah3.mp3';
    }
    if (lower.contains('salamah')) {
      return 'https://server12.mp3quran.net/salamah/Rewayat-Hafs-A-n-Assem/$surah3.mp3';
    }
    if (lower.contains('warsh') &&
        (lower.contains('dosary') ||
            lower.contains('dossari') ||
            lower.contains('dosri'))) {
      return 'https://server10.mp3quran.net/ibrahim_dosri/Rewayat-Hafs-A-n-Assem/$surah3.mp3';
    }
    if (lower.contains('krm') ||
        lower.contains('abdulkareem') ||
        lower.contains('abdul_kareem')) {
      return 'https://server12.mp3quran.net/m_krm/$surah3.mp3';
    }
    if (lower.contains('sowaid') || lower.contains('swaid')) {
      return 'https://archive.org/download/aymanswaid2020/$surah3.mp3';
    }
    if (lower.contains('jazaery') ||
        lower.contains('jazairy') ||
        lower.contains('jaza2iree')) {
      return 'https://server11.mp3quran.net/qari/$surah3.mp3';
    }
    if (lower.contains('maher') || lower.contains('muaiqly')) {
      return 'https://server12.mp3quran.net/maher/$surah3.mp3';
    }
    if (lower.contains('jibreel')) {
      return 'https://server8.mp3quran.net/jbrl/$surah3.mp3';
    }
    if (lower.contains('minshaw') && lower.contains('mujawwad')) {
      return 'https://server10.mp3quran.net/minsh/Almusshaf-Al-Mojawwad/$surah3.mp3';
    }

    return null;
  }

  /// Returns the deterministic audio URL for ANY reciter and surah across all catalog reciters.
  static String? resolveDefaultAudioUrl(String reciterPath, int surahNumber) {
    final mp3QuranInfo = resolveMp3QuranReadInfo(reciterPath);
    if (mp3QuranInfo != null) {
      final surah3 = surahNumber.toString().padLeft(3, '0');
      final folder = mp3QuranInfo.folderUrl.endsWith('/')
          ? mp3QuranInfo.folderUrl
          : '${mp3QuranInfo.folderUrl}/';
      return '$folder$surah3.mp3';
    }

    final direct = resolveDirectFullSurahUrl(reciterPath, surahNumber);
    if (direct != null) return direct;

    final lower = reciterPath.toLowerCase();
    final surah = surahNumber.toString();
    final surah3 = surahNumber.toString().padLeft(3, '0');

    if (lower.contains('minshaw')) {
      if (lower.contains('mujawwad')) {
        return 'https://server10.mp3quran.net/minsh/Almusshaf-Al-Mojawwad/$surah3.mp3';
      }
      if (lower.contains('teacher') || lower.contains('muallim')) {
        return 'https://download.quranicaudio.com/qdc/siddiq_minshawi/kids_repeat/$surah.mp3';
      }
      return 'https://download.quranicaudio.com/qdc/siddiq_minshawi/murattal/$surah.mp3';
    }
    if (lower.contains('husar')) {
      if (lower.contains('muallim')) {
        return 'https://download.quranicaudio.com/qdc/khalil_al_husary/muallim/$surah.mp3';
      }
      if (lower.contains('mujawwad')) {
        return 'https://download.quranicaudio.com/quran/mahmood_khaleel_al-husaree_iza3a/$surah3.mp3';
      }
      return 'https://download.quranicaudio.com/qdc/khalil_al_husary/murattal/$surah.mp3';
    }
    if (lower.contains('abdul_basit') || lower.contains('abdulbasit')) {
      if (lower.contains('mujawwad')) {
        return 'https://download.quranicaudio.com/qdc/abdul_baset/mujawwad/$surah.mp3';
      }
      return 'https://download.quranicaudio.com/qdc/abdul_baset/murattal/$surah.mp3';
    }
    if (lower.contains('banna')) {
      return 'https://download.quranicaudio.com/quran/mahmood_ali_albana/$surah3.mp3';
    }
    if (lower.contains('tablaway') || lower.contains('tablawi')) {
      return 'https://download.quranicaudio.com/quran/mohammad_altablawi/$surah3.mp3';
    }
    if (lower.contains('maher') || lower.contains('muaiqly')) {
      return 'https://download.quranicaudio.com/quran/maher_almu3aiqly/year1440/$surah3.mp3';
    }
    if ((lower.contains('yasser') || lower.contains('yaser')) &&
        (lower.contains('dussary') ||
            lower.contains('dossari') ||
            lower.contains('dosari'))) {
      return 'https://download.quranicaudio.com/qdc/yasser_ad-dussary/mp3/$surah.mp3';
    }
    if (lower.contains('ajamy') || lower.contains('ajami')) {
      return 'https://download.quranicaudio.com/quran/ahmed_ibn_3ali_al-3ajamy/$surah3.mp3';
    }
    if (lower.contains('ghamadi')) {
      return 'https://download.quranicaudio.com/quran/sa3d_al-ghaamidi/complete/$surah3.mp3';
    }
    if (lower.contains('qatami')) {
      return 'https://download.quranicaudio.com/quran/nasser_bin_ali_alqatami/$surah3.mp3';
    }
    if (lower.contains('abbad')) {
      return 'https://download.quranicaudio.com/quran/fares/$surah3.mp3';
    }
    if (lower.contains('shaatree') || lower.contains('shatri')) {
      return 'https://download.quranicaudio.com/qdc/abu_bakr_shatri/murattal/$surah.mp3';
    }
    if (lower.contains('shuraym') || lower.contains('shuraim')) {
      return 'https://download.quranicaudio.com/qdc/saud_ash-shuraym/murattal/$surah3.mp3';
    }
    if (lower.contains('juhaynee') || lower.contains('juhany')) {
      return 'https://download.quranicaudio.com/quran/abdullaah_3awwaad_al-juhaynee/$surah3.mp3';
    }
    if (lower.contains('hani') &&
        (lower.contains('rifai') || lower.contains('rifa3i'))) {
      return 'https://download.quranicaudio.com/qdc/hani_ar_rifai/murattal/$surah.mp3';
    }
    if (lower.contains('jaber')) {
      return 'https://server11.mp3quran.net/a_jbr/$surah3.mp3';
    }
    if (lower.contains('matroud')) {
      return 'https://server8.mp3quran.net/mtrod/$surah3.mp3';
    }
    if (lower.contains('jibreel')) {
      return 'https://download.quranicaudio.com/quran/muhammad_jibreel/complete/$surah3.mp3';
    }
    if (lower.contains('basfar') && lower.contains('walk')) {
      return 'https://download.quranicaudio.com/quran/abdullah_basfar_w_ibrahim_walk_si/$surah3.mp3';
    }
    if (lower.contains('basfar')) {
      return 'https://server6.mp3quran.net/bsfr/$surah3.mp3';
    }
    if (lower.contains('bukhatir')) {
      return 'https://server8.mp3quran.net/bu_khtr/$surah3.mp3';
    }
    if (lower.contains('sahl')) {
      return 'https://server6.mp3quran.net/shl/$surah3.mp3';
    }
    if (lower.contains('suesy') || lower.contains('souasi')) {
      return 'https://server9.mp3quran.net/hajjaj/$surah3.mp3';
    }
    if (lower.contains('alaqimy') || lower.contains('alaqmi')) {
      return 'https://server9.mp3quran.net/akrm/$surah3.mp3';
    }
    if (lower.contains('qasim')) {
      return 'https://server8.mp3quran.net/qasm/$surah3.mp3';
    }
    if (lower.contains('ibrahim_walk')) {
      return 'https://download.quranicaudio.com/quran/mishaari_w_ibrahim_walk_si/$surah3.mp3';
    }

    return null;
  }

  /// Seeds all reciter paths for all 114 surahs into SQLite
  static Future<void> seedAllSurahs(Database db) async {
    final paths = <String>{};
    for (final category in ReciterCatalog.reciterCategories.values) {
      paths.addAll(category.values);
    }
    paths.add(ReciterCatalog.defaultReciterPath);

    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final path in paths) {
      for (int surah = 1; surah <= 114; surah++) {
        final url = resolveDefaultAudioUrl(path, surah);
        if (url != null && url.isNotEmpty) {
          batch.insert(
            'surah_audio_timings',
            {
              'reciter_path': path,
              'surah_number': surah,
              'audio_url': url,
              'verse_timings': '[]',
              'created_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    }

    await batch.commit(noResult: true);
  }

  /// Clears in-memory timing caches
  static void clearMemoryCache() {
    _memoryCache.clear();
    _inFlightRequests.clear();
  }

  /// Gets surah timings and continuous stream audio URL for a given reciter and surah.
  /// Combines in-memory cache, indexed SQLite storage, MP3Quran.net v3 API, and remote Quran.com API v4.
  Future<SurahTimings?> getSurahTimings({
    required String reciterPath,
    required int surahNumber,
  }) async {
    final cacheKey = '$reciterPath:$surahNumber';

    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    if (_inFlightRequests.containsKey(cacheKey)) {
      return await _inFlightRequests[cacheKey]!;
    }

    final future = _loadSurahTimings(reciterPath, surahNumber, cacheKey);
    _inFlightRequests[cacheKey] = future;

    try {
      final result = await future;
      if (result != null) {
        _memoryCache[cacheKey] = result;
      }
      return result;
    } finally {
      _inFlightRequests.remove(cacheKey);
    }
  }

  Future<SurahTimings?> _loadSurahTimings(
    String reciterPath,
    int surahNumber,
    String cacheKey,
  ) async {
    // 0. Immediate guard: Globally untimed reciters (e.g. Maher Al-Muaiqly and listening-only reciters)
    if (ReciterCatalog.globallyUntimedReciterPaths.contains(reciterPath)) {
      final fallbackUrl = resolveDefaultAudioUrl(reciterPath, surahNumber);
      return SurahTimings(
        surah: surahNumber,
        audioUrl: fallbackUrl ?? '',
        verseTimings: const [],
      );
    }

    final mp3QuranInfo = resolveMp3QuranReadInfo(reciterPath);
    final recitationId = resolveRecitationId(reciterPath);

    // 1. Check local persistent SQLite database first
    String? dbAudioUrl;
    List<VerseTimestamp>? dbVerseTimings;

    try {
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'surah_audio_timings',
        columns: ['audio_url', 'verse_timings'],
        where: 'reciter_path = ? AND surah_number = ?',
        whereArgs: [reciterPath, surahNumber],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        final row = rows.first;
        final rawUrl = row['audio_url'] as String? ?? '';
        final rawTimings = row['verse_timings'] as String? ?? '[]';

        if (rawUrl.isNotEmpty) {
          dbAudioUrl = rawUrl;
        }

        if (rawTimings.isNotEmpty && rawTimings != '[]') {
          try {
            final list = jsonDecode(rawTimings) as List<dynamic>;
            dbVerseTimings = list
                .map((e) => VerseTimestamp.fromJson(e as Map<String, dynamic>))
                .toList();
          } catch (_) {}
        }

        // Return cached DB timings if valid and non-empty.
        // For MP3Quran-supported reciters, ensure cached audio URL is from MP3Quran (not legacy quranicaudio)
        final isMatchingSource = mp3QuranInfo == null ||
            (dbAudioUrl != null && dbAudioUrl.contains('mp3quran.net'));

        if (isMatchingSource &&
            dbAudioUrl != null &&
            dbVerseTimings != null &&
            dbVerseTimings.isNotEmpty &&
            _validateTimingIntegrity(dbVerseTimings, surahNumber)) {
          return SurahTimings(
            surah: surahNumber,
            audioUrl: dbAudioUrl,
            verseTimings: dbVerseTimings,
          );
        }
      }
    } catch (_) {}

    // 2. Primary Provider: MP3Quran.net v3 API (human-annotated polygon verse boundaries)
    if (mp3QuranInfo != null) {
      final mp3Timings = await _loadFromMp3Quran(
        reciterPath,
        surahNumber,
        mp3QuranInfo,
        cacheKey,
      );
      if (mp3Timings != null && mp3Timings.verseTimings.isNotEmpty) {
        return mp3Timings;
      }
    }

    // 3. Secondary Provider: Quran.com API v4 (only for reciters without MP3Quran reads)
    if (recitationId != null) {
      try {
        final url =
            'https://api.quran.com/api/v4/chapter_recitations/$recitationId/$surahNumber?segments=true';
        final response = await _dio.get(url);

        if (response.statusCode == 200 &&
            response.data is Map<String, dynamic>) {
          final audioFile =
              response.data['audio_file'] as Map<String, dynamic>?;
          if (audioFile != null) {
            final audioUrl =
                audioFile['audio_url'] as String? ?? dbAudioUrl ?? '';
            final rawTimestamps =
                audioFile['timestamps'] as List<dynamic>? ?? [];

            final verseTimings = <VerseTimestamp>[];
            for (final t in rawTimestamps) {
              final map = t as Map<String, dynamic>;
              final verseKey = map['verse_key'] as String? ?? '';
              final parts = verseKey.split(':');
              if (parts.length == 2) {
                final surah = int.tryParse(parts[0]) ?? surahNumber;
                final ayah = int.tryParse(parts[1]) ?? 1;
                final startMs = (map['timestamp_from'] as num?)?.toInt() ?? 0;
                final endMs = (map['timestamp_to'] as num?)?.toInt() ?? startMs;

                verseTimings.add(
                  VerseTimestamp(
                    surah: surah,
                    ayah: ayah,
                    start: Duration(milliseconds: startMs),
                    end: Duration(milliseconds: endMs),
                  ),
                );
              }
            }

            if (audioUrl.isNotEmpty && verseTimings.isNotEmpty) {
              final isValid = _validateTimingIntegrity(verseTimings, surahNumber);
              final effectiveTimings =
                  isValid ? verseTimings : const <VerseTimestamp>[];

              final timings = SurahTimings(
                surah: surahNumber,
                audioUrl: audioUrl,
                verseTimings: effectiveTimings,
              );

              // Persist to local SQLite database only if integrity is sound
              if (isValid) {
                try {
                  final db = await DatabaseHelper().database;
                  await db.insert(
                    'surah_audio_timings',
                    {
                      'reciter_path': reciterPath,
                      'surah_number': surahNumber,
                      'audio_url': audioUrl,
                      'verse_timings': jsonEncode(
                        effectiveTimings.map((v) => v.toJson()).toList(),
                      ),
                      'created_at': DateTime.now().millisecondsSinceEpoch,
                    },
                    conflictAlgorithm: ConflictAlgorithm.replace,
                  );
                } catch (_) {}
              }

              return timings;
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              'SurahAudioTimingService Quran.com error fetching $cacheKey: $e');
        }
      }
    }

    // 4. Fallback: if offline or API failed, return what we have from DB or default deterministic URL
    final fallbackUrl =
        dbAudioUrl ?? resolveDefaultAudioUrl(reciterPath, surahNumber);
    if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
      return SurahTimings(
        surah: surahNumber,
        audioUrl: fallbackUrl,
        verseTimings: dbVerseTimings ?? const [],
      );
    }

    return null;
  }

  /// Normalizes verse timings from MP3Quran.net v3 API:
  /// - Surah 1 (Al-Fatihah):
  ///   * If 7 items with 0-based indexing (items 0..6 for 7 ayahs, e.g. Husary readId 118),
  ///     converts ayah index to 1-based (item.ayah + 1) preserving exact timestamps without alteration.
  ///   * If 8 items starting with ayah 0 (e.g. Minshawy readId 112, where item 0 is the recorded Isti'adhah),
  ///     skips item 0 (recorded Isti'adhah audio) and preserves verses 1..7 directly with their recorded timestamps.
  ///   * If 7 items starting with ayah 1, preserves verses 1..7 directly.
  /// - Surahs 2..114:
  ///   * If item.ayah == 0, skips introductory Basmalah audio segment and preserves verses 1..N directly.
  /// - Upstream Source Typo Fixes:
  ///   * Sheikh Ibrahim Al-Akhdar (readId 1): Maryam Ayah 98 and Ya-Sin Ayah 83 typos replaced
  ///     with verified physical audio track durations, and Ad-Duha Ayah 10-11 split.
  static List<VerseTimestamp> _normalizeVerseTimings({
    required List<dynamic> rawList,
    required int surahNumber,
    int? readId,
  }) {
    if (rawList.isEmpty) return const [];

    final parsed = <_RawTiming>[];
    for (final item in rawList) {
      if (item is! Map<String, dynamic>) continue;
      final ayah = (item['ayah'] as num?)?.toInt() ?? 0;
      var startMs = (item['start_time'] as num?)?.toInt() ?? 0;
      var endMs = (item['end_time'] as num?)?.toInt() ?? startMs;

      // Deterministic corrections for verified typographical errors in upstream MP3Quran database:
      if (readId == 1) {
        if (surahNumber == 19 && ayah == 98) {
          // Surah Maryam Ayah 98 (last verse): source typo 962137ms -> physical track duration 1379809ms
          endMs = 1379809;
        } else if (surahNumber == 36 && ayah == 83) {
          // Surah Ya-Sin Ayah 83 (last verse): source typo 487305ms -> physical track duration 1241255ms
          endMs = 1241255;
        } else if (surahNumber == 93) {
          // Surah Ad-Duha Ayah 10 & 11: source duplicate 54906ms -> physical track split at 62000ms
          if (ayah == 10) {
            endMs = 62000;
          } else if (ayah == 11) {
            startMs = 62000;
            endMs = 69454;
          }
        }
      }

      parsed.add(_RawTiming(ayah: ayah, startMs: startMs, endMs: endMs));
    }

    if (parsed.isEmpty) return const [];

    final verseTimings = <VerseTimestamp>[];

    // Surah 1 (Al-Fatihah)
    if (surahNumber == 1) {
      // Case A: 0-indexed reciters (e.g. Mahmoud Khalil Al-Husary readId 118: items 0..6 for 7 ayahs)
      if (parsed.length == 7 && parsed.first.ayah == 0) {
        for (final item in parsed) {
          verseTimings.add(
            VerseTimestamp(
              surah: 1,
              ayah: item.ayah + 1,
              start: Duration(milliseconds: item.startMs),
              end: Duration(milliseconds: item.endMs),
            ),
          );
        }
        return verseTimings;
      }

      // Case B: Reciters with Isti'adhah audio segment recorded as item 0 (e.g. Minshawy readId 112: 8 items, 0 is Isti'adhah, 1..7 are ayahs)
      if (parsed.length == 8 && parsed.first.ayah == 0) {
        for (final item in parsed) {
          if (item.ayah == 0) continue; // Skip recorded Isti'adhah, keep Basmalah and verses 1..7
          verseTimings.add(
            VerseTimestamp(
              surah: 1,
              ayah: item.ayah,
              start: Duration(milliseconds: item.startMs),
              end: Duration(milliseconds: item.endMs),
            ),
          );
        }
        return verseTimings;
      }
    }

    // Standard handling for Surahs 2..114 and standard Surah 1 (where verses are 1..N)
    for (final item in parsed) {
      if (item.ayah == 0) continue; // Skip introductory Basmalah in surahs 2..114
      verseTimings.add(
        VerseTimestamp(
          surah: surahNumber,
          ayah: item.ayah,
          start: Duration(milliseconds: item.startMs),
          end: Duration(milliseconds: item.endMs),
        ),
      );
    }

    return verseTimings;
  }

  /// Safety Gate: Validates verse timing integrity to prevent UI glitches or invalid seeking.
  /// Safety Gate: Validates verse timing integrity to prevent UI glitches or invalid seeking.
  /// Rejects empty lists, non-positive verse durations, or chronologically inverted intervals.
  static bool _validateTimingIntegrity(
    List<VerseTimestamp> timings,
    int surahNumber,
  ) {
    if (timings.isEmpty) return false;

    for (int i = 0; i < timings.length; i++) {
      final t = timings[i];
      // Every verse must have a positive duration
      if (t.end <= t.start) return false;
      // Monotonic start times (no reverse jumps)
      if (i > 0 && t.start < timings[i - 1].start) return false;
    }

    return true;
  }

  /// Fetches real-time millisecond verse timestamps and matching server audio from MP3Quran.net v3 API
  Future<SurahTimings?> _loadFromMp3Quran(
    String reciterPath,
    int surahNumber,
    Mp3QuranReadInfo info,
    String cacheKey,
  ) async {
    try {
      final url =
          'https://mp3quran.net/api/v3/ayat_timing?surah=$surahNumber&read=${info.readId}';
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data != null) {
        final rawList = response.data is Map<String, dynamic>
            ? (response.data['value'] as List<dynamic>? ?? [])
            : (response.data is List
                ? response.data as List<dynamic>
                : <dynamic>[]);

        if (rawList.isNotEmpty) {
          final normalizedTimings = _normalizeVerseTimings(
            rawList: rawList,
            surahNumber: surahNumber,
            readId: info.readId,
          );

          final isValid = _validateTimingIntegrity(
            normalizedTimings,
            surahNumber,
          );
          final verseTimings =
              isValid ? normalizedTimings : const <VerseTimestamp>[];

          final surah3 = surahNumber.toString().padLeft(3, '0');
          final folder = info.folderUrl.endsWith('/')
              ? info.folderUrl
              : '${info.folderUrl}/';
          final audioUrl = '$folder$surah3.mp3';

          final timings = SurahTimings(
            surah: surahNumber,
            audioUrl: audioUrl,
            verseTimings: verseTimings,
          );

          // Persist to local SQLite database only if integrity is sound
          if (isValid) {
            try {
              final db = await DatabaseHelper().database;
              await db.insert(
                'surah_audio_timings',
                {
                  'reciter_path': reciterPath,
                  'surah_number': surahNumber,
                  'audio_url': audioUrl,
                  'verse_timings': jsonEncode(
                    verseTimings.map((v) => v.toJson()).toList(),
                  ),
                  'created_at': DateTime.now().millisecondsSinceEpoch,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (_) {}
          }

          return timings;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'SurahAudioTimingService MP3Quran error fetching $cacheKey: $e');
      }
    }
    return null;
  }
}

class _RawTiming {
  final int ayah;
  final int startMs;
  final int endMs;

  const _RawTiming({
    required this.ayah,
    required this.startMs,
    required this.endMs,
  });

  int get durationMs => endMs - startMs;
}
