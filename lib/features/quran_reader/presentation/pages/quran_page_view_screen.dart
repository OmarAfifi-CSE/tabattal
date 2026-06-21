import 'package:flutter/material.dart';
import '../widgets/quran_page_widget.dart';

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
      backgroundColor: const Color(0xFFFAF5EB),
      body: SafeArea(
        child: PageView.builder(
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
      ),
    );
  }
}
