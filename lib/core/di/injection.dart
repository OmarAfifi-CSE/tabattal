import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../database/database_helper.dart';
import '../network/api_client.dart';
import '../network/tafsir_download_service.dart';
import '../services/audio_preferences_service.dart';
import '../../features/quran_reader/data/datasources/quran_local_data_source.dart';
import '../../features/quran_reader/data/datasources/quran_remote_data_source.dart';
import '../../features/quran_reader/domain/repositories/quran_repository.dart';
import '../../features/quran_bookmarks/domain/repositories/bookmark_repository.dart';

import '../services/quran_audio_handler.dart';

class DependencyContainer {
  final DatabaseHelper databaseHelper;
  final ApiClient apiClient;
  final QuranLocalDataSource localDataSource;
  final QuranRemoteDataSource remoteDataSource;
  final TafsirDownloadService tafsirDownloadService;
  final QuranRepository quranRepository;
  final BookmarkRepository bookmarkRepository;
  final AudioPreferencesService audioPrefs;
  final QuranAudioHandler audioHandler;
  final SharedPreferences sharedPreferences;

  const DependencyContainer({
    required this.databaseHelper,
    required this.apiClient,
    required this.localDataSource,
    required this.remoteDataSource,
    required this.tafsirDownloadService,
    required this.quranRepository,
    required this.bookmarkRepository,
    required this.audioPrefs,
    required this.audioHandler,
    required this.sharedPreferences,
  });
}

Future<DependencyContainer> configureDependencies() async {
  final databaseHelper = DatabaseHelper();
  final isEnLocale = PlatformDispatcher.instance.locale.languageCode == 'en';

  // 🚀 Overlapped Concurrent Bootstrapping (Cuts cold start latency significantly)
  final results = await Future.wait([
    databaseHelper.database,
    SharedPreferences.getInstance(),
    AudioPreferencesService.create(),
    AudioService.init<QuranAudioHandler>(
      builder: () => QuranAudioHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.tabattal.channel.audio',
        androidNotificationChannelName: isEnLocale
            ? 'Quran Recitations'
            : 'تلاوات القرآن',
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    ),
  ]);

  final prefs = results[1] as SharedPreferences;
  final audioPrefs = results[2] as AudioPreferencesService;
  final audioHandler = results[3] as QuranAudioHandler;

  final apiClient = ApiClient(dio: Dio());
  final localDataSource = QuranLocalDataSourceImpl(
    databaseHelper: databaseHelper,
  );
  final remoteDataSource = QuranRemoteDataSourceImpl(apiClient: apiClient);

  final tafsirDownloadService = TafsirDownloadService(
    localDataSource: localDataSource,
    remoteDataSource: remoteDataSource,
  );

  final quranRepository = QuranRepositoryImpl(
    localDataSource: localDataSource,
    remoteDataSource: remoteDataSource,
    tafsirDownloadService: tafsirDownloadService,
  );

  final bookmarkRepository = BookmarkRepositoryImpl(prefs);

  return DependencyContainer(
    databaseHelper: databaseHelper,
    apiClient: apiClient,
    localDataSource: localDataSource,
    remoteDataSource: remoteDataSource,
    tafsirDownloadService: tafsirDownloadService,
    quranRepository: quranRepository,
    bookmarkRepository: bookmarkRepository,
    audioPrefs: audioPrefs,
    audioHandler: audioHandler,
    sharedPreferences: prefs,
  );
}
