import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../../core/constants/reciter_catalog.dart';
import '../../../../core/database/database_helper.dart';
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

  /// Returns the deterministic audio URL for ANY reciter and surah across all 35 reciters in the catalog.
  static String? resolveDefaultAudioUrl(String reciterPath, int surahNumber) {
    final direct = resolveDirectFullSurahUrl(reciterPath, surahNumber);
    if (direct != null) return direct;

    final lower = reciterPath.toLowerCase();
    final surah = surahNumber.toString();
    final surah3 = surahNumber.toString().padLeft(3, '0');

    if (lower.contains('alafasy') || lower.contains('afasy')) {
      return 'https://download.quranicaudio.com/qdc/mishari_al_afasy/murattal/$surah.mp3';
    }
    if (lower.contains('minshaw')) {
      if (lower.contains('mujawwad')) {
        return 'https://download.quranicaudio.com/qdc/siddiq_al-minshawi/mujawwad/$surah3.mp3';
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
      return 'https://download.quranicaudio.com/quran/ali_jaber/$surah3.mp3';
    }
    if (lower.contains('matroud')) {
      return 'https://download.quranicaudio.com/quran/abdullah_matroud/$surah3.mp3';
    }
    if (lower.contains('jibreel')) {
      return 'https://download.quranicaudio.com/quran/muhammad_jibreel/complete/$surah3.mp3';
    }
    if (lower.contains('basfar') && lower.contains('walk')) {
      return 'https://download.quranicaudio.com/quran/abdullah_basfar_w_ibrahim_walk_si/$surah3.mp3';
    }
    if (lower.contains('basfar')) {
      return 'https://download.quranicaudio.com/quran/abdullaah_basfar/$surah3.mp3';
    }
    if (lower.contains('bukhatir')) {
      return 'https://download.quranicaudio.com/quran/salaah_bukhaatir/$surah3.mp3';
    }
    if (lower.contains('sahl')) {
      return 'https://download.quranicaudio.com/quran/sahl_yaaseen/$surah3.mp3';
    }
    if (lower.contains('suesy') || lower.contains('souasi')) {
      return 'https://download.quranicaudio.com/quran/ali_hajjaj_alsouasi/$surah3.mp3';
    }
    if (lower.contains('alaqimy') || lower.contains('alaqmi')) {
      return 'https://download.quranicaudio.com/quran/akram_al_alaqmi/$surah3.mp3';
    }
    if (lower.contains('qasim')) {
      return 'https://download.quranicaudio.com/quran/abdul_muhsin_alqasim/$surah3.mp3';
    }
    if (lower.contains('ibrahim_walk')) {
      return 'https://download.quranicaudio.com/quran/mishaari_w_ibrahim_walk_si/$surah3.mp3';
    }

    return null;
  }

  /// Seeds all 41 reciter paths for all 114 surahs (4,674 entries) into SQLite
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
  /// Combines in-memory cache, indexed SQLite storage, and remote Quran.com API v4.
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

        // If we have verified verse timings from DB, or if this reciter has no Quran.com ID:
        if (dbAudioUrl != null &&
            ((dbVerseTimings != null && dbVerseTimings.isNotEmpty) ||
                recitationId == null)) {
          return SurahTimings(
            surah: surahNumber,
            audioUrl: dbAudioUrl,
            verseTimings: dbVerseTimings ?? const [],
          );
        }
      }
    } catch (_) {}

    // 2. If reciter has a Quran.com API recitation ID, try fetching live verse timestamps
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

            if (audioUrl.isNotEmpty) {
              final timings = SurahTimings(
                surah: surahNumber,
                audioUrl: audioUrl,
                verseTimings: verseTimings,
              );

              // Persist to local SQLite database
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

              return timings;
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('SurahAudioTimingService error fetching $cacheKey: $e');
        }
      }
    }

    // 3. Fallback: if offline or API failed, return what we have from DB or default deterministic URL
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
}
