import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/quran_metadata.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/arabic_text_utils.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../data/models/verse_model.dart';
import '../../../domain/repositories/quran_repository.dart';

class WordMeaningItemWeb {
  final String word;
  final String meaning;

  const WordMeaningItemWeb({
    required this.word,
    required this.meaning,
  });
}

List<WordMeaningItemWeb> _parseGhareeb(String raw) {
  final lines = raw.split('\n');
  final items = <WordMeaningItemWeb>[];
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final colonIdx = trimmed.indexOf(':');
    if (colonIdx != -1) {
      final word = trimmed.substring(0, colonIdx).trim();
      final meaning = trimmed.substring(colonIdx + 1).trim();
      items.add(WordMeaningItemWeb(word: word, meaning: meaning));
    } else {
      items.add(WordMeaningItemWeb(word: '', meaning: trimmed));
    }
  }
  return items;
}

class WordMeaningsSheetWeb extends StatefulWidget {
  final VerseModel verse;

  const WordMeaningsSheetWeb({
    super.key,
    required this.verse,
  });

  static Future<void> show(
    BuildContext context, {
    required VerseModel verse,
  }) {
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    if (isLandscape) {
      return showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              EdgeInsets.symmetric(horizontal: 40.w, vertical: 24.h),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520.w, maxHeight: 520.h),
            child: WordMeaningsSheetWeb(verse: verse),
          ),
        ),
      );
    }

    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: 620.w),
      builder: (ctx) => WordMeaningsSheetWeb(verse: verse),
    );
  }

  @override
  State<WordMeaningsSheetWeb> createState() =>
      _WordMeaningsSheetWebState();
}

