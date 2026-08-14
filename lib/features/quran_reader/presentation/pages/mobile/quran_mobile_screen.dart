import '../../widgets/drawer/mobile/quran_drawer_mobile.dart';
import '../../widgets/hifz/hifz_toolbar_widget.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../widgets/mobile/quran_page_widget_mobile.dart';
import '../../widgets/quran_glyph_prewarmer.dart';
import '../../../bloc/audio/audio_bloc.dart';
import '../../../bloc/audio/audio_state.dart';
import '../../widgets/mobile/media_control_bar_mobile.dart';
import '../../../../../core/services/audio_preferences_service.dart';
import '../../../../../core/services/font_service.dart';
import '../../../bloc/quran/quran_page_cache.dart';
import '../../../bloc/quran/quran_state.dart';
import '../../../domain/repositories/quran_repository.dart';
import '../../../data/models/search_verse_model.dart';
import '../../../data/models/verse_model.dart';
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
  late PageController _pageController;
  int _currentPage = 1;
  String? _highlightVerseKey;
  bool _isAudioExpanded = true;

  @override
  void initState() {
    super.initState();
    _currentPage = context.read<AudioPreferencesService>().lastReadPage;
    _pageController = PageController(initialPage: _currentPage - 1);
    _prefetchAdjacentPages(_currentPage);

    // Only fire setState once the page animation is fully settled at an
    // integer position (finger lifted + snap complete). This keeps the
    // swipe animation completely rebuild-free — zero jank.
    _pageController.addListener(_onPageScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UpdateService.checkForUpdates(context);
      }
    });
  }

  void _onPageScroll() {
    final pos = _pageController.page;
    if (pos == null) return;
    // Fire only when fully settled at an exact integer position.
    if (pos == pos.roundToDouble()) {
      final settled = pos.round() + 1;
      if (settled != _currentPage && mounted) {
        setState(() => _currentPage = settled);
        context.read<AudioPreferencesService>().saveLastReadPage(_currentPage);
        _prefetchAdjacentPages(_currentPage);
      }
    }
  }

  Timer? _prefetchTimer;

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _prefetchTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _jumpToPage(int pageNumber, {String? verseKey, bool animate = false}) {
    final targetPage = pageNumber.clamp(1, QuranConstants.totalPages);
    final targetIndex = targetPage - 1;
    if (animate) {
      _pageController.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _pageController.jumpToPage(targetIndex);
    }
    setState(() {
      _currentPage = targetPage;
      _highlightVerseKey = verseKey;
    });
    context.read<AudioPreferencesService>().saveLastReadPage(_currentPage);
  }


  bool _isSwiping = false;

  /// Immediate pre-warming for immediate neighbors [page-1, page+1] in post-frame callback
  /// so when the user touches the screen to drag, both adjacent page fonts, SQLite lines,
  /// and line widths are ALREADY 100% in memory — delivering 0ms initial touch lag.
  void _prefetchAdjacentPages(int page) {
    _prefetchTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isSwiping) return;
      _prefetchImmediateNeighbors(page);
    });
  }

  Future<void> _prefetchImmediateNeighbors(int page) async {
    if (_isSwiping) return;
    final repository = context.read<QuranRepository>();
    final immediate = [page + 1, page - 1];

    for (final neighbor in immediate) {
      if (!mounted) return;
      if (neighbor >= 1 && neighbor <= QuranConstants.totalPages) {
        final fontName = 'QCF_P${neighbor.toString().padLeft(3, '0')}';
        if (!FontService.isLoaded(fontName)) {
          await FontService.loadFontForPage(neighbor);
        }
        if (!mounted) return;
        if (QuranPageCache.get(neighbor) == null) {
          final result = await repository.getLinesByPage(neighbor);
          result.fold((_) {}, (lines) {
            QuranPageCache.put(
              neighbor,
              QuranLoaded(lines: lines, currentPage: neighbor),
            );
            if (QuranPageCache.getCachedLineWidth(neighbor) == null) {
              _precalculateLineWidth(neighbor, lines);
            }
          });
        }
      }
    }

    _prefetchTimer = Timer(const Duration(milliseconds: 200), () async {
      if (!mounted) return;
      final secondary = [page + 2, page - 2];
      for (final neighbor in secondary) {
        if (!mounted) return;
        if (neighbor >= 1 && neighbor <= QuranConstants.totalPages) {
          final fontName = 'QCF_P${neighbor.toString().padLeft(3, '0')}';
          if (!FontService.isLoaded(fontName)) {
            await FontService.loadFontForPage(neighbor);
            await Future<void>.delayed(const Duration(milliseconds: 30));
          }
          if (!mounted) return;
          if (QuranPageCache.get(neighbor) == null) {
            final result = await repository.getLinesByPage(neighbor);
            result.fold((_) {}, (lines) {
              QuranPageCache.put(
                neighbor,
                QuranLoaded(lines: lines, currentPage: neighbor),
              );
              if (QuranPageCache.getCachedLineWidth(neighbor) == null) {
                _precalculateLineWidth(neighbor, lines);
              }
            });
            await Future<void>.delayed(const Duration(milliseconds: 30));
          }
        }
      }
    });
  }

  void _precalculateLineWidth(int pageNumber, List<LineData> lines) {
    final pageStr = pageNumber.toString().padLeft(3, '0');
    final fontFamily = 'QCF_P$pageStr';
    final style = TextStyle(fontFamily: fontFamily, fontSize: 32.sp);
    final tp = TextPainter(textDirection: TextDirection.rtl);
    var maxLW = 0.0;

    for (final lineData in lines) {
      if (lineData.words.isEmpty) continue;
      final lineText = lineData.words
          .map((w) => w.codeV1.isNotEmpty ? w.codeV1 : w.textUthmani)
          .where((t) => t.isNotEmpty)
          .join();
      if (lineText.isEmpty) continue;
      tp.text = TextSpan(text: lineText, style: style);
      tp.layout();
      if (tp.width > maxLW) maxLW = tp.width;
    }
    tp.dispose();
    QuranPageCache.cacheLineWidth(pageNumber, maxLW + 2.0);
  }

  void _handleAudioStateChange(BuildContext context, AudioState state) {
    if (state is AudioError) {
      _showErrorSnackBar(state.message);
    } else if (state is AudioPlaying) {
      _navigateToPlayingVerse(context, state.currentVerseId);
    } else if (state is AudioIdle) {
      _isAudioExpanded = true; // reset to expanded for next time
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
            _jumpToPage(targetPage, verseKey: null, animate: true);
          }
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch SettingsBloc so this screen rebuilds instantly on theme change
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
              _jumpToPage(page, verseKey: verseKey),
        ),
        body: SafeArea(
          child: BlocListener<AudioBloc, AudioState>(
            listener: _handleAudioStateChange,
            child: Stack(
              children: [
                if (_currentPage < QuranConstants.totalPages)
                  Positioned(
                    left: -50,
                    top: -50,
                    child: QuranGlyphPrewarmer(pageNumber: _currentPage + 1),
                  ),
                if (_currentPage > 1)
                  Positioned(
                    left: -50,
                    top: -50,
                    child: QuranGlyphPrewarmer(pageNumber: _currentPage - 1),
                  ),
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
                        ? (_isAudioExpanded ? 170.h : 80.h)
                        : 0;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.only(bottom: paddingBottom),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.depth == 0) {
                            if (notification is ScrollStartNotification) {
                              _isSwiping = true;
                              _prefetchTimer?.cancel();
                              QuranPageWidgetMobile.dismissActiveMenu();
                            } else if (notification is ScrollEndNotification) {
                              _isSwiping = false;
                            }
                          }
                          return false;
                        },
                        child: PageView.builder(
                          dragStartBehavior: DragStartBehavior.down,
                          physics: const BouncingScrollPhysics(),
                          controller: _pageController,
                          allowImplicitScrolling: true,
                          itemCount: QuranConstants.totalPages,
                          scrollDirection: settingsState.scrollDirection,
                          reverse: false,
                          itemBuilder: (context, index) {
                            final pageNumber = index + 1;
                            return QuranPageWidgetMobile(
                              key: ValueKey(pageNumber),
                              pageNumber: pageNumber,
                              onNavigateToPage: (page, {verseKey}) =>
                                  _jumpToPage(page, verseKey: verseKey),
                              highlightVerseKey: pageNumber == _currentPage
                                  ? _highlightVerseKey
                                  : null,
                            );
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
                      bottom: isVisible ? 16.h : -200.h,
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
