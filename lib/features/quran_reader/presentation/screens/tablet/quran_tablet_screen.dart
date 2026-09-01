import '../../widgets/drawer/tablet/quran_drawer_tablet.dart';
import '../../../../quran_hifz/presentation/widgets/tablet/hifz_toolbar_widget_tablet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../widgets/tablet/quran_page_widget_tablet.dart';
import '../../widgets/page_navigation/quran_page_navigator.dart';
import '../../../../quran_audio/presentation/bloc/audio_bloc.dart';
import '../../../../quran_audio/presentation/bloc/audio_state.dart';
import '../../bloc/quran_page_cache.dart';
import '../../../../quran_audio/presentation/widgets/tablet/media_control_bar_tablet.dart';
import '../../../../../core/services/audio_preferences_service.dart';
import '../../../domain/repositories/quran_repository.dart';
import '../../../../quran_search/data/models/search_verse_model.dart';
import '../../../../../core/utils/verse_ref.dart';
import '../../../../../core/constants/quran_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../../../core/utils/app_snack_bar.dart';

class QuranTabletScreen extends StatefulWidget {
  final int? initialPage;
  final String? initialVerseKey;

  const QuranTabletScreen({super.key, this.initialPage, this.initialVerseKey});

  @override
  State<QuranTabletScreen> createState() => _QuranTabletScreenState();
}

class _QuranTabletScreenState extends State<QuranTabletScreen> {
  final GlobalKey<QuranPageNavigatorState> _navigatorKey =
      GlobalKey<QuranPageNavigatorState>();

  int _currentPage = 1;
  int _pageChangeToken = 0;
  String? _highlightVerseKey;
  int? _highlightTargetPage;
  int _highlightToken = 0;
  bool _isAudioExpanded = true;

  DateTime _lastPageTurnTime = DateTime.fromMillisecondsSinceEpoch(0);
  double _wheelAccumulator = 0.0;

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

