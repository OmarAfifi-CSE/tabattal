import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../quran_reader/data/models/verse_model.dart';
import '../../../quran_verse_card/presentation/widgets/desktop/verse_card_generator_sheet_desktop.dart';
import '../../../quran_verse_card/presentation/widgets/mobile/verse_card_generator_sheet_mobile.dart';
import '../../../quran_verse_card/presentation/widgets/tablet/verse_card_generator_sheet_tablet.dart';
import '../../../quran_verse_card/presentation/widgets/web/verse_card_generator_sheet_web.dart';

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

  final width = MediaQuery.sizeOf(context).width;
  if (kIsWeb || width > 1000) {
    if (kIsWeb) {
      showVerseCardGeneratorModalWeb(
        context,
        verse: verse,
        initialFormat: ShareFormat.video,
        initialVerses: initialVerses,
      );
    } else {
      showVerseCardGeneratorModalDesktop(
        context,
        verse: verse,
        initialFormat: ShareFormat.video,
        initialVerses: initialVerses,
      );
    }
  } else if (width > 600) {
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

    final width = MediaQuery.sizeOf(context).width;
    if (kIsWeb) {
      return VerseCardGeneratorSheetWeb(
        verse: effectiveVerse,
        initialFormat: ShareFormat.video,
        initialVerses: initialVerses,
      );
    }
    if (width > 1000) {
      return VerseCardGeneratorSheetDesktop(
        verse: effectiveVerse,
        initialFormat: ShareFormat.video,
        initialVerses: initialVerses,
      );
    }
    if (width > 600) {
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
