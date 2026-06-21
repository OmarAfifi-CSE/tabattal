import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class QuranPageHeader extends StatelessWidget {
  final String juzNumber;
  final String surahName;

  const QuranPageHeader({
    super.key,
    required this.juzNumber,
    required this.surahName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Juz
          Text(
            'الجزء $juzNumber',
            style: AppTextStyles.headerText,
          ),
          // Surah
          Text(
            'سورة $surahName',
            style: AppTextStyles.headerText.copyWith(
              color: AppColors.accentGold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
