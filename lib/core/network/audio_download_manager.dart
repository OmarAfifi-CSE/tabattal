import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/quran_metadata.dart';

class AudioDownloadManager {
  final Dio _dio = Dio();

  // Active prefetch tasks to avoid duplicate downloads
  final Map<int, Future<String>> _activePrefetches = {};

  // Grouped Mapping of recitation styles to backend paths
  static const Map<String, Map<String, String>> reciterCategories = {
    'مرتل': {
      // 1. الرعيل الأول وكبار القراء (تلاوات هادئة وتجويد متقن - محل إجماع)
      'محمد صديق المنشاوي': 'Minshawy_Murattal_128kbps',
      'محمود خليل الحصري': 'Husary_128kbps',
      'عبد الباسط عبد الصمد': 'Abdul_Basit_Murattal_192kbps',
      'محمود علي البنا': 'mahmoud_ali_al_banna_32kbps',
      'أحمد نعينع': 'Ahmed_Neana_128kbps',

      // 2. الجيل الحديث (سريع وتلاوة معاصرة)
      'مشاري العفاسي': 'Alafasy_128kbps',
      'ماهر المعيقلي': 'MaherAlMuaiqly128kbps',
      'ياسر الدوسري': 'Yasser_Ad-Dussary_128kbps',
      'أحمد العجمي': 'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net',
      'سعد الغامدي': 'Ghamadi_40kbps',
      'ناصر القطامي': 'Nasser_Alqatami_128kbps',
      'فارس عباد': 'Fares_Abbad_64kbps',
      'أبو بكر الشاطري': 'Abu_Bakr_Ash-Shaatree_128kbps',
      'عبد الرحمن السديس': 'Abdurrahmaan_As-Sudais_192kbps',
      'سعود الشريم': 'Saood_ash-Shuraym_128kbps',
      'عبدالله عواد الجهني': 'Abdullaah_3awwaad_Al-Juhaynee_128kbps',
      'خالد القحطاني': 'Khaalid_Abdullaah_al-Qahtaanee_192kbps',
      'هاني الرفاعي': 'Hani_Rifai_192kbps',

      // 3. قراء الحرمين الكلاسيكيين والتلاوات الهادئة المتأنية
      'علي الحذيفي': 'Hudhaify_128kbps',
      'علي جابر': 'Ali_Jaber_64kbps',
      'محمد أيوب': 'Muhammad_Ayyoub_128kbps',
      'إبراهيم الأخضر': 'Ibrahim_Akhdar_32kbps',
      'عبدالله المطرود': 'Abdullah_Matroud_128kbps',
      'محمد جبريل': 'Muhammad_Jibreel_128kbps',
      'عبد الله بصفر': 'Abdullah_Basfar_192kbps',

      // 4. قراء آخرون (تلاوات متنوعة)
      'صلاح بو خاطر': 'Salaah_AbdulRahman_Bukhatir_128kbps',
      'صلاح البدير': 'Salah_Al_Budair_128kbps',
      'نبيل الرفاعي': 'Nabil_Rifa3i_48kbps',
      'سهل ياسين': 'Sahl_Yassin_128kbps',
      'ياسر سلامة': 'Yaser_Salamah_128kbps',
      'علي حجاج السويسي': 'Ali_Hajjaj_AlSuesy_128kbps',
      'أكرم العلاقمي': 'Akram_AlAlaqimy_128kbps',
      'محمد عبد الكريم': 'Muhammad_AbdulKareem_128kbps',
      'محسن القاسم': 'Muhsin_Al_Qasim_192kbps',
    },
    'مجود': {
      'عبد الباسط عبد الصمد': 'Abdul_Basit_Mujawwad_128kbps',
      'محمد صديق المنشاوي': 'Minshawy_Mujawwad_192kbps',
      'محمود خليل الحصري': 'Husary_128kbps_Mujawwad',
      'محمد محمود الطبلاوي': 'Mohammad_al_Tablaway_128kbps',
      'مصطفى إسماعيل': 'Mustafa_Ismail_48kbps',
    },
    'المصحف المعلم': {
      'محمود خليل الحصري': 'Husary_Muallim_128kbps',
      'محمد صديق المنشاوي': 'Minshawy_Teacher_128kbps',
      'أيمن سويد': 'Ayman_Sowaid_64kbps',
      'خليفة الطنيجي': 'khalefa_al_tunaiji_64kbps',
    },
    'رواية ورش': {
      'ياسين الجزائري': 'warsh/warsh_yassin_al_jazaery_64kbps',
      'عبد الباسط عبد الصمد': 'warsh/warsh_Abdul_Basit_128kbps',
      'إبراهيم الدوسري': 'warsh/warsh_ibrahim_aldosary_128kbps',
      'محمود خليل الحصري': 'Husary_128kbps',
    },
    'الترجمات الصوتية': {
      'إبراهيم ووك (إنجليزي)': 'English/Sahih_Intnl_Ibrahim_Walk_192kbps',
      'عبد الله بصفر وإبراهيم ووك (عربي / إنجليزي)':
          'MultiLanguage/Basfar_Walk_192kbps',
    },
  };

