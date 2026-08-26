import '../../widgets/drawer/mobile/quran_drawer_mobile.dart';
import '../../widgets/mobile/hifz_toolbar_widget_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../widgets/mobile/quran_page_widget_mobile.dart';
import '../../widgets/page_navigation/quran_page_navigator.dart';
import '../../../bloc/audio/audio_bloc.dart';
import '../../../bloc/audio/audio_state.dart';
import '../../widgets/mobile/media_control_bar_mobile.dart';
import '../../../../../core/services/audio_preferences_service.dart';
import '../../../domain/repositories/quran_repository.dart';
import '../../../data/models/search_verse_model.dart';
import '../../../../../core/utils/verse_ref.dart';
import '../../../../../core/constants/quran_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../settings/bloc/settings_bloc.dart';
import 'package:flutter/services.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../core/services/update_service.dart';
import '../../../../../core/utils/app_snack_bar.dart';

class QuranMobileScreen extends StatefulWidget {
  final int? initialPage;
  final String? initialVerseKey;

  const QuranMobileScreen({super.key, this.initialPage, this.initialVerseKey});

  @override
  State<QuranMobileScreen> createState() => _QuranMobileScreenState();
}

class _QuranMobileScreenState extends State<QuranMobileScreen> {
  final GlobalKey<QuranPageNavigatorState> _navigatorKey =
      GlobalKey<QuranPageNavigatorState>();

  int _currentPage = 1;
  int _pageChangeToken = 0;
  String? _highlightVerseKey;
  int? _highlightTargetPage;
  int _highlightToken = 0;
  bool _isAudioExpanded = true;

  @override
  void initState() {
    super.initState();
    _currentPage =
        widget.initialPage ??
        context.read<AudioPreferencesService>().lastReadPage;
    _highlightVerseKey = widget.initialVerseKey;
    _highlightTargetPage = _currentPage;
    if (_highlightVerseKey != null) {
      _highlightToken = 1;
    }

    // Trigger initial page load
    context.read<QuranRepository>().getLinesByPage(_currentPage);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UpdateService.checkForUpdates(context);
      }
    });
  }

  void _onPageChanged(int newPage) {
    if (_currentPage == newPage) return;
    if (newPage != _highlightTargetPage) {
      _highlightVerseKey = null;
      _highlightTargetPage = null;
    }
    _commitPageChange(newPage, ++_pageChangeToken);
  }

  Future<void> _commitPageChange(int newPage, int token) async {
    final result = await context.read<QuranRepository>().getLinesByPage(
      newPage,
    );
    if (!mounted || token != _pageChangeToken) return;
    result.fold((_) {}, (_) {
      if (!mounted || token != _pageChangeToken) return;
      setState(() => _currentPage = newPage);
      context.read<AudioPreferencesService>().saveLastReadPage(newPage);
    });
  }

  void _navigateToPage(int pageNumber, {String? verseKey}) {
    final targetPage = pageNumber.clamp(1, QuranConstants.totalPages);
    setState(() {
      _highlightVerseKey = verseKey;
      _highlightTargetPage = targetPage;
      if (verseKey != null) {
        _highlightToken++;
      }
    });

    if (_navigatorKey.currentState != null && targetPage != _currentPage) {
      _navigatorKey.currentState!.navigateToPage(targetPage);
    } else {
      _onPageChanged(targetPage);
    }
  }

  void _handleAudioStateChange(BuildContext context, AudioState state) {
    if (state is AudioError) {
      _showErrorSnackBar(state.message);
    } else if (state is AudioPlaying) {
      _navigateToPlayingVerse(context, state.currentVerseId);
    } else if (state is AudioIdle) {
      _isAudioExpanded = true;
    }
  }

  void _showErrorSnackBar(String messageKey) {
    String message = messageKey;
    if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      if (l10n != null) {
        switch (messageKey) {
          case 'audioErrorFileNotFound':
            message = l10n.audioErrorFileNotFound;
            break;
          case 'audioErrorNoInternet':
            message = l10n.audioErrorNoInternet;
            break;
          case 'audioErrorPlayback':
            message = l10n.audioErrorPlayback;
            break;
          case 'audioErrorPlaylist':
            message = l10n.audioErrorPlaylist;
            break;
        }
      }
    }

    AppSnackBar.showError(context, message);
  }

  void _navigateToPlayingVerse(BuildContext context, int verseId) {
    final verse = VerseRef.fromId(verseId);
    context.read<QuranRepository>().getVersesBySurah(verse.surah).then((
      result,
    ) {
      if (!mounted) return;
      result.fold(
        (failure) => debugPrint(
          '[AudioBloc] Failed to resolve verse page: ${failure.toString()}',
        ),
        (verses) {
          final int searchAyah = verse.ayah == 0 ? 1 : verse.ayah;
          final SearchVerseModel? matchingVerse = verses
              .cast<SearchVerseModel>()
              .where((v) => v.ayah == searchAyah)
              .firstOrNull;
          final targetPage = matchingVerse?.page;
          if (targetPage != null && targetPage != _currentPage) {
            _navigateToPage(targetPage, verseKey: null);
          }
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = context.watch<SettingsBloc>().state;
    final isDark = settingsState.effectiveMushafTheme.isDarkTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        drawer: QuranDrawerMobile(
          currentPage: _currentPage,
          onNavigateToPage: (page, {String? verseKey}) =>
              _navigateToPage(page, verseKey: verseKey),
        ),
        body: SafeArea(
          child: BlocListener<AudioBloc, AudioState>(
            listener: _handleAudioStateChange,
            child: Stack(
              children: [
                BlocBuilder<AudioBloc, AudioState>(
                  buildWhen: (previous, current) {
                    final prevVisible =
                        previous is! AudioIdle && previous is! AudioError;
                    final currVisible =
                        current is! AudioIdle && current is! AudioError;
                    return prevVisible != currVisible;
                  },
                  builder: (context, state) {
                    final isVisible =
                        state is! AudioIdle && state is! AudioError;
                    final double paddingBottom = isVisible
                        ? (_isAudioExpanded ? 125.h : 42.h)
                        : 0;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.only(bottom: paddingBottom),
                      child: QuranPageNavigator(
                        key: _navigatorKey,
                        currentPage: _currentPage,
                        pageStep: 1,
                        scrollDirection: settingsState.scrollDirection,
                        onInteractionStart: () {
                          QuranPageWidgetMobile.dismissActiveMenu();
                        },
                        onPageChanged: _onPageChanged,
                        pageBuilder: (context, page) {
                          return QuranPageWidgetMobile(
                            key: ValueKey('page_$page'),
                            pageNumber: page,
                            onNavigateToPage: (p, {verseKey}) =>
                                _navigateToPage(p, verseKey: verseKey),
                            highlightVerseKey: page == _currentPage
                                ? _highlightVerseKey
                                : null,
                            highlightToken: page == _currentPage
                                ? _highlightToken
                                : 0,
                          );
                        },
                      ),
                    );
                  },
                ),
                const HifzToolbarWidgetMobile(),
                BlocBuilder<AudioBloc, AudioState>(
                  builder: (context, state) {
                    final isVisible =
                        state is! AudioIdle && state is! AudioError;
                    return AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      bottom: isVisible ? 0 : -200,
                      left: 16.w,
                      right: 16.w,
                      child: MediaControlBarMobile(
                        isExpanded: _isAudioExpanded,
                        onToggleExpanded: () {
                          setState(() => _isAudioExpanded = !_isAudioExpanded);
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
