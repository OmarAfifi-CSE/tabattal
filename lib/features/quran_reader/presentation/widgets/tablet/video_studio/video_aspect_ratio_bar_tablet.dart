import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../quran_video_studio/domain/entities/video_enums.dart';

class VideoAspectRatioBarTablet extends StatelessWidget {
  final VideoAspectRatio selectedRatio;
  final ValueChanged<VideoAspectRatio> onRatioSelected;

  const VideoAspectRatioBarTablet({
    super.key,
    required this.selectedRatio,
    required this.onRatioSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18.0),
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
            borderRadius: BorderRadius.circular(14.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accentGold : Colors.transparent,
                borderRadius: BorderRadius.circular(14.0),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.accentGold.withValues(alpha: 0.35),
                          blurRadius: 5,
                          offset: const Offset(0, 1.5),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getIconForRatio(ratio),
                    size: 12.0,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    ratio.shortLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
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
