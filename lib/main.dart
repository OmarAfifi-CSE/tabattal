import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

import 'features/quran_reader/presentation/pages/quran_page_view_screen.dart';
import 'features/quran_reader/presentation/pages/quran_web_view_screen.dart';
import 'core/utils/responsive_layout.dart';
import 'features/quran_reader/presentation/bloc/audio/audio_bloc.dart';
import 'features/quran_reader/presentation/bloc/bookmark/bookmark_bloc.dart';
import 'features/quran_reader/presentation/bloc/bookmark/bookmark_event.dart';
import 'features/quran_reader/domain/repositories/quran_repository.dart';
import 'features/quran_reader/data/datasources/quran_local_data_source.dart';

import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'core/network/audio_download_manager.dart';
import 'core/services/audio_preferences_service.dart';
import 'core/bloc/locale/locale_cubit.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/settings/presentation/bloc/settings_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  final container = await configureDependencies();

  runApp(TabattalApp(container: container));
}

class TabattalApp extends StatelessWidget {
  final DependencyContainer container;

  const TabattalApp({super.key, required this.container});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<QuranRepository>.value(value: container.quranRepository),
        RepositoryProvider<QuranLocalDataSource>.value(value: container.localDataSource),
        RepositoryProvider<AudioPreferencesService>.value(value: container.audioPrefs),
        RepositoryProvider(create: (_) => AudioDownloadManager()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AudioBloc>(
            create: (context) => AudioBloc(
              container.audioHandler,
              context.read<AudioDownloadManager>(),
              context.read<AudioPreferencesService>(),
            ),
          ),
          BlocProvider<BookmarkBloc>(
            create: (_) => BookmarkBloc(repository: container.bookmarkRepository)..add(LoadBookmarks()),
          ),
          BlocProvider<LocaleCubit>(
            create: (_) => LocaleCubit(container.audioPrefs),
          ),
          BlocProvider<SettingsBloc>(
            create: (_) => SettingsBloc(prefs: container.sharedPreferences),
          ),
        ],
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            return BlocBuilder<LocaleCubit, Locale>(
              builder: (context, locale) {
            return ResponsiveLayout(
              // Web: calibrated to 800×900 so .sp/.w/.h render at reasonable scale
              // for a typical browser viewport (900–1400px wide).
              webBody: ScreenUtilInit(
                designSize: const Size(800, 900),
                minTextAdapt: true,
                splitScreenMode: false,
                child: MaterialApp(
                  onGenerateTitle: (ctx) => AppLocalizations.of(ctx)?.appName ?? 'Tabattal',
                  debugShowCheckedModeBanner: false,
                  locale: locale,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  theme: appTheme(),
                  darkTheme: appThemeDark(),
                  themeMode: settingsState.themeMode,
                  builder: appDirectionalityBuilder,
                  home: const QuranWebPageViewScreen(),
                ),
              ),
              // Mobile: calibrated against OnePlus 13R (412×917 dp).
              mobileBody: ScreenUtilInit(
                designSize: const Size(412, 917),
                minTextAdapt: true,
                splitScreenMode: true,
                child: MaterialApp(
                  onGenerateTitle: (ctx) => AppLocalizations.of(ctx)?.appName ?? 'Tabattal',
                  debugShowCheckedModeBanner: false,
                  locale: locale,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  theme: appTheme(),
                  darkTheme: appThemeDark(),
                  themeMode: settingsState.themeMode,
                  builder: appDirectionalityBuilder,
                  home: const QuranPageViewScreen(),
                ),
              ),
            );
          },
        );
      },
    ),
      ),
    );
  }
}
