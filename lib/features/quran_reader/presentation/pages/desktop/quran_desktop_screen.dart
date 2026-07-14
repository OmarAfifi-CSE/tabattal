import '../../widgets/drawer/desktop/quran_drawer_desktop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../widgets/desktop/quran_page_widget_desktop.dart';
import '../../../bloc/audio/audio_bloc.dart';
import '../../../bloc/audio/audio_state.dart';
import '../../widgets/media_control_bar.dart';
import '../../../../../core/services/audio_preferences_service.dart';
import '../../../domain/repositories/quran_repository.dart';
import '../../../data/models/search_verse_model.dart';
import '../../../../../core/utils/verse_ref.dart';
import '../../../../../core/constants/quran_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../settings/bloc/settings_bloc.dart';

class QuranDesktopScreen extends StatefulWidget {
  final int? initialPage;
  final String? initialVerseKey;

  const QuranDesktopScreen({super.key, this.initialPage, this.initialVerseKey});

  @override
  State<QuranDesktopScreen> createState() => _QuranDesktopScreenState();
}

class _QuranDesktopScreenState extends State<QuranDesktopScreen> {
  late PageController _pageControllerSingle;
  late PageController _pageControllerDouble;
  int _currentPage = 1;
  String? _highlightVerseKey;
  bool _isAudioExpanded = true;
  bool _wasTwoPageMode = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage ?? context.read<AudioPreferencesService>().lastReadPage;
    _highlightVerseKey = widget.initialVerseKey;
    _pageControllerSingle = PageController(initialPage: _currentPage - 1);
    _pageControllerDouble = PageController(initialPage: (_currentPage - 1) ~/ 2);
  }

  @override
  void dispose() {
    _pageControllerSingle.dispose();
    _pageControllerDouble.dispose();
    super.dispose();
  }

  void _jumpToPage(int pageNumber, {String? verseKey, bool animate = false}) {
    final targetPage = pageNumber.clamp(1, QuranConstants.totalPages);
    final targetIndexSingle = targetPage - 1;
    final targetIndexDouble = (targetPage - 1) ~/ 2;

    if (animate) {
      if (_pageControllerSingle.hasClients) _pageControllerSingle.animateToPage(targetIndexSingle, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      if (_pageControllerDouble.hasClients) _pageControllerDouble.animateToPage(targetIndexDouble, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      if (_pageControllerSingle.hasClients) _pageControllerSingle.jumpToPage(targetIndexSingle);
      if (_pageControllerDouble.hasClients) _pageControllerDouble.jumpToPage(targetIndexDouble);
    }
    setState(() {
      _currentPage = targetPage;
      _highlightVerseKey = verseKey;
    });
    context.read<AudioPreferencesService>().saveLastReadPage(_currentPage);
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
          case 'audioErrorPlayback':
            message = l10n.audioErrorPlayback;
            break;
          case 'audioErrorPlaylist':
            message = l10n.audioErrorPlaylist;
            break;
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        backgroundColor: AppColors.verseMarkerGold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _navigateToPlayingVerse(BuildContext context, int verseId) {
    final verse = VerseRef.fromId(verseId);
    context.read<QuranRepository>().getVersesBySurah(verse.surah).then((result) {
      result.fold(
        (failure) => debugPrint('[AudioBloc] Failed to resolve verse page: ${failure.toString()}'),
        (verses) {
          final int searchAyah = verse.ayah == 0 ? 1 : verse.ayah;
          final SearchVerseModel? matchingVerse = verses.cast<SearchVerseModel>().where((v) => v.ayah == searchAyah).firstOrNull;
          final targetPage = matchingVerse?.page;
          if (targetPage != null && targetPage != _currentPage) {
            _jumpToPage(targetPage, verseKey: null, animate: true);
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
      drawer: QuranDrawerDesktop(
        currentPage: _currentPage,
        onNavigateToPage: (page, {String? verseKey}) => _jumpToPage(page, verseKey: verseKey),
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

              if (isTwoPageMode != _wasTwoPageMode) {
                _wasTwoPageMode = isTwoPageMode;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final targetIndex = isTwoPageMode ? (_currentPage - 1) ~/ 2 : _currentPage - 1;
                  final controller = isTwoPageMode ? _pageControllerDouble : _pageControllerSingle;
                  if (controller.hasClients) controller.jumpToPage(targetIndex);
                });
              }

              return Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Stack(
                    children: [
                      BlocBuilder<AudioBloc, AudioState>(
                        builder: (context, state) {
                          final isVisible = state is! AudioIdle && state is! AudioError;
                          final double paddingBottom = isVisible ? (_isAudioExpanded ? 170 : 80) : 0;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.only(bottom: paddingBottom),
                            child: Listener(
                              onPointerSignal: (pointerSignal) {
                                if (pointerSignal is PointerScrollEvent) {
                                  final controller = isTwoPageMode ? _pageControllerDouble : _pageControllerSingle;
                                  if (pointerSignal.scrollDelta.dy > 0) {
                                    controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                                  } else if (pointerSignal.scrollDelta.dy < 0) {
                                    controller.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                                  }
                                }
                              },
                              child: PageView.builder(
                              key: ValueKey('page_view_$isTwoPageMode'),
                              controller: isTwoPageMode ? _pageControllerDouble : _pageControllerSingle,
                              allowImplicitScrolling: true,
                              itemCount: isTwoPageMode 
                                  ? (QuranConstants.totalPages / 2).ceil() 
                                  : QuranConstants.totalPages,
                              scrollDirection: settingsState.scrollDirection,
                              reverse: false,
                              onPageChanged: (index) {
                                setState(() {
                                  if (isTwoPageMode) {
                                    _currentPage = (index * 2) + 1;
                                  } else {
                                    _currentPage = index + 1;
                                  }
                                });
                                context.read<AudioPreferencesService>().saveLastReadPage(_currentPage);
                              },
                              itemBuilder: (context, index) {
                                if (isTwoPageMode) {
                                  final rightPage = (index * 2) + 1;
                                  final leftPage = (index * 2) + 2;

                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Center(
                                          child: AspectRatio(
                                            aspectRatio: 650 / 950,
                                            child: QuranPageWidgetDesktop(
                                              key: ValueKey('page_$rightPage'),
                                              pageNumber: rightPage,
                                              highlightVerseKey: (rightPage == _currentPage || leftPage == _currentPage) ? _highlightVerseKey : null,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (leftPage <= QuranConstants.totalPages)
                                        Container(
                                          width: 2,
                                          margin: const EdgeInsets.symmetric(vertical: 40),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.transparent,
                                                AppColors.accentGold.withValues(alpha: 0.3),
                                                Colors.transparent,
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                          ),
                                        ),
                                      if (leftPage <= QuranConstants.totalPages)
                                        Expanded(
                                          child: Center(
                                            child: AspectRatio(
                                              aspectRatio: 650 / 950,
                                              child: QuranPageWidgetDesktop(
                                                key: ValueKey('page_$leftPage'),
                                                pageNumber: leftPage,
                                                highlightVerseKey: (rightPage == _currentPage || leftPage == _currentPage) ? _highlightVerseKey : null,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        const Expanded(child: SizedBox()),
                                    ],
                                  );
                                } else {
                                  final int currentPage = index + 1;
                                  return Align(
                                    alignment: Alignment.center,
                                    child: AspectRatio(
                                      aspectRatio: 650 / 950,
                                      child: RepaintBoundary(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.1),
                                                blurRadius: 10,
                                                offset: const Offset(0, 5),
                                              ),
                                            ],
                                          ),
                                          child: QuranPageWidgetDesktop(
                                            key: ValueKey('page_$currentPage'),
                                            pageNumber: currentPage,
                                            highlightVerseKey: currentPage == _currentPage ? _highlightVerseKey : null,
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
                      BlocBuilder<AudioBloc, AudioState>(
                        builder: (context, state) {
                          final isVisible = state is! AudioIdle && state is! AudioError;
                          return AnimatedPositioned(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            bottom: isVisible ? 16 : -200,
                            left: 16,
                            right: 16,
                            child: MediaControlBar(
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
              );
            },
          ),
        ),
      ),
    );
  }
}








