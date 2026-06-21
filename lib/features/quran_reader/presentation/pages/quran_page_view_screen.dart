import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/quran_page_widget.dart';
import '../bloc/audio/audio_bloc.dart';
import '../bloc/audio/audio_state.dart';
import '../widgets/media_control_bar.dart';
class QuranPageViewScreen extends StatefulWidget {
  const QuranPageViewScreen({super.key});

  @override
  State<QuranPageViewScreen> createState() => _QuranPageViewScreenState();
}

class _QuranPageViewScreenState extends State<QuranPageViewScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFfdf4e0), // Warm background color to match edge
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
                  backgroundColor: const Color(0xFFC7B698), // Premium gold
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
                reverse: true, 
                itemBuilder: (context, index) {
                  final pageNumber = index + 1;
                  return QuranPageWidget(
                    key: ValueKey(pageNumber),
                    pageNumber: pageNumber,
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
