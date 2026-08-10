import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/quran_metadata.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../bloc/hifz/hifz_bloc.dart';
import '../../../bloc/hifz/hifz_event.dart';
import '../../../bloc/hifz/hifz_state.dart';
import '../../widgets/hifz/hifz_plan_creation_dialog.dart';
import 'hifz_quiz_screen.dart';

class HifzDashboardScreen extends StatelessWidget {
  final void Function(int page, {String? verseKey})? onNavigateToPage;

  const HifzDashboardScreen({super.key, this.onNavigateToPage});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = AppColors.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l10n.hifzDashboardTitle,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accentGold,
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const HifzPlanCreationDialog(),
          );
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          l10n.hifzCreatePlan,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 14.sp,
          ),
        ),
      ),
      body: BlocBuilder<HifzBloc, HifzState>(
        builder: (context, state) {
          if (state.isLoading) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Streak & Summary Card ---
                Container(
                  padding: EdgeInsets.all(18.r),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentGold.withValues(alpha: 0.85),
                        AppColors.accentGold,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentGold.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.local_fire_department_rounded,
                          color: Colors.white,
                          size: 32.sp,
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l10n.hifzStreak} 🔥',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'مستمر للحفظ اليومي!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // --- Section Header ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'خطط الحفظ الحالية',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${state.plans.length} خطط',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                if (state.plans.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(24.r),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          size: 48.sp,
                          color: AppColors.accentGold.withValues(alpha: 0.5),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          l10n.hifzNoPlans,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.plans.length,
                    separatorBuilder: (_, _) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final plan = state.plans[index];
                      final surahName =
                          QuranMetadata.getSurahNameWithTashkeel(plan.surahNumber);

                      return Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: AppColors.accentGold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8.r),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentGold
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10.r),
                                      ),
                                      child: Text(
                                        '${plan.surahNumber}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.accentGold,
                                          fontSize: 14.sp,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          plan.title,
                                          style: TextStyle(
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(
                                          'سورة $surahName • ص ${plan.startPage}',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () {
                                    context
                                        .read<HifzBloc>()
                                        .add(DeleteHifzPlanEvent(plan.id));
                                  },
                                ),
                              ],
                            ),
                            SizedBox(height: 14.h),

                            // --- Progress Bar ---
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6.r),
                              child: LinearProgressIndicator(
                                value: plan.progressPercentage,
                                backgroundColor: isDark
                                    ? Colors.white12
                                    : Colors.black.withValues(alpha: 0.06),
                                color: AppColors.accentGold,
                                minHeight: 6.h,
                              ),
                            ),
                            SizedBox(height: 14.h),

                            // --- Actions Row ---
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color: AppColors.accentGold),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10.r),
                                      ),
                                    ),
                                    onPressed: () {
                                      context.read<HifzBloc>().add(
                                            const ToggleHifzMode(enabled: true),
                                          );
                                      Navigator.pop(context);
                                      onNavigateToPage?.call(plan.startPage);
                                    },
                                    icon: Icon(
                                      Icons.visibility_off_rounded,
                                      size: 16.sp,
                                      color: AppColors.accentGold,
                                    ),
                                    label: Text(
                                      'ابدأ الحفظ والتسميع',
                                      style: TextStyle(
                                        color: AppColors.accentGold,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentGold,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => HifzQuizScreen(
                                          surahNumber: plan.surahNumber,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: Icon(Icons.quiz_rounded, size: 16.sp),
                                  label: Text(
                                    'اختبار الحفظ',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
