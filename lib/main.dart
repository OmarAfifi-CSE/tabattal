import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/quran_reader/presentation/pages/quran_page_view_screen.dart';
import 'features/quran_reader/presentation/bloc/audio/audio_bloc.dart';
import 'features/quran_reader/presentation/bloc/bookmark/bookmark_bloc.dart';
import 'features/quran_reader/presentation/bloc/bookmark/bookmark_event.dart';
import 'features/quran_reader/data/datasources/quran_local_data_source.dart';
import 'features/quran_reader/data/datasources/quran_remote_data_source.dart';
import 'features/quran_reader/domain/repositories/quran_repository.dart';
import 'package:dio/dio.dart';
import 'core/database/database_helper.dart';
import 'core/theme/app_colors.dart';
import 'core/network/audio_download_manager.dart';
import 'core/services/audio_preferences_service.dart';

import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, 
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  // Dependency Injection
  final databaseHelper = DatabaseHelper();
  await databaseHelper.database;
  
  final quranLocalDataSource = QuranLocalDataSourceImpl(databaseHelper: databaseHelper);
  final quranRemoteDataSource = QuranRemoteDataSourceImpl(dio: Dio());
  final quranRepository = QuranRepositoryImpl(
    localDataSource: quranLocalDataSource,
    remoteDataSource: quranRemoteDataSource,
  );
  final audioPrefs = await AudioPreferencesService.create();

  runApp(TabattalApp(
    quranRepository: quranRepository,
    localDataSource: quranLocalDataSource,
    audioPrefs: audioPrefs,
  ));
}

class TabattalApp extends StatelessWidget {
  final QuranRepository quranRepository;
  final QuranLocalDataSource localDataSource;
  final AudioPreferencesService audioPrefs;

  const TabattalApp({
    super.key,
    required this.quranRepository,
    required this.localDataSource,
    required this.audioPrefs,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<QuranRepository>.value(value: quranRepository),
        RepositoryProvider<QuranLocalDataSource>.value(value: localDataSource),
        RepositoryProvider<AudioPreferencesService>.value(value: audioPrefs),
        RepositoryProvider<AudioDownloadManager>(
          create: (context) => AudioDownloadManager(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AudioBloc>(
            create: (context) => AudioBloc(
              context.read<AudioDownloadManager>(),
              context.read<AudioPreferencesService>(),
            ),
          ),
          BlocProvider<BookmarkBloc>(
            create: (_) => BookmarkBloc()..add(LoadBookmarks()),
          ),
        ],
        child: MaterialApp(
          title: 'تبتل',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.accentGold,
              surface: AppColors.background,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.background,
          ),
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
          home: const QuranPageViewScreen(),
        ),
      ),
    );
  }
}
