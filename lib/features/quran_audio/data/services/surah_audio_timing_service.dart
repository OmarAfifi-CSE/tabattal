import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/surah_timing_model.dart';

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

  /// 100% verified Quran.com API recitation IDs mapped directly to reciter catalog paths
  static const Map<String, int> _reciterIdMap = {
    // 1. الرعيل الأول وكبار القراء
    'Minshawy_Murattal_128kbps': 9,
    'Minshawy_Mujawwad_192kbps': 8,
    'Minshawy_Teacher_128kbps': 168,
    'Husary_128kbps': 6,
    'Husary_128kbps_Mujawwad': 122,
    'Husary_Muallim_128kbps': 12,
    'Abdul_Basit_Murattal_192kbps': 2,
    'Abdul_Basit_Mujawwad_128kbps': 1,
    'mahmoud_ali_al_banna_32kbps': 129,
    'Mohammad_al_Tablaway_128kbps': 91,

    // 2. الجيل الحديث وقراء الحرمين
    'MaherAlMuaiqly128kbps': 159,
    'Yasser_Ad-Dussary_128kbps': 174,
    'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net': 19,
    'Ghamadi_40kbps': 13,
    'Nasser_Alqatami_128kbps': 104,
    'Fares_Abbad_64kbps': 14,
    'Abu_Bakr_Ash-Shaatree_128kbps': 4,
    'Saood_ash-Shuraym_128kbps': 10,
    'Abdullaah_3awwaad_Al-Juhaynee_128kbps': 162,
    'Hani_Rifai_192kbps': 5,
    'Ali_Jaber_64kbps': 158,
    'Abdullah_Matroud_128kbps': 124,
    'Muhammad_Jibreel_128kbps': 169,
    'Abdullah_Basfar_192kbps': 163,
    'Salaah_AbdulRahman_Bukhatir_128kbps': 18,
    'Sahl_Yassin_128kbps': 17,
    'Ali_Hajjaj_AlSuesy_128kbps': 128,
    'Akram_AlAlaqimy_128kbps': 127,
    'Muhsin_Al_Qasim_192kbps': 11,
    'Alafasy_128kbps': 7,
    'Mishary_Rashid_Alafasy': 7,

    // 3. الترجمات الصوتية
    'English/Sahih_Intnl_Ibrahim_Walk_192kbps': 58,
    'MultiLanguage/Basfar_Walk_192kbps': 66,
  };

  static int? resolveRecitationId(String reciterPath) {
    if (_reciterIdMap.containsKey(reciterPath)) {
      return _reciterIdMap[reciterPath];
    }
    final lower = reciterPath.toLowerCase();
    if (lower.contains('qatami')) return 104;
    if (lower.contains('maher') || lower.contains('muaiqly')) return 159;
    if ((lower.contains('yasser') || lower.contains('yaser')) &&
        (lower.contains('dussary') ||
            lower.contains('dossari') ||
            lower.contains('dosari'))) {
      return 174;
    }
    if (lower.contains('ghamadi')) return 13;
    if (lower.contains('banna')) return 129;
    if (lower.contains('tablaway') || lower.contains('tablawi')) return 91;
    if (lower.contains('juhaynee') || lower.contains('juhany')) return 162;
    if (lower.contains('jaber')) return 158;
    if (lower.contains('jibreel')) return 169;
    if (lower.contains('matroud')) return 124;
    if (lower.contains('sahl')) return 17;
    if (lower.contains('bukhatir')) return 18;
    if (lower.contains('ajamy') || lower.contains('ajami')) return 19;
    if (lower.contains('abbad')) return 14;
    if (lower.contains('shaatree') || lower.contains('shatri')) return 4;
    if (lower.contains('shuraym') || lower.contains('shuraim')) return 10;
    if (lower.contains('hani') &&
        (lower.contains('rifai') || lower.contains('rifa3i'))) {
      return 5;
    }
    if (lower.contains('alafasy') || lower.contains('afasy')) return 7;
    if (lower.contains('minshaw')) {
      if (lower.contains('mujawwad')) return 8;
      if (lower.contains('teacher') || lower.contains('muallim')) return 168;
      return 9;
    }
    if (lower.contains('abdul_basit') || lower.contains('abdulbasit')) {
      return lower.contains('mujawwad') ? 1 : 2;
    }
    if (lower.contains('husar')) {
      if (lower.contains('muallim')) return 12;
      if (lower.contains('mujawwad')) return 122;
      return 6;
    }
    if (lower.contains('basfar')) return 163;
    if (lower.contains('suesy') || lower.contains('souasi')) return 128;
    if (lower.contains('alaqimy') || lower.contains('alaqmi')) return 127;
    if (lower.contains('qasim')) return 11;
    if (lower.contains('ibrahim_walk')) return 58;

    return null;
  }

  /// Direct full-surah audio streams for high-fidelity reciters without Quran.com timestamp records.
  /// Sourced from Quranicaudio, MP3Quran, and Internet Archive.
  static String? resolveDirectFullSurahUrl(String reciterPath, int surahNumber) {
    final lower = reciterPath.toLowerCase();
    final surah3 = surahNumber.toString().padLeft(3, '0');

    if (lower.contains('huthayfi') || lower.contains('hudhaify')) {
      return 'https://download.quranicaudio.com/quran/huthayfi/$surah3.mp3';
    }
    if (lower.contains('ayyoub') || lower.contains('ayyub')) {
      return 'https://download.quranicaudio.com/quran/muhammad_ayyoob_hq/$surah3.mp3';
    }
    if (lower.contains('qahtaanee') || lower.contains('qahtani')) {
      return 'https://download.quranicaudio.com/quran/khaalid_al-qahtaanee/$surah3.mp3';
    }
    if (lower.contains('akhdar')) {
      return 'https://download.quranicaudio.com/quran/ibrahim_al_akhdar/$surah3.mp3';
    }
    if (lower.contains('nabil') && (lower.contains('rifai') || lower.contains('rifa3i'))) {
      return 'https://download.quranicaudio.com/quran/nabil_rifa3i/$surah3.mp3';
    }
    if (lower.contains('hazmi') || lower.contains('hazme')) {
      return 'https://download.quranicaudio.com/quran/abdulkareem_al_hazmi/$surah3.mp3';
    }
    if (lower.contains('salamah')) {
      return 'https://server12.mp3quran.net/salamah/Rewayat-Hafs-A-n-Assem/$surah3.mp3';
    }
    if (lower.contains('warsh') && (lower.contains('dosary') || lower.contains('dossari') || lower.contains('dosri'))) {
      return 'https://server10.mp3quran.net/ibrahim_dosri/Rewayat-Warsh-A-n-Nafi/$surah3.mp3';
    }
    if (lower.contains('krm') || lower.contains('abdulkareem') || lower.contains('abdul_kareem')) {
      return 'https://server12.mp3quran.net/m_krm/$surah3.mp3';
    }
    if (lower.contains('sowaid') || lower.contains('swaid')) {
      return 'https://archive.org/download/aymanswaid2020/$surah3.mp3';
    }
    if (lower.contains('jazaery') || lower.contains('jazairy') || lower.contains('jaza2iree')) {
      return 'https://server11.mp3quran.net/qari/$surah3.mp3';
    }

    return null;
  }

  /// Clears in-memory timing caches
  static void clearMemoryCache() {
    _memoryCache.clear();
    _inFlightRequests.clear();
  }

  /// Gets surah timings and continuous stream audio URL for a given reciter and surah.
  /// Combines in-memory cache, offline SharedPreferences cache, and remote Quran.com API v4.
  Future<SurahTimings?> getSurahTimings({
    required String reciterPath,
    required int surahNumber,
  }) async {
    final recitationId = resolveRecitationId(reciterPath);
    if (recitationId == null) {
      final directUrl = resolveDirectFullSurahUrl(reciterPath, surahNumber);
      if (directUrl != null) {
        return SurahTimings(
          surah: surahNumber,
          audioUrl: directUrl,
          verseTimings: const [],
        );
      }
      return null;
    }

    final cacheKey = '$recitationId:$surahNumber';

    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    if (_inFlightRequests.containsKey(cacheKey)) {
      return await _inFlightRequests[cacheKey]!;
    }

    final future = _loadSurahTimings(recitationId, surahNumber, cacheKey);
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
    int recitationId,
    int surahNumber,
    String cacheKey,
  ) async {
    // 1. Check local persistent offline cache in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final localJson = prefs.getString('surah_timings_$cacheKey');
      if (localJson != null && localJson.isNotEmpty) {
        final decoded = jsonDecode(localJson) as Map<String, dynamic>;
        final parsed = SurahTimings.fromJson(decoded);
        if (parsed.audioUrl.isNotEmpty || parsed.verseTimings.isNotEmpty) {
          return parsed;
        }
      }
    } catch (_) {}

    // 2. Fetch from Quran.com API v4 with segments=true for verse timestamps
    try {
      final url = 'https://api.quran.com/api/v4/chapter_recitations/$recitationId/$surahNumber?segments=true';
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final audioFile = response.data['audio_file'] as Map<String, dynamic>?;
        if (audioFile != null) {
          final audioUrl = audioFile['audio_url'] as String? ?? '';
          final rawTimestamps = audioFile['timestamps'] as List<dynamic>? ?? [];

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

          if (audioUrl.isNotEmpty) {
            final timings = SurahTimings(
              surah: surahNumber,
              audioUrl: audioUrl,
              verseTimings: verseTimings,
            );

            // Persist to local offline storage
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('surah_timings_$cacheKey', jsonEncode(timings.toJson()));
            } catch (_) {}

            return timings;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SurahAudioTimingService error fetching $cacheKey: $e');
      }
    }

    return null;
  }
}
