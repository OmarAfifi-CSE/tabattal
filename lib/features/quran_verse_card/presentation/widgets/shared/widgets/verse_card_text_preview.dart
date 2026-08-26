import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../core/constants/quran_metadata.dart';
import '../../../../../../core/widgets/mixed_direction_text.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../helpers/verse_card_text_utils.dart';
import '../models/verse_card_theme.dart';

/// Text preview widget for sharing formatted verse text.
class VerseCardTextPreview extends StatelessWidget {
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

  const VerseCardTextPreview({
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
    final surahName = isEn
        ? QuranMetadata.getSurahNameEnglish(surahNumber)
        : QuranMetadata.getSurahName(surahNumber);
    final l10n = AppLocalizations.of(context)!;

    final rangeText = startAyah == endAyah
        ? l10n.verseCardSurahSingleAyah(
            surahName,
            isEn ? '$startAyah' : VerseCardTextUtils.toArabicDigits(startAyah),
          )
        : l10n.verseCardSurahMultipleAyahs(
            surahName,
            isEn ? '$startAyah' : VerseCardTextUtils.toArabicDigits(startAyah),
            isEn ? '$endAyah' : VerseCardTextUtils.toArabicDigits(endAyah),
          );

    return Container(
      width: MediaQuery.sizeOf(context).width,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: theme.borderColor, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
                                  text: '( $verseTextUthmani )',
                                  style: const TextStyle(fontFamily: 'Amiri'),
                                ),
                              ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),

          if (includeTafsir) ...[
            SizedBox(height: 12.h),
            Container(
              width: MediaQuery.sizeOf(context).width,
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: theme.backgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: theme.accentColor.withValues(alpha: 0.25),
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
                                Icons.auto_stories_outlined,
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

          if (includeTranslation) ...[
            SizedBox(height: 12.h),
            Container(
              width: MediaQuery.sizeOf(context).width,
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: theme.backgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: theme.accentColor.withValues(alpha: 0.25),
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
                                Icons.translate_rounded,
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

          SizedBox(height: 12.h),

          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: theme.accentColor.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              rangeText,
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: theme.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
