import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/quran_metadata.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../bloc/hifz/hifz_bloc.dart';
import '../../../bloc/hifz/hifz_event.dart';

class HifzPlanCreationDialog extends StatefulWidget {
  const HifzPlanCreationDialog({super.key});

  @override
  State<HifzPlanCreationDialog> createState() => _HifzPlanCreationDialogState();
}

class _HifzPlanCreationDialogState extends State<HifzPlanCreationDialog> {
  int _selectedSurah = 1;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: 'حفظ سورة ${QuranMetadata.getSurahNameWithTashkeel(1)}',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = AppColors.isDarkMode;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      backgroundColor: AppColors.cardBackground,
      child: Container(
        padding: EdgeInsets.all(20.r),
        constraints: BoxConstraints(maxWidth: 400.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  color: AppColors.accentGold,
                  size: 24.sp,
                ),
                SizedBox(width: 10.w),
                Text(
                  l10n.hifzCreatePlan,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Text(
              'اختر السورة المراد حفظها:',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedSurah,
                  isExpanded: true,
                  dropdownColor: AppColors.cardBackground,
                  items: List.generate(114, (i) {
                    final surahNum = i + 1;
                    return DropdownMenuItem<int>(
                      value: surahNum,
                      child: Text(
                        '$surahNum. سورة ${QuranMetadata.getSurahNameWithTashkeel(surahNum)}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  }),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _selectedSurah = val;
                      _titleController.text =
                          'حفظ سورة ${QuranMetadata.getSurahNameWithTashkeel(val)}';
                    });
                  },
                ),
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'عنوان الخطة',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppColors.accentGold),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                  ),
                ),
              ),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14.sp),
            ),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'إلغاء',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                SizedBox(width: 8.w),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  onPressed: () {
                    final startPage = QuranMetadata.getStartPageForSurah(_selectedSurah);
                    final versesCount = QuranMetadata.getVerseCountForSurah(_selectedSurah);
                    final endPage = startPage + (versesCount / 15).ceil();

                    context.read<HifzBloc>().add(
                          CreateHifzPlanEvent(
                            title: _titleController.text.trim().isEmpty
                                ? 'حفظ سورة ${QuranMetadata.getSurahNameWithTashkeel(_selectedSurah)}'
                                : _titleController.text.trim(),
                            surahNumber: _selectedSurah,
                            startPage: startPage,
                            endPage: endPage,
                            targetVersesCount: versesCount,
                          ),
                        );
                    Navigator.pop(context);
                  },
                  child: const Text('إنشاء الخطة'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