class _WordMeaningsSheetWebState extends State<WordMeaningsSheetWeb> {
  List<WordMeaningItemWeb>? _meanings;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMeanings();
      }
    });
  }

  Future<void> _loadMeanings() async {
    setState(() => _isLoading = true);
    final repo = context.read<QuranRepository>();
    final result = await repo.getGhareebByVerse(widget.verse.verseKey);
    if (!mounted) return;

    result.fold(
      (_) => setState(() {
        _meanings = const [];
        _isLoading = false;
      }),
      (text) => setState(() {
        _meanings = text != null ? _parseGhareeb(text) : const [];
        _isLoading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final parsed = ArabicTextUtils.parseVerseKey(widget.verse.verseKey);
    final surahNumber = parsed?.surah ?? 1;
    final ayahNumber = parsed?.ayah ?? widget.verse.verseNumber;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final surahName = isArabic
        ? QuranMetadata.getSurahName(surahNumber)
        : QuranMetadata.getSurahNameEnglish(surahNumber);
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: isLandscape ? 520.h : MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceCream,
        borderRadius: isLandscape
            ? BorderRadius.circular(20.r)
            : BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border.all(
          color: AppColors.verseMarkerGold.withValues(alpha: 0.4),
          width: 1.5.w,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30.r,
            offset: Offset(0, -5.h),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isLandscape)
              Center(
                child: Container(
                  width: 56.w,
                  height: 4.5.h,
                  margin: EdgeInsets.only(top: 12.h, bottom: 14.h),
                  decoration: BoxDecoration(
                    color: AppColors.verseMarkerGold.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                ),
              )
            else
              SizedBox(height: 16.h),

            _WordMeaningsHeaderWeb(
              surahName: surahName,
              ayahNumber: ayahNumber,
              isArabic: isArabic,
              l10n: l10n,
            ),
            SizedBox(height: 8.h),
            Divider(height: 1, color: AppColors.divider),

            // Content with natural wrapping sizing like mobile
            if (_isLoading)
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: (isLandscape ? 24.0 : 36.0).h,
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.verseMarkerGold,
                  ),
                ),
              )
            else if (_meanings == null || _meanings!.isEmpty)
              _WordMeaningsEmptyStateWeb(
                isArabic: isArabic,
                l10n: l10n,
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.symmetric(
                    horizontal: (isLandscape ? 16.0 : 20.0).w,
                    vertical: (isLandscape ? 10.0 : 14.0).h,
                  ),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _meanings!.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(height: (isLandscape ? 8.0 : 10.0).h),
                  itemBuilder: (context, index) {
                    return _WordMeaningCardWeb(
                      item: _meanings![index],
                      index: index,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WordMeaningsHeaderWeb extends StatelessWidget {
  final String surahName;
  final int ayahNumber;
  final bool isArabic;
  final AppLocalizations l10n;

  const _WordMeaningsHeaderWeb({
    required this.surahName,
    required this.ayahNumber,
    required this.isArabic,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: (isLandscape ? 16.0 : 20.0).w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.translate_rounded,
                color: AppColors.verseMarkerGold,
                size: (isLandscape ? 20.0 : 26.0).sp,
              ),
              SizedBox(width: (isLandscape ? 8.0 : 10.0).w),
              Text(
                l10n.wordMeaningsTitle,
                style: AppTextStyles.headerText.copyWith(
                  fontSize: (isLandscape ? 16.0 : 21.0).sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.verseMarkerGold,
                ),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: (isLandscape ? 10.0 : 14.0).w,
              vertical: (isLandscape ? 4.0 : 6.0).h,
            ),
            decoration: BoxDecoration(
              color: AppColors.verseMarkerGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular((isLandscape ? 10.0 : 12.0).r),
              border: Border.all(
                color: AppColors.verseMarkerGold.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              isArabic
                  ? 'سورة $surahName : الآية ${ArabicTextUtils.toArabicDigits(ayahNumber)}'
                  : 'Surah $surahName : $ayahNumber',
              style: TextStyle(
                fontFamily: isArabic ? 'Amiri' : null,
                fontSize: (isLandscape ? 13.0 : 16.0).sp,
                fontWeight: FontWeight.bold,
                color: AppColors.verseMarkerGold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WordMeaningsEmptyStateWeb extends StatelessWidget {
  final bool isArabic;
  final AppLocalizations l10n;

  const _WordMeaningsEmptyStateWeb({
    required this.isArabic,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: (isLandscape ? 16.0 : 24.0).w,
        vertical: (isLandscape ? 18.0 : 28.0).h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.verseMarkerGold.withValues(alpha: 0.8),
            size: (isLandscape ? 32.0 : 42.0).sp,
          ),
          SizedBox(height: (isLandscape ? 8.0 : 12.0).h),
          Text(
            isArabic
                ? 'جميع مفردات الآية الكريمة واضحة وجلية المعنى'
                : 'All words in this verse are clear in meaning',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: isArabic ? 'Amiri' : null,
              color: AppColors.textSecondary,
              fontSize: (isLandscape ? 14.5 : 17.5).sp,
            ),
          ),
        ],
      ),
    );
  }
}

class _WordMeaningCardWeb extends StatelessWidget {
  final WordMeaningItemWeb item;
  final int index;

  const _WordMeaningCardWeb({
    required this.item,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: (isLandscape ? 14.0 : 18.0).w,
        vertical: (isLandscape ? 10.0 : 14.0).h,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular((isLandscape ? 10.0 : 14.0).r),
        border: Border.all(
          color: AppColors.verseMarkerGold.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: (isLandscape ? 24.0 : 30.0).r,
            height: (isLandscape ? 24.0 : 30.0).r,
            margin: EdgeInsets.only(top: (isLandscape ? 1.0 : 2.0).h),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.verseMarkerGold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              ArabicTextUtils.toArabicDigits(index + 1),
              style: TextStyle(
                fontSize: (isLandscape ? 11.5 : 14.0).sp,
                fontWeight: FontWeight.bold,
                color: AppColors.verseMarkerGold,
              ),
            ),
          ),
          SizedBox(width: (isLandscape ? 10.0 : 12.0).w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (item.word.isNotEmpty) ...[
                  Text(
                    item.word,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'KFGQPC HAFS Uthmanic Script Regular',
                      fontSize: (isLandscape ? 17.0 : 23.0).sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.verseMarkerGold,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: (isLandscape ? 4.0 : 7.0).h),
                ],
                Text(
                  item.meaning,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: (isLandscape ? 14.5 : 18.5).sp,
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
