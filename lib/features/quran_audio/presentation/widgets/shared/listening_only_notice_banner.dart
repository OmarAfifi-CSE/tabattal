import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/reciter_catalog.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/reciter_localization.dart';

/// A luxury, informative notice banner displayed when an untimed reciter
/// is selected. Clarifies that the recitation plays the full surah audio
/// without synchronized verse-by-verse highlighting, specific to the chosen reciter or surah.
class ListeningOnlyNoticeBanner extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  final bool compact;
  final String? reciterName;
  final String? reciterPath;
  final int? surahNumber;

  const ListeningOnlyNoticeBanner({
    super.key,
    this.margin,
    this.compact = false,
    this.reciterName,
    this.reciterPath,
    this.surahNumber,
  });

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final isAr = langCode == 'ar';
    final isId = langCode == 'id';

    final String titleText;
    final String descriptionText;

    final isSpecificSurah = reciterPath != null &&
        surahNumber != null &&
        (ReciterCatalog.surahSpecificUntimedReciterPaths[reciterPath]?.contains(surahNumber) ?? false);

    if (reciterName != null && reciterName!.isNotEmpty) {
      final displayName =
          ReciterLocalization.localize(context, reciterName!);

      if (isSpecificSurah) {
        titleText = isAr
            ? 'تلاوة استماع (لهذه السورة)'
            : (isId
                ? 'Mode Hanya Mendengarkan (Surah ini)'
                : 'Listening-Only Mode (This surah)');
        descriptionText = isAr
            ? 'التتبع اللحظي غير متاح لهذه السورة مع ($displayName) لعدم توفر توقيتات في هذا التسجيل، ويمكنك اختيار قارئ آخر لتفعيل التتبع المتزامن.'
            : (isId
                ? 'Pelacakan ayat tersinkronisasi tidak tersedia untuk surah ini dengan ($displayName) karena tidak ada data waktu dalam rekaman ini. Anda dapat memilih qari lain untuk pelacakan tersinkronisasi.'
                : 'Synchronized tracking is unavailable for this surah with ($displayName) due to missing timing data in this recording. You can choose another reciter for synchronized tracking.');
      } else {
        titleText = isAr
            ? 'تلاوة استماع (خاصة بهذا القارئ)'
            : (isId
                ? 'Mode Hanya Mendengarkan (Qari ini)'
                : 'Listening-Only Mode (This reciter)');
        descriptionText = isAr
            ? 'تسجيلات ($displayName) تعمل بالتلاوة الكاملة دون تتبع متزامن للآيات، ويمكنك اختيار قارئ آخر في أي وقت لتفعيل التتبع والتظليل المتزامن.'
            : (isId
                ? 'Rekaman untuk ($displayName) memutar audio surah penuh tanpa pelacakan ayat tersinkronisasi. Anda dapat memilih qari lain kapan saja untuk pelacakan tersinkronisasi.'
                : 'Recordings for ($displayName) feature full surah audio without synchronized verse tracking. You can choose another reciter at any time for synchronized tracking.');
      }
    } else {
      titleText = isAr
          ? 'قراء بنمط الاستماع (بدون تتبع للآيات)'
          : (isId
              ? 'Qari Mode Hanya Mendengarkan'
              : 'Listening-Only Reciters');
      descriptionText = isAr
          ? 'تسجيلات هؤلاء القراء تعمل بالتلاوة الكاملة دون تتبع متزامن للآيات، ويمكنك اختيار قارئ من الفئات الأخرى لتفعيل التتبع والتظليل المتزامن.'
          : (isId
              ? 'Rekaman untuk qari ini memutar audio surah penuh tanpa pelacakan ayat tersinkronisasi. Anda dapat memilih qari dari kategori lain untuk mengaktifkan pelacakan tersinkronisasi.'
              : 'Recordings for these reciters feature full surah audio without synchronized verse tracking. You can choose a reciter from other categories to enable synchronized tracking.');
    }

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
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  descriptionText,
                  style: TextStyle(
                    fontSize: compact ? 10.5.sp : 11.5.sp,
                    color: AppColors.textSecondary,
                    height: 1.55,
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
