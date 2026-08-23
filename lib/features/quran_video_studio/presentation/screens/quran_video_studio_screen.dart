import 'package:flutter/material.dart';
import '../../../quran_reader/data/models/verse_model.dart';
import '../../../quran_reader/presentation/widgets/verse_card_generator_sheet.dart';

/// Shows the unified Quran Video Studio modal bottom sheet matching the app theme.
void showQuranVideoStudioModal(
  BuildContext context, {
  required int surahNumber,
  required int startAyah,
  int? endAyah,
  List<VerseModel>? initialVerses,
}) {
  showVerseCardGeneratorModal(
    context,
    verse: (initialVerses != null && initialVerses.isNotEmpty)
        ? initialVerses.first
        : VerseModel(
            id: 0,
            verseNumber: startAyah,
            verseKey: '$surahNumber:$startAyah',
            textUthmani: '',
            juzNumber: 1,
            words: const [],
          ),
    initialFormat: ShareFormat.video,
    initialVerses: initialVerses,
  );
}

/// Unified entry point for Quran Video Studio screen, delegated to VerseCardGeneratorSheet.
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

    return VerseCardGeneratorSheet(
      verse: effectiveVerse,
      initialFormat: ShareFormat.video,
      initialVerses: initialVerses,
    );
  }
}
