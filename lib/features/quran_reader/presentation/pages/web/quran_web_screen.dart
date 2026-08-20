import '../../widgets/drawer/web/quran_drawer_web.dart';
import '../../widgets/hifz/hifz_toolbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../widgets/web/quran_page_widget_web.dart';
import '../../widgets/page_navigation/quran_page_navigator.dart';
import '../../../bloc/audio/audio_bloc.dart';
import '../../../bloc/audio/audio_state.dart';
import '../../widgets/web/media_control_bar_web.dart';
import '../../../../../core/services/audio_preferences_service.dart';
import '../../../domain/repositories/quran_repository.dart';
import '../../../data/models/search_verse_model.dart';
import '../../../../../core/utils/verse_ref.dart';
import '../../../../../core/constants/quran_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../settings/bloc/settings_bloc.dart';
import '../../../../../core/utils/app_snack_bar.dart';

class QuranWebScreen extends StatefulWidget {
  final int? initialPage;
  final String? initialVerseKey;

  const QuranWebScreen({super.key, this.initialPage, this.initialVerseKey});

  @override
  State<QuranWebScreen> createState() => _QuranWebScreenState();
}

class _QuranWebScreenState extends State<QuranWebScreen> {
  final GlobalKey<QuranPageNavigatorState> _navigatorKey =
      GlobalKey<QuranPageNavigatorState>();

  int _currentPage = 1;
  int _pageChangeToken = 0;
  String? _highlightVerseKey;
  bool _isAudioExpanded = true;

  @override
  void initState() {
    super.initState();
    _currentPage =
        widget.initialPage ??
        context.read<AudioPreferencesService>().lastReadPage;
    _highlightVerseKey = widget.initialVerseKey;

    context.read<QuranRepository>().getLinesByPage(_currentPage);
  }

  void _onPageChanged(int newPage) {
    if (_currentPage == newPage) return;
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
    _highlightVerseKey = verseKey;

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

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: QuranDrawerWeb(
        currentPage: _currentPage,
        onNavigateToPage: (page, {String? verseKey}) =>
            _navigateToPage(page, verseKey: verseKey),
      ),
      body: SafeArea(
        child: BlocListener<AudioBloc, AudioState>(
          listener: _handleAudioStateChange,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTwoPageMode = constraints.maxWidth >= 1000;
              final contentWidth = isTwoPageMode
                  ? (constraints.maxWidth * 0.95).clamp(800.0, 1400.0)
                  : (constraints.maxWidth * 0.85).clamp(320.0, 900.0);
              final pageStep = isTwoPageMode ? 2 : 1;

              return Center(
                child: SizedBox(
                  width: contentWidth,
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
                              ? (_isAudioExpanded ? 170 : 80)
                              : 0;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.only(bottom: paddingBottom),
                            child: Listener(
                              onPointerSignal: (pointerSignal) {
                                if (pointerSignal is PointerScrollEvent) {
                                  if (pointerSignal.scrollDelta.dy > 0) {
                                    _navigateToPage(_currentPage + pageStep);
                                  } else if (pointerSignal.scrollDelta.dy < 0) {
                                    _navigateToPage(_currentPage - pageStep);
                                  }
                                }
                              },
                              child: QuranPageNavigator(
                                key: _navigatorKey,
                                currentPage: _currentPage,
                                pageStep: pageStep,
                                scrollDirection: settingsState.scrollDirection,
                                onInteractionStart: () {
                                  QuranPageWidgetWeb.dismissActiveMenu();
                                },
                                onPageChanged: _onPageChanged,
                                pageBuilder: (context, page) {
                                  if (isTwoPageMode) {
                                    final rightPage = (page % 2 == 1)
                                        ? page
                                        : page - 1;
                                    final leftPage = rightPage + 1;

                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Center(
                                            child: AspectRatio(
                                              aspectRatio: 650 / 950,
                                              child: RepaintBoundary(
                                                child: QuranPageWidgetWeb(
                                                  key: ValueKey(
                                                    'page_$rightPage',
                                                  ),
                                                  pageNumber: rightPage,
                                                  onNavigateToPage:
                                                      (p, {verseKey}) =>
                                                          _navigateToPage(
                                                            p,
                                                            verseKey: verseKey,
                                                          ),
                                                  highlightVerseKey:
                                                      (rightPage ==
                                                              _currentPage ||
                                                          leftPage ==
                                                              _currentPage)
                                                      ? _highlightVerseKey
                                                      : null,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (leftPage <=
                                            QuranConstants.totalPages)
                                          Container(
                                            width: 2,
                                            margin: const EdgeInsets.symmetric(
                                              vertical: 40,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.transparent,
                                                  AppColors.accentGold
                                                      .withValues(alpha: 0.3),
                                                  Colors.transparent,
                                                ],
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                              ),
                                            ),
                                          ),
                                        if (leftPage <=
                                            QuranConstants.totalPages)
                                          Expanded(
                                            child: Center(
                                              child: AspectRatio(
                                                aspectRatio: 650 / 950,
                                                child: RepaintBoundary(
                                                  child: QuranPageWidgetWeb(
                                                    key: ValueKey(
                                                      'page_$leftPage',
                                                    ),
                                                    pageNumber: leftPage,
                                                    onNavigateToPage:
                                                        (p, {verseKey}) =>
                                                            _navigateToPage(
                                                              p,
                                                              verseKey:
                                                                  verseKey,
                                                            ),
                                                    highlightVerseKey:
                                                        (rightPage ==
                                                                _currentPage ||
                                                            leftPage ==
                                                                _currentPage)
                                                        ? _highlightVerseKey
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          const Expanded(child: SizedBox()),
                                      ],
                                    );
                                  } else {
                                    return Align(
                                      alignment: Alignment.center,
                                      child: AspectRatio(
                                        aspectRatio: 650 / 1000,
                                        child: RepaintBoundary(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.2),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 0),
                                                ),
                                              ],
                                            ),
                                            child: QuranPageWidgetWeb(
                                              key: ValueKey('page_$page'),
                                              pageNumber: page,
                                              onNavigateToPage:
                                                  (p, {verseKey}) =>
                                                      _navigateToPage(
                                                        p,
                                                        verseKey: verseKey,
                                                      ),
                                              highlightVerseKey:
                                                  page == _currentPage
                                                  ? _highlightVerseKey
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      const HifzToolbarWidget(),
                      BlocBuilder<AudioBloc, AudioState>(
                        builder: (context, state) {
                          final isVisible =
                              state is! AudioIdle && state is! AudioError;
                          return AnimatedPositioned(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            bottom: isVisible ? 16 : -200,
                            left: 16,
                            right: 16,
                            child: MediaControlBarWeb(
                              isExpanded: _isAudioExpanded,
                              onToggleExpanded: () {
                                setState(
                                  () => _isAudioExpanded = !_isAudioExpanded,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
