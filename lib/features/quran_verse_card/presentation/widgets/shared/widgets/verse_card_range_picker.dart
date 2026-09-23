import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../core/constants/quran_metadata.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../helpers/verse_card_text_utils.dart';

/// Verse range picker with from/to selector buttons and bottom sheet picker modal.
class VerseCardRangePicker extends StatelessWidget {
  final int? surahNumber;
  final int startAyah;
  final int endAyah;
  final int totalAyahsInSurah;
  final ValueChanged<int> onStartAyahChanged;
  final ValueChanged<int> onEndAyahChanged;

  const VerseCardRangePicker({
    super.key,
    this.surahNumber,
    required this.startAyah,
    required this.endAyah,
    required this.totalAyahsInSurah,
    required this.onStartAyahChanged,
    required this.onEndAyahChanged,
  });

  int _getMaxEndAyah(int start) {
    return (start + 24).clamp(1, totalAyahsInSurah);
  }

  void _showAyahPickerSheet({
    required BuildContext context,
    required String title,
    required int currentValue,
    required List<int> options,
    required ValueChanged<int> onSelected,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final isDesktopOrTablet = MediaQuery.sizeOf(context).width > 600;

    Widget buildContent(BuildContext ctx, {required bool isDialog}) {
      return Directionality(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: isDialog ? 480.h : MediaQuery.sizeOf(ctx).height * 0.65,
            maxWidth: isDialog ? 420.w : MediaQuery.sizeOf(ctx).width,
          ),
          padding: EdgeInsets.only(
            left: isDialog ? 22.w : 16.w,
            right: isDialog ? 22.w : 16.w,
            top: isDialog ? 22.h : 12.h,
            bottom: isDialog ? 22.h : MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isDialog)
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
                    splashRadius: 20,
                  ),
                ],
              ),
              const Divider(height: 1),
              SizedBox(height: 8.h),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
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
                              : AppColors.surfaceCream,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accentGold
                                : AppColors.divider,
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.accentGold.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          l10n.verseCardAyah(
                            !isAr
                                ? '$item'
                                : VerseCardTextUtils.toArabicDigits(item),
                          ),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
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
      );
    }

    if (isDesktopOrTablet) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: AppColors.cardCream,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: buildContent(ctx, isDialog: true),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardCream,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => buildContent(ctx, isDialog: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final langCode = Localizations.localeOf(context).languageCode;
    final isAr = langCode == 'ar';

    final startOptions = List.generate(totalAyahsInSurah, (i) => i + 1);
    final maxEndForCurrentStart = _getMaxEndAyah(startAyah);
    final endOptions = List.generate(
      maxEndForCurrentStart - startAyah + 1,
      (i) => startAyah + i,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header with Surah Badge
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.verseCardVerseRange,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (surahNumber != null) ...[
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
                    QuranMetadata.getSurahNameForLocale(langCode, surahNumber!),
                  ),
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentGold,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 6.h),

        // 2. From Ayah / To Ayah Selectors
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _showAyahPickerSheet(
                  context: context,
                  title: l10n.verseCardStartAyah,
                  currentValue: startAyah,
                  options: startOptions,
                  onSelected: onStartAyahChanged,
                ),
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
                          !isAr
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
                        color: AppColors.accentGold,
                        size: 20.sp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: InkWell(
                onTap: () => _showAyahPickerSheet(
                  context: context,
                  title: l10n.verseCardEndAyah,
                  currentValue: endAyah,
                  options: endOptions,
                  onSelected: onEndAyahChanged,
                ),
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
                          !isAr
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
                        color: AppColors.accentGold,
                        size: 20.sp,
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
