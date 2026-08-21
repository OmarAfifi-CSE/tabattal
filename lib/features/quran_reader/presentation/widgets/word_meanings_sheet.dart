import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/quran_metadata.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/arabic_text_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/verse_model.dart';
import '../../domain/repositories/quran_repository.dart';

class WordMeaningItem {
  final String word;
  final String meaning;

  const WordMeaningItem({
    required this.word,
    required this.meaning,
  });
}

List<WordMeaningItem> _parseGhareeb(String raw) {
  final lines = raw.split('\n');
  final items = <WordMeaningItem>[];
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final colonIdx = trimmed.indexOf(':');
    if (colonIdx != -1) {
      final word = trimmed.substring(0, colonIdx).trim();
      final meaning = trimmed.substring(colonIdx + 1).trim();
      items.add(WordMeaningItem(word: word, meaning: meaning));
    } else {
      items.add(WordMeaningItem(word: '', meaning: trimmed));
    }
  }
  return items;
}

class WordMeaningsSheet extends StatefulWidget {
  final VerseModel verse;

  const WordMeaningsSheet({
    super.key,
    required this.verse,
  });

  static Future<void> show(
    BuildContext context, {
    required VerseModel verse,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WordMeaningsSheet(verse: verse),
    );
  }

  @override
  State<WordMeaningsSheet> createState() => _WordMeaningsSheetState();
}

class _WordMeaningsSheetState extends State<WordMeaningsSheet> {
  List<WordMeaningItem>? _meanings;
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

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border.all(
          color: AppColors.verseMarkerGold.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 48.w,
                height: 4.h,
                margin: EdgeInsets.only(top: 12.h, bottom: 12.h),
                decoration: BoxDecoration(
                  color: AppColors.verseMarkerGold.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),

            // Header: Title & Surah/Ayah Reference
            _WordMeaningsHeader(
              surahName: surahName,
              ayahNumber: ayahNumber,
              isArabic: isArabic,
              l10n: l10n,
            ),

            SizedBox(height: 12.h),
            Divider(height: 1, color: AppColors.divider),

            // Content with natural wrapping sizing
            if (_isLoading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 36.h),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.verseMarkerGold,
                  ),
                ),
              )
            else if (_meanings == null || _meanings!.isEmpty)
              _WordMeaningsEmptyState(isArabic: isArabic)
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                  itemCount: _meanings!.length,
                  separatorBuilder: (context, index) => SizedBox(height: 10.h),
                  itemBuilder: (context, index) {
                    return _WordMeaningCard(
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

class _WordMeaningsHeader extends StatelessWidget {
  final String surahName;
  final int ayahNumber;
  final bool isArabic;
  final AppLocalizations l10n;

  const _WordMeaningsHeader({
    required this.surahName,
    required this.ayahNumber,
    required this.isArabic,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.translate_rounded,
                color: AppColors.verseMarkerGold,
                size: 22.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                l10n.wordMeaningsTitle,
                style: AppTextStyles.headerText.copyWith(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.verseMarkerGold,
                ),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: AppColors.verseMarkerGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppColors.verseMarkerGold.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              isArabic
                  ? 'سورة $surahName : ${ayahNumber.toString().toArabicDigits}'
                  : 'Surah $surahName : $ayahNumber',
              style: TextStyle(
                fontFamily: isArabic ? 'Amiri' : null,
                fontSize: 14.sp,
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

class _WordMeaningsEmptyState extends StatelessWidget {
  final bool isArabic;

  const _WordMeaningsEmptyState({required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.verseMarkerGold.withValues(alpha: 0.8),
            size: 36.sp,
          ),
          SizedBox(height: 10.h),
          Text(
            isArabic
                ? 'جميع مفردات الآية الكريمة واضحة وجلية المعنى'
                : 'All words in this verse are clear and straightforward.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: isArabic ? 'Amiri' : null,
              color: AppColors.textSecondary,
              fontSize: 15.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class _WordMeaningCard extends StatelessWidget {
  final WordMeaningItem item;
  final int index;

  const _WordMeaningCard({
    required this.item,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: 12.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.verseMarkerGold.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: TextDirection.rtl,
        children: [
          // Index Badge
          Container(
            width: 26.r,
            height: 26.r,
            margin: EdgeInsets.only(top: 2.h),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.verseMarkerGold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              (index + 1).toString().toArabicDigits,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.verseMarkerGold,
              ),
            ),
          ),
          SizedBox(width: 12.w),

          // Word and its Arabic Meaning
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.word.isNotEmpty) ...[
                  Text(
                    item.word,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'KFGQPC HAFS Uthmanic Script Regular',
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.verseMarkerGold,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 7.h),
                ],
                Text(
                  item.meaning,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 16.sp,
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
