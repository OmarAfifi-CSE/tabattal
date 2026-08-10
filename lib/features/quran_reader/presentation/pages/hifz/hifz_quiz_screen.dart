import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/quran_metadata.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';

class HifzQuizScreen extends StatefulWidget {
  final int surahNumber;
  const HifzQuizScreen({super.key, required this.surahNumber});

  @override
  State<HifzQuizScreen> createState() => _HifzQuizScreenState();
}

class _HifzQuizScreenState extends State<HifzQuizScreen> {
  int _currentQuestionIndex = 0;
  bool _isAnswerRevealed = false;
  int _correctCount = 0;
  int _reviewCount = 0;

  late final int _totalVerses;

  @override
  void initState() {
    super.initState();
    _totalVerses = QuranMetadata.getVerseCountForSurah(widget.surahNumber);
  }

  void _nextQuestion(bool correct) {
    setState(() {
      if (correct) {
        _correctCount++;
      } else {
        _reviewCount++;
      }
      _isAnswerRevealed = false;
      if (_currentQuestionIndex < _totalVerses - 1) {
        _currentQuestionIndex++;
      } else {
        _showResultsDialog();
      }
    });
  }

  void _showResultsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          'نتيجة الاختبار 🎉',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'سورة ${QuranMetadata.getSurahNameWithTashkeel(widget.surahNumber)}',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '$_correctCount',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      'متقن 👍',
                      style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '$_reviewCount',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentGold,
                      ),
                    ),
                    Text(
                      'يحتاج مراجعة 🔁',
                      style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit quiz
            },
            child: const Text('إنهاء الاختبار'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentAyah = _currentQuestionIndex + 1;
    final surahName = QuranMetadata.getSurahNameWithTashkeel(widget.surahNumber);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '${l10n.hifzQuizTitle} • سورة $surahName',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: Padding(
        padding: EdgeInsets.all(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الآية $currentAyah من $_totalVerses',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${((_currentQuestionIndex + 1) / _totalVerses * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.accentGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(6.r),
              child: LinearProgressIndicator(
                value: (_currentQuestionIndex + 1) / _totalVerses,
                backgroundColor: AppColors.accentGold.withValues(alpha: 0.15),
                color: AppColors.accentGold,
                minHeight: 6.h,
              ),
            ),
            SizedBox(height: 30.h),

            // Quiz Card
            Expanded(
              child: Container(
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: AppColors.accentGold.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'اختبار تذكر الآية رقم ($currentAyah):',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 20.h),

                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 300),
                      crossFadeState: _isAnswerRevealed
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: Container(
                        padding: EdgeInsets.all(24.r),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: AppColors.accentGold.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.visibility_off_rounded,
                              size: 40.sp,
                              color: AppColors.accentGold,
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              'اقرأ الآية ($currentAyah) من سورة $surahName بصوتك ثم اضغط لكشف النص للتحقق.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppColors.textPrimary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      secondChild: Container(
                        padding: EdgeInsets.all(24.r),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '﴿ سورة $surahName — الآية $currentAyah ﴾\n\nتم الاستظهار بنجاح! قارن تلاوتك الآن.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 30.h),

                    if (!_isAnswerRevealed)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentGold,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24.w,
                            vertical: 12.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        onPressed: () {
                          setState(() => _isAnswerRevealed = true);
                        },
                        icon: const Icon(Icons.remove_red_eye_rounded),
                        label: const Text('كشف النص والتحقق'),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // Controls
            if (_isAnswerRevealed)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      onPressed: () => _nextQuestion(true),
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('حفظ ممتاز (متقن)'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.accentGold),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      onPressed: () => _nextQuestion(false),
                      icon: Icon(Icons.sync_rounded, color: AppColors.accentGold),
                      label: Text(
                        'يحتاج مراجعة',
                        style: TextStyle(color: AppColors.accentGold),
                      ),
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
