import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

import 'features/quran_reader/presentation/screens/mobile/quran_mobile_screen.dart';
import 'features/quran_reader/presentation/screens/tablet/quran_tablet_screen.dart';
import 'features/quran_reader/presentation/screens/desktop/quran_desktop_screen.dart';
import 'features/quran_reader/presentation/screens/web/quran_web_screen.dart';
import 'core/utils/responsive_layout.dart';
import 'features/quran_audio/presentation/bloc/audio_bloc.dart';
import 'features/quran_bookmarks/presentation/bloc/bookmark_bloc.dart';
import 'features/quran_bookmarks/presentation/bloc/bookmark_event.dart';
import 'features/quran_reader/domain/repositories/quran_repository.dart';
import 'features/quran_reader/data/datasources/quran_local_data_source.dart';

import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/network/audio_download_manager.dart';
import 'core/services/audio_preferences_service.dart';
import 'core/bloc/locale/locale_cubit.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/settings/presentation/bloc/settings_state.dart';
import 'features/quran_hifz/presentation/bloc/hifz_bloc.dart';

import 'features/quran_reader/presentation/bloc/quran_bloc.dart';

// ---------------------------------------------------------------------------
// Main entrypoint
// ---------------------------------------------------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final logicalShortestSide =
      view.physicalSize.shortestSide / view.devicePixelRatio;
  if (logicalShortestSide < 600) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

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
        RepositoryProvider<QuranRepository>.value(
          value: container.quranRepository,
        ),
        RepositoryProvider<QuranLocalDataSource>.value(
          value: container.localDataSource,
        ),
        RepositoryProvider<AudioPreferencesService>.value(
          value: container.audioPrefs,
        ),
        RepositoryProvider(create: (_) => AudioDownloadManager()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<QuranBloc>(
            create: (_) => QuranBloc(repository: container.quranRepository),
          ),
          BlocProvider<AudioBloc>(
            create: (context) => AudioBloc(
              container.audioHandler,
              context.read<AudioDownloadManager>(),
              context.read<AudioPreferencesService>(),
            ),
          ),
          BlocProvider<BookmarkBloc>(
            create: (_) =>
                BookmarkBloc(repository: container.bookmarkRepository)
                  ..add(LoadBookmarks()),
          ),
          BlocProvider<LocaleCubit>(
            create: (_) => LocaleCubit(container.audioPrefs),
          ),
          BlocProvider<SettingsBloc>(
            create: (_) => SettingsBloc(prefs: container.sharedPreferences),
          ),
          BlocProvider<HifzBloc>(create: (_) => HifzBloc()),
        ],
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            // Update static AppColors immediately so appTheme() uses the correct seed color
            AppColors.isDarkMode = settingsState.themeMode == ThemeMode.dark;
            AppColors.currentMushafTheme = settingsState.effectiveMushafTheme;

            return BlocBuilder<LocaleCubit, Locale>(
              builder: (context, locale) {
                return ResponsiveLayout(
                  // Web: adapts designSize dynamically based on viewport orientation
                  webBody: LayoutBuilder(
                    builder: (context, constraints) {
                      final isLandscape =
                          constraints.maxWidth > constraints.maxHeight;
                      final isTwoPage =
                          isLandscape && constraints.maxWidth >= 1000;
                      final isMobile =
                          !isLandscape && constraints.maxWidth < 600;
                      final Size effectiveDesignSize = isMobile
                          ? const Size(412, 917)
                          : isTwoPage
                              ? const Size(1536, 864)
                              : const Size(1000, 864);
                      return ScreenUtilInit(
                        designSize: effectiveDesignSize,
                        minTextAdapt: true,
                        splitScreenMode: false,
                        child: MaterialApp(
                          title: 'Tabattal - تبتل',
                          debugShowCheckedModeBanner: false,
                          locale: locale,
                          scrollBehavior: const AppScrollBehavior(),
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
                          home: const QuranWebScreen(),
                        ),
                      );
                    },
                  ),
                  desktopBody: LayoutBuilder(
                    builder: (context, constraints) {
                      final isLandscape =
                          constraints.maxWidth > constraints.maxHeight;
                      final isTwoPage =
                          isLandscape && constraints.maxWidth >= 1000;
                      return ScreenUtilInit(
                        designSize: isTwoPage
                            ? const Size(1536, 864)
                            : const Size(1000, 864),
                        minTextAdapt: true,
                        splitScreenMode: false,
                        child: MaterialApp(
                          title: 'Tabattal - تبتل',
                          debugShowCheckedModeBanner: false,
                          locale: locale,
                          scrollBehavior: const AppScrollBehavior(),
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
                          home: const QuranDesktopScreen(),
                        ),
                      );
                    },
                  ),
                  tabletBody: LayoutBuilder(
                    builder: (context, constraints) {
                      final isLandscape =
                          constraints.maxWidth > constraints.maxHeight;
                      return ScreenUtilInit(
                        designSize: isLandscape
                            ? const Size(1280, 800)
                            : const Size(800, 1280),
                        minTextAdapt: true,
                        splitScreenMode: false,
                        child: MaterialApp(
                          title: 'Tabattal - تبتل',
                          debugShowCheckedModeBanner: false,
                          locale: locale,
                          scrollBehavior: const AppScrollBehavior(),
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
                          home: const QuranTabletScreen(),
                        ),
                      );
                    },
                  ),
                  // Mobile: calibrated against OnePlus 13R (412×917 dp).
                  mobileBody: ScreenUtilInit(
                    designSize: const Size(412, 917),
                    minTextAdapt: true,
                    splitScreenMode: true,
                    child: MaterialApp(
                      title: 'Tabattal - تبتل',
                      debugShowCheckedModeBanner: false,
                      locale: locale,
                      scrollBehavior: const AppScrollBehavior(),
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
                      home: const QuranMobileScreen(),
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
