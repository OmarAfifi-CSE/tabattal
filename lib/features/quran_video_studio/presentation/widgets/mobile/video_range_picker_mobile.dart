import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/quran_metadata.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../quran_verse_card/presentation/widgets/shared/helpers/verse_card_text_utils.dart';

class VideoRangePickerMobile extends StatelessWidget {
  final int surahNumber;
  final int startAyah;
  final int endAyah;
  final ValueChanged<int> onStartAyahChanged;
  final ValueChanged<int> onEndAyahChanged;

  const VideoRangePickerMobile({
    super.key,
    required this.surahNumber,
    required this.startAyah,
    required this.endAyah,
    required this.onStartAyahChanged,
    required this.onEndAyahChanged,
  });

  int get totalAyahsInSurah => QuranMetadata.getVerseCountForSurah(surahNumber);

  int _getMaxEndAyah(int start) {
    // Max 10 ayahs per video segment for optimal video size and performance
    return (start + 9).clamp(1, totalAyahsInSurah);
  }

  void _showAyahPickerSheet({
    required BuildContext context,
    required String title,
    required int currentValue,
    required List<int> options,
    required ValueChanged<int> onSelected,
  }) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardCream,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.65,
            ),
            padding: EdgeInsets.only(
              left: 16.w,
              right: 16.w,
              top: 12.h,
              bottom: MediaQuery.paddingOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const Divider(height: 1),
                SizedBox(height: 8.h),
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      childAspectRatio: 1.4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: options.length,
                    itemBuilder: (ctx, index) {
                      final item = options[index];
                      final isSelected = item == currentValue;
                      return GestureDetector(
                        onTap: () {
                          onSelected(item);
                          Navigator.pop(ctx);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accentGold
                                : AppColors.accentGold.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.accentGold
                                  : AppColors.accentGold.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            isEn ? '$item' : VerseCardTextUtils.toArabicDigits(item),
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
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
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(
                  color: AppColors.accentGold.withValues(alpha: 0.28),
                  width: 1,
                ),
              ),
              child: Text(
                l10n.verseCardSurah(
                  isEn
                      ? QuranMetadata.getSurahNameEnglish(surahNumber)
                      : QuranMetadata.getSurahName(surahNumber),
                ),
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentGold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  _showAyahPickerSheet(
                    context: context,
                    title: l10n.verseCardStartAyah,
                    currentValue: startAyah,
                    options: startOptions,
                    onSelected: (val) {
                      onStartAyahChanged(val);
                    },
                  );
                },
                borderRadius: BorderRadius.circular(12.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.verseCardFromAyah(
                          isEn
                              ? '$startAyah'
                              : VerseCardTextUtils.toArabicDigits(startAyah),
                        ),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18.sp,
                        color: AppColors.accentGold,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: InkWell(
                onTap: () {
                  _showAyahPickerSheet(
                    context: context,
                    title: l10n.verseCardEndAyah,
                    currentValue: endAyah,
                    options: endOptions,
                    onSelected: (val) {
                      onEndAyahChanged(val);
                    },
                  );
                },
                borderRadius: BorderRadius.circular(12.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.verseCardToAyah(
                          isEn
                              ? '$endAyah'
                              : VerseCardTextUtils.toArabicDigits(endAyah),
                        ),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18.sp,
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
