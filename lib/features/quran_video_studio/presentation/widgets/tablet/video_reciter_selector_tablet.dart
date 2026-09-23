import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/reciter_catalog.dart';
import '../../../../../core/network/audio_download_manager.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/video_enums.dart';
import '../../../../../l10n/app_localizations.dart';
import '../shared/video_all_reciters_modal.dart';

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
    final isEn = Localizations.localeOf(context).languageCode != 'ar';

    VideoAllRecitersModal.showAsDialog(
      context: context,
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
                        ReciterCatalog.localizeCategory(context, cat),
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
              final reciterDisplayName =
                  ReciterCatalog.localizeReciter(context, reciter['name']!);

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

