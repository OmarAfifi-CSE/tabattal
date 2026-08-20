import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../l10n/app_localizations.dart';

/// Verse range picker with from/to selector buttons and bottom sheet picker modal.
class VerseCardRangePicker extends StatelessWidget {
  final int startAyah;
  final int endAyah;
  final int totalAyahsInSurah;
  final ValueChanged<int> onStartAyahChanged;
  final ValueChanged<int> onEndAyahChanged;

  const VerseCardRangePicker({
    super.key,
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
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    const isWeb = kIsWeb;

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
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
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
                        fontSize: isWeb ? 17 : 16.sp,
                        fontWeight: FontWeight.bold,
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
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            isEn ? 'Ayah $item' : 'آية $item',
                            style: TextStyle(
                              fontSize: isWeb ? 13 : 12.sp,
                              fontWeight: FontWeight.bold,
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    const isWeb = kIsWeb;

    final maxEndForCurrentStart = _getMaxEndAyah(startAyah);
    final availableEndAyahs = List.generate(
      maxEndForCurrentStart - startAyah + 1,
      (i) => startAyah + i,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.verseCardVerseRange,
            style: TextStyle(
              fontSize: isWeb ? 14 : 13.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Row(
            children: [
              // From Ayah Tile
              GestureDetector(
                onTap: () => _showAyahPickerSheet(
                  context: context,
                  title: l10n.verseCardStartAyah,
                  currentValue: startAyah,
                  options: List.generate(totalAyahsInSurah, (i) => i + 1),
                  onSelected: onStartAyahChanged,
                ),
                child: Container(
                  height: 34.h,
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  decoration: BoxDecoration(
                    color: AppColors.cardCream,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentGold.withValues(alpha: 0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isEn ? 'Ayah $startAyah' : 'آية $startAyah',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 18.r,
                        color: AppColors.accentGold,
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.w),
                child: Text(
                  '—',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentGold,
                  ),
                ),
              ),

              // To Ayah Tile
              GestureDetector(
                onTap: () => _showAyahPickerSheet(
                  context: context,
                  title: l10n.verseCardEndAyah,
                  currentValue: endAyah,
                  options: availableEndAyahs,
                  onSelected: onEndAyahChanged,
                ),
                child: Container(
                  height: 34.h,
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  decoration: BoxDecoration(
                    color: AppColors.cardCream,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentGold.withValues(alpha: 0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isEn ? 'Ayah $endAyah' : 'آية $endAyah',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 18.r,
                        color: AppColors.accentGold,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
