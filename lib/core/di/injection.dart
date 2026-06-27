import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../network/api_client.dart';
import '../network/tafsir_download_service.dart';
import '../services/audio_preferences_service.dart';
import '../../features/quran_reader/data/datasources/quran_local_data_source.dart';
import '../../features/quran_reader/data/datasources/quran_remote_data_source.dart';
import '../../features/quran_reader/domain/repositories/quran_repository.dart';
import '../../features/quran_reader/domain/repositories/bookmark_repository.dart';

import '../services/quran_audio_handler.dart';
import 'package:audio_service/audio_service.dart';

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
  });
}

Future<DependencyContainer> configureDependencies() async {
  final databaseHelper = DatabaseHelper();
  await databaseHelper.database;
  
  final apiClient = ApiClient(dio: Dio());
  final localDataSource = QuranLocalDataSourceImpl(databaseHelper: databaseHelper);
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

  final prefs = await SharedPreferences.getInstance();
  final bookmarkRepository = BookmarkRepositoryImpl(prefs);
  
  final audioPrefs = await AudioPreferencesService.create();

  final audioHandler = await AudioService.init<QuranAudioHandler>(
    builder: () => QuranAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.tabattal.channel.audio',
      androidNotificationChannelName: 'تلاوات القرآن',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

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
  );
}
