import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/quran_page_widget.dart';
import '../bloc/audio/audio_bloc.dart';
import '../bloc/audio/audio_state.dart';
import '../widgets/media_control_bar.dart';
import '../widgets/drawer/quran_drawer.dart';
import '../../../../core/services/audio_preferences_service.dart';
import '../../domain/repositories/quran_repository.dart';
import '../../data/models/search_verse_model.dart';
import '../../../../core/utils/verse_ref.dart';
import '../../../../core/constants/quran_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/settings/presentation/bloc/settings_bloc.dart';
import 'package:flutter/services.dart';
import '../../../../l10n/app_localizations.dart';
class QuranPageViewScreen extends StatefulWidget {
  const QuranPageViewScreen({super.key});

  @override
  State<QuranPageViewScreen> createState() => _QuranPageViewScreenState();
}

class _QuranPageViewScreenState extends State<QuranPageViewScreen> {
  late PageController _pageController;
  int _currentPage = 1;
  String? _highlightVerseKey;
  bool _isAudioExpanded = true;

  @override
  void initState() {
    super.initState();
    _currentPage = context.read<AudioPreferencesService>().lastReadPage;
    _pageController = PageController(initialPage: _currentPage - 1);
  }

  @override
  void dispose() {
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
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp),
        ),
        backgroundColor: AppColors.verseMarkerGold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.r),
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
    // Watch SettingsBloc so this screen rebuilds instantly on theme change
    final settingsState = context.watch<SettingsBloc>().state;
    final isDarkMode = settingsState.effectiveMushafTheme.id == 'dark';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
      drawer: QuranDrawer(
        currentPage: _currentPage,
        onNavigateToPage: (page, {String? verseKey}) => _jumpToPage(page, verseKey: verseKey),
      ),
      body: SafeArea(
        child: BlocListener<AudioBloc, AudioState>(
          listener: _handleAudioStateChange,
          child: Stack(
            children: [
              BlocBuilder<AudioBloc, AudioState>(
                builder: (context, state) {
                  final isVisible = state is! AudioIdle && state is! AudioError;
                  final double paddingBottom = isVisible ? (_isAudioExpanded ? 170.h : 80.h) : 0;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.only(bottom: paddingBottom),
                    child: PageView.builder(
                      controller: _pageController,
                      allowImplicitScrolling: true,
                      itemCount: QuranConstants.totalPages,
                      scrollDirection: Axis.horizontal,
                      reverse: false,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index + 1);
                        context.read<AudioPreferencesService>().saveLastReadPage(_currentPage);
                      },
                      itemBuilder: (context, index) {
                        final pageNumber = index + 1;
                        return QuranPageWidget(
                          key: ValueKey(pageNumber),
                          pageNumber: pageNumber,
                          highlightVerseKey: pageNumber == _currentPage ? _highlightVerseKey : null,
                        );
                      },
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
                    bottom: isVisible ? 16.h : -200.h,
                    left: 16.w,
                    right: 16.w,
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
        ),
      ),
    );
  }
}
