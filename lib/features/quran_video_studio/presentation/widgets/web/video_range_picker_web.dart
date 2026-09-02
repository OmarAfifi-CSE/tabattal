import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/quran_metadata.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../quran_verse_card/presentation/widgets/shared/helpers/verse_card_text_utils.dart';

class VideoRangePickerWeb extends StatelessWidget {
  final int surahNumber;
  final int startAyah;
  final int endAyah;
  final ValueChanged<int> onStartAyahChanged;
  final ValueChanged<int> onEndAyahChanged;

  const VideoRangePickerWeb({
    super.key,
    required this.surahNumber,
    required this.startAyah,
    required this.endAyah,
    required this.onStartAyahChanged,
    required this.onEndAyahChanged,
  });

  int get totalAyahsInSurah => QuranMetadata.getVerseCountForSurah(surahNumber);

  int _getMaxEndAyah(int start) {
    return (start + 9).clamp(1, totalAyahsInSurah);
  }

  void _showAyahPickerDialog({
    required BuildContext context,
    required String title,
    required int currentValue,
    required List<int> options,
    required ValueChanged<int> onSelected,
  }) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppColors.cardCream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0.r),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420.w, maxHeight: 480.h),
            child: Directionality(
              textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.all(20.0.r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 17.0.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded, size: 24.sp),
                        ),
                      ],
                    ),
                    Divider(height: 1.h),
                    SizedBox(height: 10.0.h),
                    Expanded(
                      child: GridView.builder(
                        padding: EdgeInsets.symmetric(vertical: 8.0.h),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          childAspectRatio: 1.3,
                          crossAxisSpacing: 10.w,
                          mainAxisSpacing: 10.h,
                        ),
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final ayah = options[index];
                          final isSelected = ayah == currentValue;

                          return InkWell(
                            onTap: () {
                              onSelected(ayah);
                              Navigator.pop(ctx);
                            },
                            borderRadius: BorderRadius.circular(12.0.r),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.accentGold
                                    : AppColors.accentGold
                                        .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12.0.r),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.accentGold
                                      : AppColors.accentGold
                                          .withValues(alpha: 0.25),
                                  width: 1.w,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                Localizations.localeOf(context).languageCode ==
                                        'en'
                                    ? '$ayah'
                                    : VerseCardTextUtils.toArabicDigits(ayah),
                                style: TextStyle(
                                  fontSize: 15.0.sp,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final startOptions = List.generate(totalAyahsInSurah, (i) => i + 1);
    final maxEnd = _getMaxEndAyah(startAyah);
    final endOptions = List.generate(
      maxEnd - startAyah + 1,
      (i) => startAyah + i,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.videoStudioVerseRange,
              style: TextStyle(
                fontSize: 16.0.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(width: 8.0.w),
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 8.0.w, vertical: 3.0.h),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8.0.r),
                border: Border.all(
                  color: AppColors.accentGold.withValues(alpha: 0.28),
                  width: 1.w,
                ),
              ),
              child: Text(
                l10n.verseCardSurah(
                  isEn
                      ? QuranMetadata.getSurahNameEnglish(surahNumber)
                      : QuranMetadata.getSurahName(surahNumber),
                ),
                style: TextStyle(
                  fontSize: 13.0.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentGold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.0.h),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  _showAyahPickerDialog(
                    context: context,
                    title: l10n.verseCardStartAyah,
                    currentValue: startAyah,
                    options: startOptions,
                    onSelected: (val) {
                      onStartAyahChanged(val);
                    },
                  );
                },
                borderRadius: BorderRadius.circular(12.0.r),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.0.w,
                    vertical: 10.0.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12.0.r),
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.2),
                      width: 1.w,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          l10n.verseCardFromAyah(
                            isEn
                                ? '$startAyah'
                                : VerseCardTextUtils.toArabicDigits(startAyah),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20.0.sp,
                        color: AppColors.accentGold,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.0.w),
            Expanded(
              child: InkWell(
                onTap: () {
                  _showAyahPickerDialog(
                    context: context,
                    title: l10n.verseCardEndAyah,
                    currentValue: endAyah,
                    options: endOptions,
                    onSelected: (val) {
                      onEndAyahChanged(val);
                    },
                  );
                },
                borderRadius: BorderRadius.circular(12.0.r),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.0.w,
                    vertical: 10.0.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12.0.r),
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.2),
                      width: 1.w,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          l10n.verseCardToAyah(
                            isEn
                                ? '$endAyah'
                                : VerseCardTextUtils.toArabicDigits(endAyah),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20.0.sp,
                        color: AppColors.accentGold,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
