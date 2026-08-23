import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

class VideoReciterSelector extends StatefulWidget {
  final String selectedReciter;
  final String? selectedCategory;
  final void Function(String name, String category, String path) onReciterSelected;

  const VideoReciterSelector({
    super.key,
    required this.selectedReciter,
    this.selectedCategory,
    required this.onReciterSelected,
  });

  /// Reciters with 100% verified millisecond-accurate word timing data from Quran.com API
  static const Map<String, List<Map<String, String>>> verifiedRecitersByCategory = {
    'مرتل': [
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
        'name': 'أبو بكر الشاطري',
        'category': 'مرتل',
        'path': 'Abu_Bakr_Ash-Shaatree_128kbps',
      },
      {
        'name': 'سعود الشريم',
        'category': 'مرتل',
        'path': 'Saood_ash-Shuraym_128kbps',
      },
    ],
    'مجود': [
      {
        'name': 'محمد صديق المنشاوي',
        'category': 'مجود',
        'path': 'Minshawy_Mujawwad_192kbps',
      },
      {
        'name': 'عبد الباسط عبد الصمد',
        'category': 'مجود',
        'path': 'Abdul_Basit_Mujawwad_128kbps',
      },
    ],
  };

  @override
  State<VideoReciterSelector> createState() => _VideoReciterSelectorState();
}

class _VideoReciterSelectorState extends State<VideoReciterSelector> {
  late String _activeCategory;

  @override
  void initState() {
    super.initState();
    _activeCategory = widget.selectedCategory ?? 'مرتل';
  }

  @override
  void didUpdateWidget(covariant VideoReciterSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCategory != null) {
      _activeCategory = widget.selectedCategory!;
    }
  }

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
          child: DefaultTabController(
            initialIndex: VideoReciterSelector.verifiedRecitersByCategory.keys
                .toList()
                .indexOf(_activeCategory)
                .clamp(0, VideoReciterSelector.verifiedRecitersByCategory.keys.length - 1),
            length: VideoReciterSelector.verifiedRecitersByCategory.keys.length,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
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
                      Row(
                        children: [
                          Icon(Icons.verified_rounded, color: AppColors.accentGold, size: 20.sp),
                          SizedBox(width: 8.w),
                          Text(
                            l10n.videoStudioChooseReciter,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  TabBar(
                    labelColor: AppColors.accentGold,
                    unselectedLabelColor: AppColors.textPrimary.withValues(alpha: 0.6),
                    indicatorColor: AppColors.accentGold,
                    labelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
                    tabs: VideoReciterSelector.verifiedRecitersByCategory.keys
                        .map((cat) => Tab(text: cat))
                        .toList(),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: VideoReciterSelector.verifiedRecitersByCategory.entries.map((entry) {
                        final cat = entry.key;
                        final reciters = entry.value;

                        return ListView.separated(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          physics: const BouncingScrollPhysics(),
                          itemCount: reciters.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (subCtx, idx) {
                            final item = reciters[idx];
                            final isSelected = item['name'] == widget.selectedReciter && _activeCategory == cat;

                            return ListTile(
                              leading: Icon(
                                Icons.record_voice_over_rounded,
                                color: isSelected ? AppColors.accentGold : AppColors.textPrimary.withValues(alpha: 0.5),
                                size: 20.sp,
                              ),
                              title: Text(
                                item['name']!,
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
                                setState(() {
                                  _activeCategory = cat;
                                });
                                widget.onReciterSelected(item['name']!, cat, item['path']!);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentReciters = VideoReciterSelector.verifiedRecitersByCategory[_activeCategory] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header & View All button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  l10n.videoStudioReciter,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(width: 6.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 11.sp, color: AppColors.accentGold),
                      SizedBox(width: 3.w),
                      Text(
                        'توقيت دقيق',
                        style: TextStyle(
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
        SizedBox(height: 8.h),

        // 2. Category Selector Chips (مرتل / مجود / المصحف المعلم)
        SizedBox(
          height: 32.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: VideoReciterSelector.verifiedRecitersByCategory.keys.length,
            separatorBuilder: (_, _) => SizedBox(width: 8.w),
            itemBuilder: (context, index) {
              final cat = VideoReciterSelector.verifiedRecitersByCategory.keys.elementAt(index);
              final isCatSelected = cat == _activeCategory;

              return InkWell(
                onTap: () {
                  setState(() {
                    _activeCategory = cat;
                  });
                  final reciters = VideoReciterSelector.verifiedRecitersByCategory[cat]!;
                  final matchingInCat = reciters.where((r) => r['name'] == widget.selectedReciter).firstOrNull;
                  if (matchingInCat != null) {
                    widget.onReciterSelected(matchingInCat['name']!, cat, matchingInCat['path']!);
                  } else if (reciters.isNotEmpty) {
                    final first = reciters.first;
                    widget.onReciterSelected(first['name']!, cat, first['path']!);
                  }
                },
                borderRadius: BorderRadius.circular(16.r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: isCatSelected
                        ? AppColors.accentGold
                        : AppColors.accentGold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: isCatSelected
                          ? AppColors.accentGold
                          : AppColors.accentGold.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: isCatSelected ? FontWeight.bold : FontWeight.w500,
                        color: isCatSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 8.h),

        // 3. Reciters List for the active category
        SizedBox(
          height: 38.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: currentReciters.length,
            separatorBuilder: (_, _) => SizedBox(width: 8.w),
            itemBuilder: (context, index) {
              final reciter = currentReciters[index];
              final isSelected = reciter['name'] == widget.selectedReciter;

              return InkWell(
                onTap: () {
                  widget.onReciterSelected(
                    reciter['name']!,
                    _activeCategory,
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
