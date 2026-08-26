import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/reciter_catalog.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';

class VideoReciterSelectorTablet extends StatefulWidget {
  final String selectedReciter;
  final String? selectedCategory;
  final void Function(String name, String category, String path)
      onReciterSelected;

  const VideoReciterSelectorTablet({
    super.key,
    required this.selectedReciter,
    this.selectedCategory,
    required this.onReciterSelected,
  });

  @override
  State<VideoReciterSelectorTablet> createState() =>
      _VideoReciterSelectorTabletState();
}

class _VideoReciterSelectorTabletState
    extends State<VideoReciterSelectorTablet> {
  late String _activeCategory;

  @override
  void initState() {
    super.initState();
    _activeCategory = widget.selectedCategory ?? 'مرتل';
  }

  @override
  void didUpdateWidget(covariant VideoReciterSelectorTablet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCategory != null) {
      _activeCategory = widget.selectedCategory!;
    }
  }

  void _showAllRecitersSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppColors.cardCream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0.r),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 500.w, maxHeight: 520.h),
            child: Directionality(
              textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
              child: DefaultTabController(
                initialIndex: ReciterCatalog
                    .verifiedVideoRecitersByCategory.keys
                    .toList()
                    .indexOf(_activeCategory)
                    .clamp(
                        0,
                        ReciterCatalog
                                .verifiedVideoRecitersByCategory.keys.length -
                            1),
                length: ReciterCatalog
                    .verifiedVideoRecitersByCategory.keys.length,
                child: Padding(
                  padding: EdgeInsets.all(16.0.r),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified_rounded,
                                  color: AppColors.accentGold, size: 20.0.sp),
                              SizedBox(width: 8.0.w),
                              Text(
                                l10n.videoStudioChooseReciter,
                                style: TextStyle(
                                  fontSize: 15.0.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: Icon(Icons.close_rounded, size: 22.sp),
                          ),
                        ],
                      ),
                      TabBar(
                        labelColor: AppColors.accentGold,
                        unselectedLabelColor:
                            AppColors.textPrimary.withValues(alpha: 0.6),
                        indicatorColor: AppColors.accentGold,
                        labelStyle: TextStyle(
                            fontSize: 12.0.sp, fontWeight: FontWeight.bold),
                        tabs: ReciterCatalog
                            .verifiedVideoRecitersByCategory.keys
                            .map((cat) => Tab(
                                text: isEn
                                    ? ReciterCatalog.getCategoryNameEnglish(cat)
                                    : cat))
                            .toList(),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: ReciterCatalog
                              .verifiedVideoRecitersByCategory.entries
                              .map((entry) {
                            final cat = entry.key;
                            final reciters = entry.value;

                            return ListView.separated(
                              padding:
                                  EdgeInsets.symmetric(vertical: 8.0.h),
                              physics: const BouncingScrollPhysics(),
                              itemCount: reciters.length,
                              separatorBuilder: (_, _) =>
                                  Divider(height: 1.h),
                              itemBuilder: (subCtx, idx) {
                                final item = reciters[idx];
                                final isSelected =
                                    item['name'] == widget.selectedReciter &&
                                        _activeCategory == cat;
                                final reciterDisplayName = isEn
                                    ? ReciterCatalog.getReciterNameEnglish(
                                        item['name']!)
                                    : item['name']!;

                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.record_voice_over_rounded,
                                    color: isSelected
                                        ? AppColors.accentGold
                                        : AppColors.textPrimary
                                            .withValues(alpha: 0.5),
                                    size: 18.0.sp,
                                  ),
                                  title: Text(
                                    reciterDisplayName,
                                    style: TextStyle(
                                      fontSize: 13.0.sp,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? AppColors.accentGold
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? Icon(Icons.check_circle_rounded,
                                          color: AppColors.accentGold, size: 20.sp)
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _activeCategory = cat;
                                    });
                                    widget.onReciterSelected(
                                        item['name']!, cat, item['path']!);
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
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentReciters =
        ReciterCatalog.verifiedVideoRecitersByCategory[_activeCategory] ?? [];

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
                    fontSize: 16.0.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => _showAllRecitersSheet(context),
              borderRadius: BorderRadius.circular(8.0.r),
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 6.0.w, vertical: 3.0.h),
                child: Text(
                  l10n.videoStudioViewAll,
                  style: TextStyle(
                    fontSize: 14.0.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentGold,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.0.h),

        // 2. Category Selector Chips (مرتل / مجود / المصحف المعلم)
        SizedBox(
          height: 38.0.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount:
                ReciterCatalog.verifiedVideoRecitersByCategory.keys.length,
            separatorBuilder: (_, _) => SizedBox(width: 8.0.w),
            itemBuilder: (context, index) {
              final cat = ReciterCatalog.verifiedVideoRecitersByCategory.keys
                  .elementAt(index);
              final isCatSelected = cat == _activeCategory;
              final isEn = Localizations.localeOf(context).languageCode == 'en';

              return InkWell(
                onTap: () {
                  setState(() {
                    _activeCategory = cat;
                  });
                  final reciters =
                      ReciterCatalog.verifiedVideoRecitersByCategory[cat]!;
                  final matchingInCat = reciters
                      .where((r) => r['name'] == widget.selectedReciter)
                      .firstOrNull;
                  if (matchingInCat != null) {
                    widget.onReciterSelected(matchingInCat['name']!, cat,
                        matchingInCat['path']!);
                  } else if (reciters.isNotEmpty) {
                    final first = reciters.first;
                    widget.onReciterSelected(
                        first['name']!, cat, first['path']!);
                  }
                },
                borderRadius: BorderRadius.circular(16.0.r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.0.w,
                    vertical: 6.0.h,
                  ),
                  decoration: BoxDecoration(
                    color: isCatSelected
                        ? AppColors.accentGold
                        : AppColors.accentGold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16.0.r),
                    border: Border.all(
                      color: isCatSelected
                          ? AppColors.accentGold
                          : AppColors.accentGold.withValues(alpha: 0.25),
                      width: 1.w,
                    ),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isEn ? ReciterCatalog.getCategoryNameEnglish(cat) : cat,
                        style: TextStyle(
                          fontSize: 13.5.sp,
                          fontWeight: isCatSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isCatSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 8.0.h),

        // 3. Reciters List for the active category
        SizedBox(
          height: 44.0.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: currentReciters.length,
            separatorBuilder: (_, _) => SizedBox(width: 8.0.w),
            itemBuilder: (context, index) {
              final reciter = currentReciters[index];
              final isSelected = reciter['name'] == widget.selectedReciter;
              final isEn = Localizations.localeOf(context).languageCode == 'en';
              final reciterDisplayName = isEn
                  ? ReciterCatalog.getReciterNameEnglish(reciter['name']!)
                  : reciter['name']!;

              return InkWell(
                onTap: () {
                  widget.onReciterSelected(
                    reciter['name']!,
                    _activeCategory,
                    reciter['path']!,
                  );
                },
                borderRadius: BorderRadius.circular(16.0.r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.0.w,
                    vertical: 6.0.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentGold.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16.0.r),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentGold
                          : AppColors.accentGold.withValues(alpha: 0.25),
                      width: isSelected ? 1.5.w : 1.w,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.record_voice_over_rounded,
                        size: 18.0.sp,
                        color: isSelected
                            ? AppColors.accentGold
                            : AppColors.textPrimary.withValues(alpha: 0.6),
                      ),
                      SizedBox(width: 8.0.w),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          reciterDisplayName,
                          style: TextStyle(
                            fontSize: 14.0.sp,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.accentGold
                                : AppColors.textPrimary,
                            height: 1.15,
                          ),
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
