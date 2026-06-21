import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/quran_page_widget.dart';
import '../bloc/audio/audio_bloc.dart';
import '../bloc/audio/audio_state.dart';
import '../widgets/media_control_bar.dart';
import '../widgets/drawer/quran_drawer.dart';

class QuranPageViewScreen extends StatefulWidget {
  const QuranPageViewScreen({super.key});

  @override
  State<QuranPageViewScreen> createState() => _QuranPageViewScreenState();
}

class _QuranPageViewScreenState extends State<QuranPageViewScreen> {
  late PageController _pageController;
  int _currentPage = 1;
  String? _highlightVerseKey; // set when navigating from bookmarks

  @override
  void initState() {
    super.initState();
    // PageView with reverse:true means:
    // - User swipes LEFT to go to NEXT page (higher number) = correct RTL reading
    // - index 0 = page 1 (displayed on the right side)
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Navigates to a specific Quran page (1-indexed).
  /// Optional [verseKey] will highlight that specific verse after navigation.
  void _jumpToPage(int pageNumber, {String? verseKey}) {
    final targetPage = pageNumber.clamp(1, 604);
    final targetIndex = targetPage - 1;
    _pageController.jumpToPage(targetIndex);
    setState(() {
      _currentPage = targetPage;
      _highlightVerseKey = verseKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFfdf4e0),
      // In RTL, 'drawer' opens from the RIGHT side.
      drawer: QuranDrawer(
        currentPage: _currentPage,
        onNavigateToPage: (page, {String? verseKey}) => _jumpToPage(page, verseKey: verseKey),
      ),
      body: SafeArea(
        child: BlocListener<AudioBloc, AudioState>(
          listener: (context, state) {
            if (state is AudioError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.message,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: const Color(0xFFC7B698),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                ),
              );
            }
          },
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: 604,
                scrollDirection: Axis.horizontal,
                // In RTL, reverse: false means index 0 is on the right, swiping left goes to index 1 (page 2)
                reverse: false,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index + 1;
                  });
                },
                itemBuilder: (context, index) {
                  final pageNumber = index + 1;
                  // Only pass the highlight verseKey to the currently-visible page
                  final highlight = (pageNumber == _currentPage) ? _highlightVerseKey : null;
                  return QuranPageWidget(
                    key: ValueKey(pageNumber),
                    pageNumber: pageNumber,
                    highlightVerseKey: highlight,
                  );
                },
              ),
              // Overlay Media Control Bar
              BlocBuilder<AudioBloc, AudioState>(
                builder: (context, state) {
                  final isVisible = state is! AudioIdle && state is! AudioError;
                  return AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    bottom: isVisible ? 16.0 : -200.0,
                    left: 16.0,
                    right: 16.0,
                    child: const MediaControlBar(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

