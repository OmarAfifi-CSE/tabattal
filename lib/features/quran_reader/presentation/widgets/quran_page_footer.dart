import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class QuranPageFooter extends StatelessWidget {
  final String pageNumber;

  const QuranPageFooter({
    super.key,
    required this.pageNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.5), width: 1.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            pageNumber,
            style: AppTextStyles.headerText.copyWith(
              color: AppColors.accentGoldDark,
            ),
          ),
        ),
      ),
    );
  }
}
