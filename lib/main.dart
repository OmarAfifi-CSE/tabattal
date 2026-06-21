import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/quran_reader/presentation/pages/quran_page_view_screen.dart';
import 'features/quran_reader/presentation/bloc/audio/audio_bloc.dart';
import 'features/quran_reader/presentation/bloc/bookmark/bookmark_bloc.dart';
import 'features/quran_reader/presentation/bloc/bookmark/bookmark_event.dart';
import 'features/quran_reader/data/datasources/quran_local_data_source.dart';
import 'features/quran_reader/domain/repositories/quran_repository.dart';
import 'core/database/database_helper.dart';
import 'core/theme/app_colors.dart';
import 'core/network/audio_download_manager.dart';

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
  
  
  // Dependency Injection (simple manual setup for now)
  final databaseHelper = DatabaseHelper();
  // Initialize the database asynchronously before starting the app to ensure it's copied
  await databaseHelper.database;
  
  final quranLocalDataSource = QuranLocalDataSourceImpl(databaseHelper: databaseHelper);
  final quranRepository = QuranRepositoryImpl(localDataSource: quranLocalDataSource);

  runApp(TabattalApp(quranRepository: quranRepository));
}

class TabattalApp extends StatelessWidget {
  final QuranRepository quranRepository;

  const TabattalApp({super.key, required this.quranRepository});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<QuranRepository>.value(
          value: quranRepository,
        ),
        RepositoryProvider<AudioDownloadManager>(
          create: (context) => AudioDownloadManager(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AudioBloc>(
            create: (context) => AudioBloc(
              context.read<AudioDownloadManager>(),
            ),
          ),
          BlocProvider<BookmarkBloc>(
            create: (_) => BookmarkBloc()..add(LoadBookmarks()),
          ),
        ],
        child: MaterialApp(
          title: 'Tabattal',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.accentGold,
              surface: AppColors.background,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.background,
          ),
          home: const QuranPageViewScreen(),
        ),
      ),
    );
  }
}