    _prewarmAdjacentPages(_currentPage);
  }

  void _prewarmAdjacentPages(int page) {
    final repo = context.read<QuranRepository>();
    // 1. Immediately request the active primary page
    if (QuranPageCache.get(page) == null) {
      repo.getLinesByPage(page);
    }

    // 2. Defer neighbor prewarming to post-frame to keep frame 1 completely unblocked
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (int offset = -4; offset <= 5; offset++) {
        if (offset == 0) continue;
        final p = page + offset;
        if (p >= 1 && p <= QuranConstants.totalPages) {
          if (QuranPageCache.get(p) == null) {
            repo.getLinesByPage(p);
          }
        }
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
    final repo = context.read<QuranRepository>();
    final result = await repo.getLinesByPage(newPage);
    if (!mounted || token != _pageChangeToken) return;
    result.fold((_) {}, (_) {
      if (!mounted || token != _pageChangeToken) return;
      setState(() => _currentPage = newPage);
      context.read<AudioPreferencesService>().saveLastReadPage(newPage);

      _prewarmAdjacentPages(newPage);
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

  void _handlePointerScroll(PointerSignalEvent event, int pageStep) {
    if (event is! PointerScrollEvent) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastPageTurnTime).inMilliseconds;
    if (elapsed < 220) {
      _wheelAccumulator = 0.0;
      return;
    }

    final dy = event.scrollDelta.dy;
    final dx = event.scrollDelta.dx;
    final delta = dy.abs() > dx.abs() ? dy : dx;
    if (delta == 0) return;

    _wheelAccumulator += delta;

    if (_wheelAccumulator.abs() >= 12.0) {
      final isNext = _wheelAccumulator > 0;
      _wheelAccumulator = 0.0;
      _lastPageTurnTime = now;

      final targetPage = isNext
          ? (_currentPage + pageStep).clamp(1, QuranConstants.totalPages)
          : (_currentPage - pageStep).clamp(1, QuranConstants.totalPages);

      if (targetPage != _currentPage) {
        _navigateToPage(targetPage);
      }
    }
  }

  void _handleAudioStateChange(BuildContext context, AudioState state) {
    if (state is AudioError) {
      _showErrorSnackBar(state.message);
    } else if (state is AudioPlaying) {
      _navigateToPlayingVerse(context, state.currentVerseId);
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
        drawer: QuranDrawerTablet(
          currentPage: _currentPage,
          onNavigateToPage: (page, {String? verseKey}) =>
              _navigateToPage(page, verseKey: verseKey),
        ),
        body: SafeArea(
          child: BlocListener<AudioBloc, AudioState>(
            listener: _handleAudioStateChange,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape = constraints.maxWidth > constraints.maxHeight;
                final isTwoPageMode = isLandscape || constraints.maxWidth >= 900;
                final pageStep = isTwoPageMode ? 2 : 1;

                return Stack(
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
                            ? (isLandscape
                                ? 0.0
                                : (_isAudioExpanded ? 80.h : 30.h))
                            : 0;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.only(bottom: paddingBottom),
                          child: Focus(
                            autofocus: true,
                            onKeyEvent: (node, event) {
                              if (event is! KeyDownEvent) return KeyEventResult.ignored;
                              if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                                  event.logicalKey == LogicalKeyboardKey.pageDown ||
                                  event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                _navigateToPage(_currentPage + pageStep);
                                return KeyEventResult.handled;
                              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                                  event.logicalKey == LogicalKeyboardKey.pageUp ||
                                  event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                _navigateToPage(_currentPage - pageStep);
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: Listener(
                              behavior: HitTestBehavior.translucent,
                              onPointerSignal: (pointerSignal) =>
                                  _handlePointerScroll(pointerSignal, pageStep),
                              child: QuranPageNavigator(
                                key: _navigatorKey,
                                currentPage: _currentPage,
                                pageStep: pageStep,
                                scrollDirection: settingsState.scrollDirection,
                                onInteractionStart: () {
                                  QuranPageWidgetTablet.dismissActiveMenu();
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
                                            child: FittedBox(
                                              fit: BoxFit.contain,
                                              child: SizedBox(
                                                width: 800,
                                                height: 1280,
                                                child: RepaintBoundary(
                                                  child: QuranPageWidgetTablet(
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
                                                    highlightToken:
                                                        (rightPage ==
                                                                _currentPage ||
                                                            leftPage ==
                                                                _currentPage)
                                                        ? _highlightToken
                                                        : 0,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (leftPage <=
                                            QuranConstants.totalPages)
                                          Container(
                                            width: 1.5.w,
                                            margin: EdgeInsets.symmetric(
                                              vertical: (isLandscape ? 28.0 : 36.0).h,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.transparent,
                                                  settingsState
                                                      .effectiveMushafTheme
                                                      .goldColor
                                                      .withValues(alpha: 0.35),
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
                                              child: FittedBox(
                                                fit: BoxFit.contain,
                                                child: SizedBox(
                                                  width: 800,
                                                  height: 1280,
                                                  child: RepaintBoundary(
                                                    child: QuranPageWidgetTablet(
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
                                                      highlightToken:
                                                          (rightPage ==
                                                                  _currentPage ||
                                                              leftPage ==
                                                                  _currentPage)
                                                          ? _highlightToken
                                                          : 0,
                                                    ),
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
                                    return Center(
                                      child: FittedBox(
                                        fit: BoxFit.contain,
                                        child: SizedBox(
                                          width: 800,
                                          height: 1280,
                                          child: QuranPageWidgetTablet(
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
                                            highlightToken:
                                                page == _currentPage
                                                ? _highlightToken
                                                : 0,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const HifzToolbarWidgetTablet(),
                    
                    BlocBuilder<AudioBloc, AudioState>(
                      builder: (context, state) {
                        final isVisible =
                            state is! AudioIdle && state is! AudioError;
                        return AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          bottom: isVisible
                              ? (isLandscape ? 12.0.h : 16.h)
                              : -150.0.h,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: (isLandscape ? 16.0 : 16.0).w,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: isLandscape
                                      ? 600.0.w
                                      : (constraints.maxWidth - 32.w),
                                ),
                                child: MediaControlBarTablet(
                                  isExpanded: _isAudioExpanded,
                                  onToggleExpanded: () {
                                    setState(
                                      () => _isAudioExpanded =
                                          !_isAudioExpanded,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
