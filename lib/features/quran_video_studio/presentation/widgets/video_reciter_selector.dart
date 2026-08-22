import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/reciter_catalog.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

class VideoReciterSelector extends StatelessWidget {
  final String selectedReciter;
  final void Function(String name, String category, String path) onReciterSelected;

  const VideoReciterSelector({
    super.key,
    required this.selectedReciter,
    required this.onReciterSelected,
  });

  static const List<Map<String, String>> featuredReciters = [
    {
      'name': 'محمد صديق المنشاوي',
      'category': 'مرتل',
      'path': 'Minshawy_Murattal_128kbps',
    },
    {
      'name': 'محمود خليل الحصري',
      'category': 'مرتل',
      'path': 'Husary_128kbps',
    },
    {
      'name': 'عبد الباسط عبد الصمد',
      'category': 'مرتل',
      'path': 'Abdul_Basit_Murattal_192kbps',
    },
    {
      'name': 'مشاري العفاسي',
      'category': 'مرتل',
      'path': 'Alafasy_128kbps',
    },
    {
      'name': 'ماهر المعيقلي',
      'category': 'مرتل',
      'path': 'MaherAlMuaiqly128kbps',
    },
    {
      'name': 'ياسر الدوسري',
      'category': 'مرتل',
      'path': 'Yasser_Ad-Dussary_128kbps',
    },
    {
      'name': 'سعد الغامدي',
      'category': 'مرتل',
      'path': 'Ghamadi_40kbps',
    },
    {
      'name': 'علي الحذيفي',
      'category': 'مرتل',
      'path': 'Hudhaify_128kbps',
    },
  ];

  void _showAllRecitersSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardCream,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
            ),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.videoStudioChooseReciter,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    physics: const BouncingScrollPhysics(),
                    itemCount: ReciterCatalog.reciterCategories['مرتل']?.length ?? 0,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final entries = ReciterCatalog.reciterCategories['مرتل']!.entries.toList();
                      final item = entries[idx];
                      final isSelected = item.key == selectedReciter;

                      return ListTile(
                        title: Text(
                          item.key,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppColors.accentGold : AppColors.textPrimary,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: AppColors.accentGold)
                            : null,
                        onTap: () {
                          onReciterSelected(item.key, 'مرتل', item.value);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.videoStudioReciter,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            InkWell(
              onTap: () => _showAllRecitersSheet(context),
              borderRadius: BorderRadius.circular(8.r),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                child: Text(
                  l10n.videoStudioViewAll,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentGold,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        SizedBox(
          height: 38.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: featuredReciters.length,
            separatorBuilder: (_, _) => SizedBox(width: 8.w),
            itemBuilder: (context, index) {
              final reciter = featuredReciters[index];
              final isSelected = reciter['name'] == selectedReciter;

              return InkWell(
                onTap: () {
                  onReciterSelected(
                    reciter['name']!,
                    reciter['category']!,
                    reciter['path']!,
                  );
                },
                borderRadius: BorderRadius.circular(20.r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentGold.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentGold
                          : AppColors.accentGold.withValues(alpha: 0.25),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.record_voice_over_rounded,
                        size: 13.sp,
                        color: isSelected ? AppColors.accentGold : AppColors.textPrimary.withValues(alpha: 0.6),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        reciter['name']!,
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.accentGold : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
