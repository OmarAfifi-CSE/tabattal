import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/reciter_catalog.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';

/// A shared, high-performance modal sheet for selecting reciters in Video Studio
/// across mobile, desktop, tablet, and web platforms.
class VideoAllRecitersModal extends StatefulWidget {
  final Map<String, List<Map<String, String>>> recitersByCategory;
  final String initialCategory;
  final String selectedReciter;
  final bool isEn;
  final void Function(String name, String category, String path) onReciterSelected;
  final double maxHeightFactor;
  final bool isDialog;

  const VideoAllRecitersModal({
    super.key,
    required this.recitersByCategory,
    required this.initialCategory,
    required this.selectedReciter,
    required this.isEn,
    required this.onReciterSelected,
    this.maxHeightFactor = 0.82,
    this.isDialog = false,
  });

  /// Displays the modal adaptively as a bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required Map<String, List<Map<String, String>>> recitersByCategory,
    required String initialCategory,
    required String selectedReciter,
    required bool isEn,
    required void Function(String name, String category, String path) onReciterSelected,
    double maxHeightFactor = 0.82,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardCream,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        return VideoAllRecitersModal(
          recitersByCategory: recitersByCategory,
          initialCategory: initialCategory,
          selectedReciter: selectedReciter,
          isEn: isEn,
          onReciterSelected: onReciterSelected,
          maxHeightFactor: maxHeightFactor,
          isDialog: false,
        );
      },
    );
  }

  /// Displays the modal as a dialog for desktop, tablet, and web.
  static Future<void> showAsDialog({
    required BuildContext context,
    required Map<String, List<Map<String, String>>> recitersByCategory,
    required String initialCategory,
    required String selectedReciter,
    required bool isEn,
    required void Function(String name, String category, String path) onReciterSelected,
    double maxWidth = 500,
    double maxHeight = 560,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppColors.cardCream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0.r),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth.w, maxHeight: maxHeight.h),
            child: VideoAllRecitersModal(
              recitersByCategory: recitersByCategory,
              initialCategory: initialCategory,
              selectedReciter: selectedReciter,
              isEn: isEn,
              onReciterSelected: onReciterSelected,
              isDialog: true,
            ),
          ),
        );
      },
    );
  }

  @override
  State<VideoAllRecitersModal> createState() => _VideoAllRecitersModalState();
}

class _VideoAllRecitersModalState extends State<VideoAllRecitersModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<String> _categories;
  late String _currentCategory;
  late String _currentReciter;
  int _lastHandledIndex = 0;
  String _searchQuery = '';

  static String _normalizeArabic(String text) {
    return text
        .replaceAll(RegExp(r'[\u064B-\u0652\u0670]'), '')
        .replaceAll(RegExp(r'[إأآا]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ـ', '')
        .toLowerCase()
        .trim();
  }

  @override
  void initState() {
    super.initState();
    _categories = widget.recitersByCategory.keys.toList();
    _currentCategory = widget.initialCategory;
    _currentReciter = widget.selectedReciter;
    final initialIndex = _categories
        .indexOf(_currentCategory)
        .clamp(0, _categories.isEmpty ? 0 : _categories.length - 1);
    _lastHandledIndex = initialIndex;
    _tabController = TabController(
      initialIndex: initialIndex,
      length: _categories.length,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.index == _lastHandledIndex) return;
    _lastHandledIndex = _tabController.index;
    final newCat = _categories[_tabController.index];
    final reciters = widget.recitersByCategory[newCat] ?? [];
    if (reciters.isEmpty) {
      setState(() {
        _currentCategory = newCat;
      });
      return;
    }

    final matching =
        reciters.where((r) => r['name'] == _currentReciter).firstOrNull;
    final selected = matching ?? reciters.first;

    setState(() {
      _currentCategory = newCat;
      _currentReciter = selected['name']!;
    });

    widget.onReciterSelected(selected['name']!, newCat, selected['path']!);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = widget.isEn;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Container(
        constraints: widget.isDialog
            ? null
            : BoxConstraints(
                maxHeight:
                    MediaQuery.sizeOf(context).height * widget.maxHeightFactor,
              ),
        padding: widget.isDialog
            ? EdgeInsets.all(16.0.r)
            : EdgeInsets.only(
                left: 16.w,
                right: 16.w,
                top: 12.h,
                bottom: MediaQuery.paddingOf(context).bottom + 8.h,
              ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar (bottom sheet only)
            if (!widget.isDialog)
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
                    Icon(
                      Icons.verified_rounded,
                      color: AppColors.accentGold,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      l10n.videoStudioChooseReciter,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SizedBox(height: 6.h),

            // Search Bar
            Container(
              height: 40.h,
              margin: EdgeInsets.only(bottom: 8.h),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppColors.accentGold.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
                textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: isEn ? 'Search reciters...' : 'ابحث عن قارئ...',
                  hintStyle: TextStyle(
                    fontSize: 12.5.sp,
                    color: AppColors.textPrimary.withValues(alpha: 0.45),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18.sp,
                    color: AppColors.accentGold,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 16.sp,
                            color: AppColors.textPrimary.withValues(alpha: 0.5),
                          ),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                ),
              ),
            ),

            // Category Tab Bar
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.accentGold,
              unselectedLabelColor:
                  AppColors.textPrimary.withValues(alpha: 0.6),
              indicatorColor: AppColors.accentGold,
              labelStyle:
                  TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
              tabs: _categories
                  .map((cat) => Tab(
                      text: isEn
                          ? ReciterCatalog.getCategoryNameEnglish(cat)
                          : cat))
                  .toList(),
            ),

            // Reciters List
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _categories.map((cat) {
                  final reciters = widget.recitersByCategory[cat] ?? [];

                  final normQuery = _normalizeArabic(_searchQuery);
                  final filteredReciters = reciters.where((item) {
                    if (normQuery.isEmpty) return true;
                    final name = item['name'] ?? '';
                    final normName = _normalizeArabic(name);
                    final enName =
                        ReciterCatalog.getReciterNameEnglish(name).toLowerCase();
                    return normName.contains(normQuery) ||
                        enName.contains(_searchQuery.toLowerCase()) ||
                        name.toLowerCase().contains(_searchQuery.toLowerCase());
                  }).toList();

                  if (filteredReciters.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32.h),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 36.sp,
                              color:
                                  AppColors.textPrimary.withValues(alpha: 0.3),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              isEn ? 'No reciters found' : 'لا توجد نتائج مطابقة',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: AppColors.textPrimary
                                    .withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredReciters.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (subCtx, idx) {
                      final item = filteredReciters[idx];
                      final isSelected = item['name'] == _currentReciter &&
                          _currentCategory == cat;
                      final reciterDisplayName = isEn
                          ? ReciterCatalog.getReciterNameEnglish(item['name']!)
                          : item['name']!;

                      return ListTile(
                        leading: Icon(
                          Icons.record_voice_over_rounded,
                          color: isSelected
                              ? AppColors.accentGold
                              : AppColors.textPrimary.withValues(alpha: 0.5),
                          size: 20.sp,
                        ),
                        title: Text(
                          reciterDisplayName,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? AppColors.accentGold
                                : AppColors.textPrimary,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded,
                                color: AppColors.accentGold)
                            : null,
                        onTap: () {
                          setState(() {
                            _currentCategory = cat;
                            _currentReciter = item['name']!;
                          });
                          widget.onReciterSelected(
                              item['name']!, cat, item['path']!);
                          Navigator.pop(context);
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
    );
  }
}
