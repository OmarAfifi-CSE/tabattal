import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class MixedDirectionText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const MixedDirectionText({
    super.key,
    required this.text,
    this.style,
  });

  bool _isRtl(String text) {
    final RegExp arabicRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    final RegExp englishRegex = RegExp(r'[a-zA-Z]');
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (arabicRegex.hasMatch(char)) return true;
      if (englishRegex.hasMatch(char)) return false;
    }
    return true; // Default to RTL
  }

  @override
  Widget build(BuildContext context) {
    // Split text by newlines into paragraphs
    final paragraphs = text.split(RegExp(r'\n+'));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: paragraphs.map((p) {
        final trimmed = p.trim();
        if (trimmed.isEmpty) return const SizedBox.shrink();
        
        final isRtl = _isRtl(trimmed);
        return Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Text(
            trimmed,
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            style: style ?? AppTextStyles.menuItemText.copyWith(
              height: 1.8.h,
              color: AppColors.textPrimary,
            ),
          ),
        );
      }).toList(),
    );
  }
}
