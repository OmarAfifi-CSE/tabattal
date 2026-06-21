import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'features/quran_reader/presentation/pages/quran_page_view_screen.dart';
import 'features/quran_reader/presentation/bloc/audio/audio_bloc.dart';
import 'features/quran_reader/presentation/bloc/bookmark/bookmark_bloc.dart';
import 'features/quran_reader/presentation/bloc/bookmark/bookmark_event.dart';
import 'features/quran_reader/data/datasources/quran_remote_data_source.dart';
import 'features/quran_reader/domain/repositories/quran_repository.dart';
import 'core/theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Dependency Injection (simple manual setup for now)
  final dio = Dio();
  final quranRemoteDataSource = QuranRemoteDataSourceImpl(dio: dio);
  final quranRepository = QuranRepositoryImpl(remoteDataSource: quranRemoteDataSource);

  runApp(TabattalApp(quranRepository: quranRepository));
}

class TabattalApp extends StatelessWidget {
  final QuranRepository quranRepository;

  const TabattalApp({super.key, required this.quranRepository});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: quranRepository,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AudioBloc>(
            create: (_) => AudioBloc(),
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
