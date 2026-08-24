import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/verse_card_theme.dart';

/// Full page snapshot card preview.
class VerseCardFullPagePreview extends StatelessWidget {
  final VerseCardTheme theme;
  final bool isCapturingSnapshot;
  final Uint8List? pageSnapshot;
  final VoidCallback onRetryCapture;

  const VerseCardFullPagePreview({
    super.key,
    required this.theme,
    required this.isCapturingSnapshot,
    required this.pageSnapshot,
    required this.onRetryCapture,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('full_page_card_preview'),
      width: MediaQuery.sizeOf(context).width,
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(14.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCapturingSnapshot)
            Container(
              height: 380.h,
              alignment: Alignment.center,
              child: CupertinoActivityIndicator(
                color: theme.accentColor,
                radius: 14.r,
              ),
            )
          else if (pageSnapshot != null)
            Image.memory(
              pageSnapshot!,
              fit: BoxFit.fitWidth,
              width: MediaQuery.sizeOf(context).width,
            )
          else
            Container(
              height: 200.h,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_rounded,
                    color: theme.accentColor.withValues(alpha: 0.6),
                    size: 36.r,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'تعذر التقاط صورة الصفحة',
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 13.sp,
                      color: theme.primaryTextColor,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextButton.icon(
                    onPressed: onRetryCapture,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),

          SizedBox(height: 12.h),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_stories_rounded,
                size: 14.r,
                color: theme.accentColor,
              ),
              SizedBox(width: 6.w),
              Text(
                'تَـبَـتَّـلْ • Tabattal',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: theme.secondaryTextColor.withValues(alpha: 0.85),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
