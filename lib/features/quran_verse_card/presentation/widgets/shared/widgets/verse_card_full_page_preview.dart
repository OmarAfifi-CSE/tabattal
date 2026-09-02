import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../models/verse_card_theme.dart';

/// Full page snapshot card preview matching VerseCardContentPreview structure.
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
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Container(
      key: const ValueKey('full_page_card_preview'),
      width: screenWidth,
      color: theme.backgroundColor,
      padding: EdgeInsets.all(12.r),
      child: Container(
        width: screenWidth,
        decoration: BoxDecoration(
          color: theme.cardBackground,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: theme.borderColor, width: 1.5),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 14.w,
          vertical: 16.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
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
              ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: Image.memory(
                  pageSnapshot!,
                  fit: BoxFit.fitWidth,
                  width: screenWidth,
                ),
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
                      AppLocalizations.of(context)!.verseCardCapturePageError,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 13.sp,
                        color: theme.primaryTextColor,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextButton.icon(
                      onPressed: onRetryCapture,
                      icon: Icon(Icons.refresh_rounded, size: 16.r),
                      label: Text(AppLocalizations.of(context)!.verseCardRetry),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 14.h),

            // Footer Branding Watermark
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  size: 12.r,
                  color: theme.accentColor,
                ),
                SizedBox(width: 6.w),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: theme.secondaryTextColor.withValues(alpha: 0.85),
                    ),
                    children: const [
                      TextSpan(text: 'تَـبَـتَّـلْ • '),
                      TextSpan(
                        text: 'Tabattal',
                        style: TextStyle(letterSpacing: 0.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
