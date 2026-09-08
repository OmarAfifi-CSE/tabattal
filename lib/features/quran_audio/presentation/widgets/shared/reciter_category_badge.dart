import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/reciter_localization.dart';

/// A compact visual badge displaying the current recitation category (e.g. "مرتل" / "Murattal").
class ReciterCategoryBadge extends StatelessWidget {
  final String category;

  const ReciterCategoryBadge({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final categoryName = ReciterLocalization.localize(context, category);

    return Tooltip(
      message: categoryName,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: AppColors.accentGold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(
            color: AppColors.accentGold.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Text(
          categoryName,
          style: TextStyle(
            fontSize: 9.5.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.accentGold,
          ),
        ),
      ),
    );
  }
}
