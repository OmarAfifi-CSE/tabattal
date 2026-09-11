import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/reciter_catalog.dart';
import '../../../../../core/network/audio_download_manager.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/video_enums.dart';
import '../../../../../l10n/app_localizations.dart';

class VideoReciterSelectorTablet extends StatefulWidget {
  final String selectedReciter;
  final String? selectedCategory;
  final VideoTextDisplayMode displayMode;
  final int? surahNumber;
  final void Function(String name, String category, String path)
      onReciterSelected;

  const VideoReciterSelectorTablet({
    super.key,
    required this.selectedReciter,
    this.selectedCategory,
    this.displayMode = VideoTextDisplayMode.lineByLine,
    this.surahNumber,
    required this.onReciterSelected,
  });

  @override
  State<VideoReciterSelectorTablet> createState() =>
      _VideoReciterSelectorTabletState();
}

class _VideoReciterSelectorTabletState
    extends State<VideoReciterSelectorTablet> {
  late String _activeCategory;
  Set<String> _downloadedMp3QuranPaths = const {};


  Map<String, List<Map<String, String>>> get _recitersByCategory =>
      ReciterCatalog.getVideoRecitersByCategory(
        widget.displayMode,
        surahNumber: widget.surahNumber,
        downloadedMp3QuranPaths: _downloadedMp3QuranPaths,
      );

  @override
  void initState() {
    super.initState();
    _activeCategory = widget.selectedCategory ?? 'مرتل';
    _loadDownloadedReciters();
  }

  @override
  void didUpdateWidget(covariant VideoReciterSelectorTablet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCategory != null) {
      _activeCategory = widget.selectedCategory!;
    }
    if (widget.surahNumber != oldWidget.surahNumber) {
      _loadDownloadedReciters();
    }
  }

  Future<void> _loadDownloadedReciters() async {
    if (widget.surahNumber == null) return;
    final downloaded = await AudioDownloadManager().getDownloadedSurahReciterPaths(widget.surahNumber!);
    if (mounted) {
      setState(() {
        _downloadedMp3QuranPaths = downloaded;
      });
    }
  }

  void _showAllRecitersSheet(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    showDialog(
      context: context,
      builder: (ctx) {
        return _AllRecitersDialogContentTablet(
          recitersByCategory: _recitersByCategory,
          initialCategory: _activeCategory,
          selectedReciter: widget.selectedReciter,
          isEn: isEn,
          onReciterSelected: (name, category, path) {
            setState(() {
              _activeCategory = category;
            });
            widget.onReciterSelected(name, category, path);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentReciters =
        _recitersByCategory[_activeCategory] ?? [];

    // Fallback if current selected reciter is untimed / filtered out for this surah
    final isSelectedAvailable = currentReciters.any((r) => r['name'] == widget.selectedReciter);
    if (!isSelectedAvailable &&
        currentReciters.isNotEmpty &&
        _activeCategory == (widget.selectedCategory ?? _activeCategory)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final fallback = currentReciters.first;
          widget.onReciterSelected(fallback['name']!, _activeCategory, fallback['path']!);
        }
      });
    }

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
                    fontWeight: FontWeight.w600,
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
                _recitersByCategory.keys.length,
            separatorBuilder: (_, _) => SizedBox(width: 8.0.w),
            itemBuilder: (context, index) {
              final cat = _recitersByCategory.keys
                  .elementAt(index);
              final isCatSelected = cat == _activeCategory;
              final isEn = Localizations.localeOf(context).languageCode == 'en';

              return InkWell(
                onTap: () {
                  if (_activeCategory == cat) return;
                  setState(() {
                    _activeCategory = cat;
                  });
                  final reciters = _recitersByCategory[cat] ?? [];
                  if (reciters.isEmpty) return;

                  final matchingInCat = reciters
                      .where((r) => r['name'] == widget.selectedReciter)
                      .firstOrNull;
                  final selected = matchingInCat ?? reciters.first;
                  widget.onReciterSelected(
                      selected['name']!, cat, selected['path']!);
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
                              ? FontWeight.w600
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
                                ? FontWeight.w600
                                : FontWeight.w500,
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

class _AllRecitersDialogContentTablet extends StatefulWidget {
  final Map<String, List<Map<String, String>>> recitersByCategory;
  final String initialCategory;
  final String selectedReciter;
  final bool isEn;
  final void Function(String name, String category, String path) onReciterSelected;

  const _AllRecitersDialogContentTablet({
    required this.recitersByCategory,
    required this.initialCategory,
    required this.selectedReciter,
    required this.isEn,
    required this.onReciterSelected,
  });

  @override
  State<_AllRecitersDialogContentTablet> createState() => _AllRecitersDialogContentTabletState();
}

class _AllRecitersDialogContentTabletState extends State<_AllRecitersDialogContentTablet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _currentCategory;
  late String _currentReciter;
  late List<String> _categories;
  int _lastHandledIndex = -1;
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
    final initialIndex = _categories.indexOf(_currentCategory).clamp(0, _categories.isEmpty ? 0 : _categories.length - 1);
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

    final matching = reciters.where((r) => r['name'] == _currentReciter).firstOrNull;
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

    return Dialog(
      backgroundColor: AppColors.cardCream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0.r),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 500.w, maxHeight: 560.h),
        child: Directionality(
          textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
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
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, size: 22.sp),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                // Search Bar
                Container(
                  height: 38.h,
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
                        fontSize: 12.0.sp,
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    ),
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.accentGold,
                  unselectedLabelColor: AppColors.textPrimary.withValues(alpha: 0.6),
                  indicatorColor: AppColors.accentGold,
                  labelStyle: TextStyle(fontSize: 12.0.sp, fontWeight: FontWeight.w600),
                  tabs: _categories
                      .map((cat) => Tab(
                          text: isEn
                              ? ReciterCatalog.getCategoryNameEnglish(cat)
                              : cat))
                      .toList(),
                ),
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
                        final enName = ReciterCatalog.getReciterNameEnglish(name).toLowerCase();
                        return normName.contains(normQuery) ||
                               enName.contains(_searchQuery.toLowerCase()) ||
                               name.toLowerCase().contains(_searchQuery.toLowerCase());
                      }).toList();

                      if (filteredReciters.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.h),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 32.sp,
                                  color: AppColors.textPrimary.withValues(alpha: 0.3),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  isEn ? 'No reciters found' : 'لا توجد نتائج مطابقة',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: AppColors.textPrimary.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: EdgeInsets.symmetric(vertical: 8.0.h),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredReciters.length,
                        separatorBuilder: (_, _) => Divider(height: 1.h),
                        itemBuilder: (subCtx, idx) {
                          final item = filteredReciters[idx];
                          final isSelected = item['name'] == _currentReciter && _currentCategory == cat;
                          final reciterDisplayName = isEn
                              ? ReciterCatalog.getReciterNameEnglish(item['name']!)
                              : item['name']!;

                          return ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.record_voice_over_rounded,
                              color: isSelected
                                  ? AppColors.accentGold
                                  : AppColors.textPrimary.withValues(alpha: 0.5),
                              size: 18.0.sp,
                            ),
                            title: Text(
                              reciterDisplayName,
                              style: TextStyle(
                                fontSize: 13.0.sp,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? AppColors.accentGold : AppColors.textPrimary,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle_rounded,
                                    color: AppColors.accentGold, size: 20.sp)
                                : null,
                            onTap: () {
                              setState(() {
                                _currentCategory = cat;
                                _currentReciter = item['name']!;
                              });
                              widget.onReciterSelected(item['name']!, cat, item['path']!);
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
        ),
      ),
    );
  }
}
