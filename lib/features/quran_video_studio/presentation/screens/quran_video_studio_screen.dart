import 'package:flutter/material.dart';
import '../../../quran_reader/data/models/verse_model.dart';
import '../../../quran_reader/presentation/widgets/mobile/verse_card_generator_sheet_mobile.dart';
import '../../../quran_reader/presentation/widgets/tablet/verse_card_generator_sheet_tablet.dart';

/// Shows the unified Quran Video Studio modal bottom sheet matching the app theme.
void showQuranVideoStudioModal(
  BuildContext context, {
  required int surahNumber,
  required int startAyah,
  int? endAyah,
  List<VerseModel>? initialVerses,
}) {
  final verse = (initialVerses != null && initialVerses.isNotEmpty)
      ? initialVerses.first
      : VerseModel(
          id: 0,
          verseNumber: startAyah,
          verseKey: '$surahNumber:$startAyah',
          textUthmani: '',
          juzNumber: 1,
          words: const [],
        );

  final isTablet = MediaQuery.sizeOf(context).width > 600;
  if (isTablet) {
    showVerseCardGeneratorModalTablet(
      context,
      verse: verse,
      initialFormat: ShareFormat.video,
      initialVerses: initialVerses,
    );
  } else {
    showVerseCardGeneratorModalMobile(
      context,
      verse: verse,
      initialFormat: ShareFormat.video,
      initialVerses: initialVerses,
    );
  }
}

/// Unified entry point for Quran Video Studio screen.
class QuranVideoStudioScreen extends StatelessWidget {
  final int surahNumber;
  final int startAyah;
  final int endAyah;
  final List<VerseModel> initialVerses;
  final bool isBottomSheet;

  const QuranVideoStudioScreen({
    super.key,
    required this.surahNumber,
    required this.startAyah,
    required this.endAyah,
    required this.initialVerses,
    this.isBottomSheet = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveVerse = initialVerses.isNotEmpty
        ? initialVerses.first
        : VerseModel(
            id: 0,
            verseNumber: startAyah,
            verseKey: '$surahNumber:$startAyah',
            textUthmani: '',
            juzNumber: 1,
            words: const [],
          );

    final isTablet = MediaQuery.sizeOf(context).width > 600;
    if (isTablet) {
      return VerseCardGeneratorSheetTablet(
        verse: effectiveVerse,
        initialFormat: ShareFormat.video,
        initialVerses: initialVerses,
      );
    }

    return VerseCardGeneratorSheetMobile(
      verse: effectiveVerse,
      initialFormat: ShareFormat.video,
      initialVerses: initialVerses,
    );
  }
}
