import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';

/// A luxury, informative notice banner displayed when an untimed reciter
/// is selected. Clarifies that the recitation plays the full surah audio
/// without synchronized verse-by-verse highlighting.
class ListeningOnlyNoticeBanner extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  final bool compact;

  const ListeningOnlyNoticeBanner({
    super.key,
    this.margin,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    final titleText = isEn
        ? 'Recitation without Verse Tracking'
        : 'تلاوة بدون تتبع للآيات';

    final descriptionText = isEn
        ? 'These recordings feature full surah recitations without synchronized verse tracking.'
        : 'تعمل هذه التسجيلات بالتلاوة الكاملة للسور ولكن بدون تتبع أو تظليل متزامن للآيات أثناء القراءة.';

    return Container(
      margin: margin ?? EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      padding: EdgeInsets.symmetric(
        horizontal: 12.w,
        vertical: compact ? 8.h : 10.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.accentGold.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 6.r : 8.r),
            decoration: BoxDecoration(
              color: AppColors.accentGold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.headphones_rounded,
              color: AppColors.accentGold,
              size: compact ? 16.sp : 18.sp,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titleText,
                  style: TextStyle(
                    fontSize: compact ? 12.sp : 13.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  descriptionText,
                  style: TextStyle(
                    fontSize: compact ? 10.5.sp : 11.5.sp,
                    color: AppColors.textSecondary,
                    height: 1.35,
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
