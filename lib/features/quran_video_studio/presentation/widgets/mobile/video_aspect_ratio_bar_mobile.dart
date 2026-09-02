import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/video_enums.dart';

class VideoAspectRatioBarMobile extends StatelessWidget {
  final VideoAspectRatio selectedRatio;
  final ValueChanged<VideoAspectRatio> onRatioSelected;

  const VideoAspectRatioBarMobile({
    super.key,
    required this.selectedRatio,
    required this.onRatioSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: AppColors.accentGold.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: VideoAspectRatio.values.map((ratio) {
          final isSelected = ratio == selectedRatio;
          return InkWell(
            onTap: () => onRatioSelected(ratio),
            borderRadius: BorderRadius.circular(20.r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accentGold : Colors.transparent,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.accentGold.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getIconForRatio(ratio),
                    size: 14.sp,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    ratio.shortLabel,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getIconForRatio(VideoAspectRatio ratio) {
    switch (ratio) {
      case VideoAspectRatio.portrait9x16:
        return Icons.crop_portrait_rounded;
      case VideoAspectRatio.square1x1:
        return Icons.crop_square_rounded;
      case VideoAspectRatio.landscape16x9:
        return Icons.crop_landscape_rounded;
    }
  }
}