  /// Helper to get the flat reciter path from any category
  static String getReciterPath(String categoryName, String reciterName) {
    if (reciterCategories.containsKey(categoryName)) {
      if (reciterCategories[categoryName]!.containsKey(reciterName)) {
        return reciterCategories[categoryName]![reciterName]!;
      }
    }
    return 'Minshawy_Murattal_128kbps'; // Default fallback
  }

  /// Returns the base directory for a specific reciter
  Future<String> getReciterDirectory(String category, String reciterKey) async {
    if (kIsWeb) return ''; // Not supported on web
    final dir = await getApplicationDocumentsDirectory();
    final reciterPath = getReciterPath(category, reciterKey);
    final targetDir = Directory('${dir.path}/audio/$reciterPath');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir.path;
  }

  /// Returns the local path for a specific verse if it exists, otherwise null
  Future<String?> getLocalVersePath(
    String category,
    String reciterKey,
    int verseId,
  ) async {
    if (kIsWeb) return null;
    final dirPath = await getReciterDirectory(category, reciterKey);
    final file = File('$dirPath/$verseId.mp3');
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  /// Returns the local path for a specific verse if it exists, otherwise null
  Future<String> getVerseAudioPath(
    String category,
    String reciterKey,
    int surah,
    int ayah,
  ) async {
    final reciterPath = getReciterPath(category, reciterKey);
    final surahStr = surah.toString().padLeft(3, '0');
    final ayahStr = ayah.toString().padLeft(3, '0');

    final url = 'https://everyayah.com/data/$reciterPath/$surahStr$ayahStr.mp3';

    if (kIsWeb) return url;

    final dirPath = await getReciterDirectory(category, reciterKey);
    final verseId = surah * 1000 + ayah;
    final savePath = '$dirPath/$verseId.mp3';

    if (await File(savePath).exists()) {
      return savePath;
    }

    return url;
  }

  /// Downloads a specific verse audio file
  Future<String> downloadVerse(
    String category,
    String reciterKey,
    int surah,
    int ayah,
    Function(double)? onProgress,
  ) async {
    final reciterPath = getReciterPath(category, reciterKey);
    final surahStr = surah.toString().padLeft(3, '0');
    final ayahStr = ayah.toString().padLeft(3, '0');

    final url = 'https://everyayah.com/data/$reciterPath/$surahStr$ayahStr.mp3';

    if (kIsWeb) return url;

    final dirPath = await getReciterDirectory(category, reciterKey);
    final verseId = surah * 1000 + ayah;
    final savePath = '$dirPath/$verseId.mp3';
    final tempPath = '$savePath.temp';

    // If it already exists and is not a temp file, return
    if (await File(savePath).exists()) {
      return savePath;
    }

    // Check if we are already downloading this verse
    if (_activePrefetches.containsKey(verseId)) {
      return await _activePrefetches[verseId]!;
    }

    // Register active download
    final completer = Completer<String>();
    _activePrefetches[verseId] = completer.future;

    try {
      await _dio.download(
        url,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      // Rename temp file to actual file atomically
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.rename(savePath);
      }

      _activePrefetches.remove(verseId);
      completer.complete(savePath);
      return savePath;
    } catch (e) {
      // Clean up partial temp file if download failed
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      _activePrefetches.remove(verseId);
      completer.completeError(e);
      throw Exception(
        'Failed to download audio for Surah $surah Ayah $ayah: $e',
      );
    }
  }

  /// Checks if an entire Surah is already downloaded locally
  Future<bool> isSurahDownloaded(
    String category,
    String reciterKey,
    int surah,
    int numAyahs,
  ) async {
    if (kIsWeb) return false;
    final dirPath = await getReciterDirectory(category, reciterKey);
    for (int ayah = 1; ayah <= numAyahs; ayah++) {
      final verseId = surah * 1000 + ayah;
      final file = File('$dirPath/$verseId.mp3');
      if (!await file.exists()) {
        return false;
      }
    }
    return true;
  }

  /// Deletes all downloaded audio for a specific surah
  Future<void> deleteSurah(
    String category,
    String reciterKey,
    int surah,
    int numAyahs,
  ) async {
    if (kIsWeb) return;
    final dirPath = await getReciterDirectory(category, reciterKey);
    for (int ayah = 1; ayah <= numAyahs; ayah++) {
      final verseId = surah * 1000 + ayah;
      final file = File('$dirPath/$verseId.mp3');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Returns download progress for a surah (0.0 to 1.0).
  /// Counts how many ayahs are already on disk vs total.
  Future<double> getSurahDownloadProgress(
    String category,
    String reciterKey,
    int surah,
    int numAyahs,
  ) async {
    if (kIsWeb || numAyahs == 0) return 0.0;
    final dirPath = await getReciterDirectory(category, reciterKey);
    int count = 0;
    for (int ayah = 1; ayah <= numAyahs; ayah++) {
      final verseId = surah * 1000 + ayah;
      if (await File('$dirPath/$verseId.mp3').exists()) count++;
    }
    return count / numAyahs;
  }

  /// Downloads an entire Surah by downloading all its ayahs sequentially
  Future<void> downloadSurah(
    String category,
    String reciterKey,
    int surah,
    int numAyahs, {
    Function(double)? onProgress,
  }) async {
    int downloadedCount = 0;

    // Check what's already downloaded to initialize progress properly
    final dirPath = await getReciterDirectory(category, reciterKey);
    for (int ayah = 1; ayah <= numAyahs; ayah++) {
      final verseId = surah * 1000 + ayah;
      if (await File('$dirPath/$verseId.mp3').exists()) {
        downloadedCount++;
      }
    }

    if (downloadedCount == numAyahs) {
      if (onProgress != null) onProgress(1.0);
      return;
    }

    // Download missing ayahs
    for (int ayah = 1; ayah <= numAyahs; ayah++) {
      final verseId = surah * 1000 + ayah;
      if (!await File('$dirPath/$verseId.mp3').exists()) {
        await downloadVerse(category, reciterKey, surah, ayah, null);
        downloadedCount++;
        if (onProgress != null) {
          onProgress(downloadedCount / numAyahs);
        }
      }
    }
  }

  /// Constructs the streaming URL for a verse
  String getStreamingUrl(
    String category,
    String reciterKey,
    int surah,
    int ayah,
  ) {
    final reciterPath = getReciterPath(category, reciterKey);
    final surahStr = surah.toString().padLeft(3, '0');
    final ayahStr = ayah.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$reciterPath/$surahStr$ayahStr.mp3';
  }

  /// Predictive Prefetching Queue Engine (Anti-Stuttering)
  /// Instantly fires background downloads for N+1, N+2...
  Future<void> prefetchVerses(
    String category,
    String reciterKey,
    int currentSurah,
    int currentAyah, {
    int lookaheadCount = 3,
  }) async {
    int surah = currentSurah;
    int ayah = currentAyah;

    for (int i = 0; i < lookaheadCount; i++) {
      ayah++;

      // Use QuranMetadata for accurate bound checking
      final maxAyah = QuranMetadata.surahLengthOf(surah);
      if (ayah > maxAyah) {
        surah++;
        ayah = 1;
      }
      if (surah > 114) break;

      final verseId = surah * 1000 + ayah;

      // If we are already prefetching this verse, skip
      if (_activePrefetches.containsKey(verseId)) continue;

      // Check if file already exists locally
      final localPath = await getLocalVersePath(category, reciterKey, verseId);
      if (localPath != null) continue;

      // Launch background download task and catch errors silently since it's just prefetching
      final downloadTask =
          downloadVerse(
            category,
            reciterKey,
            surah,
            ayah,
            null,
          ).catchError((_) => '').whenComplete(() {
            _activePrefetches.remove(verseId);
          });

      _activePrefetches[verseId] = downloadTask;
    }
  }
}
