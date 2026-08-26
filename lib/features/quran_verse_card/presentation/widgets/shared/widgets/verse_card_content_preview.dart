import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../core/constants/quran_metadata.dart';
import '../../../../../../core/widgets/mixed_direction_text.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../helpers/verse_card_text_utils.dart';
import '../models/verse_card_theme.dart';

/// The visual Verse Card content rendered inside the RepaintBoundary.
class VerseCardContentPreview extends StatelessWidget {
  final VerseCardTheme theme;
  final int surahNumber;
  final int startAyah;
  final int endAyah;
  final String verseTextUthmani;
  final List<TextSpan> qcfSpans;
  final bool isLoadingText;
  final bool includeTafsir;
  final String tafsirText;
  final bool isLoadingTafsir;
  final bool includeTranslation;
  final String translationText;
  final bool isLoadingTranslation;

  const VerseCardContentPreview({
    super.key,
    required this.theme,
    required this.surahNumber,
    required this.startAyah,
    required this.endAyah,
    required this.verseTextUthmani,
    required this.qcfSpans,
    required this.isLoadingText,
    required this.includeTafsir,
    required this.tafsirText,
    required this.isLoadingTafsir,
    required this.includeTranslation,
    required this.translationText,
    required this.isLoadingTranslation,
  });

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final surahCleanName = isEn
        ? QuranMetadata.getSurahNameEnglish(surahNumber)
        : QuranMetadata.getSurahName(surahNumber);
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.sizeOf(context).width;

    final bool showBismillah =
        startAyah == 1 && surahNumber != 9 && surahNumber != 1;

    return Container(
      width: screenWidth,
      color: theme.backgroundColor,
      padding: EdgeInsets.all(12.r),
      child: Container(
        width: screenWidth,
        decoration: BoxDecoration(
          color: theme.cardBackground,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: theme.borderColor, width: 1.5),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 18.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top Decorative Header
            if (showBismillah)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 1,
                    width: 30.w,
                    color: theme.accentColor.withValues(alpha: 0.6),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 14.sp,
                      color: theme.accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    height: 1,
                    width: 30.w,
                    color: theme.accentColor.withValues(alpha: 0.6),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 1,
                    width: 38.w,
                    color: theme.accentColor.withValues(alpha: 0.4),
                  ),
                  SizedBox(width: 6.w),
                  Icon(
                    Icons.star_rate_rounded,
                    size: 10.r,
                    color: theme.accentColor.withValues(alpha: 0.7),
                  ),
                  SizedBox(width: 6.w),
                  Container(
                    height: 1,
                    width: 38.w,
                    color: theme.accentColor.withValues(alpha: 0.4),
                  ),
                ],
              ),

            SizedBox(height: 14.h),

            // Quran Verse Text
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: isLoadingText && verseTextUthmani.isEmpty
                  ? Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: CupertinoActivityIndicator(
                        color: theme.accentColor,
                        radius: 12.r,
                      ),
                    )
                  : Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text.rich(
                        TextSpan(
                          style: VerseCardTextUtils.getDynamicVerseTextStyle(
                            hasQcfFont: qcfSpans.isNotEmpty,
                            verseText: verseTextUthmani,
                            theme: theme,
                          ),
                          children: qcfSpans.isNotEmpty
                              ? qcfSpans
                              : [
                                  TextSpan(
                                    text: '﴿ $verseTextUthmani ﴾',
                                    style: const TextStyle(fontFamily: 'Amiri'),
                                  ),
                                ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),

            SizedBox(height: 14.h),

            // Surah Name Badge
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 4.h,
              ),
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: theme.accentColor.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Text(
                startAyah == endAyah
                    ? l10n.verseCardSurahSingleAyah(
                        surahCleanName,
                        isEn
                            ? '$startAyah'
                            : VerseCardTextUtils.toArabicDigits(startAyah),
                      )
                    : l10n.verseCardSurahMultipleAyahs(
                        surahCleanName,
                        isEn
                            ? '$startAyah'
                            : VerseCardTextUtils.toArabicDigits(startAyah),
                        isEn
                            ? '$endAyah'
                            : VerseCardTextUtils.toArabicDigits(endAyah),
                      ),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: theme.accentColor,
                ),
              ),
            ),

            // Optional Tafsir Box
            if (includeTafsir) ...[
              SizedBox(height: 12.h),
              Container(
                width: screenWidth,
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: theme.cardBackground,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: theme.borderColor.withValues(alpha: 0.6),
                  ),
                ),
                child: isLoadingTafsir
                    ? Center(
                        child: CupertinoActivityIndicator(
                          color: theme.accentColor,
                          radius: 8.r,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: isEn
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.menu_book_outlined,
                                  size: 12.r,
                                  color: theme.accentColor,
                                ),
                                SizedBox(width: 5.w),
                                Text(
                                  l10n.verseCardTafsirBadge,
                                  style: TextStyle(
                                    fontFamily: isEn ? null : 'Amiri',
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                    color: theme.accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 6.h),
                          MixedDirectionText(
                            text: tafsirText.trim(),
                            style: TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 12.sp,
                              height: 1.6,
                              color: theme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
              ),
            ],

            // Optional Translation Box
            if (includeTranslation) ...[
              SizedBox(height: 12.h),
              Container(
                width: screenWidth,
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: theme.cardBackground,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: theme.borderColor.withValues(alpha: 0.6),
                  ),
                ),
                child: isLoadingTranslation
                    ? Center(
                        child: CupertinoActivityIndicator(
                          color: theme.accentColor,
                          radius: 8.r,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: isEn
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.g_translate_outlined,
                                  size: 12.r,
                                  color: theme.accentColor,
                                ),
                                SizedBox(width: 5.w),
                                Text(
                                  l10n.verseCardTranslationBadge,
                                  style: TextStyle(
                                    fontFamily: isEn ? null : 'Amiri',
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                    color: theme.accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 6.h),
                          MixedDirectionText(
                            text: translationText.trim(),
                            style: TextStyle(
                              fontSize: 12.sp,
                              height: 1.5,
                              fontStyle: FontStyle.italic,
                              color: theme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
              ),
            ],

            // Footer Branding Watermark
            SizedBox(height: 14.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  size: 12.r,
                  color: theme.accentColor,
                ),
                SizedBox(width: 6.w),
                Text(
                  isEn ? 'Tabattal' : 'تَـبَـتَّـلْ',
                  style: TextStyle(
                    fontFamily: isEn ? null : 'Amiri',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: theme.secondaryTextColor.withValues(alpha: 0.85),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
