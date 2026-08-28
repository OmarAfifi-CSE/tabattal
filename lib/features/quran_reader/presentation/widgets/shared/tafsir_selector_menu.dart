import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../l10n/app_localizations.dart';

/// Represents a single selectable Tafsir item in the dropdown menu.
class TafsirOption {
  final int id;
  final String name;
  final bool isDownloaded;
  final bool isDownloading;
  final double downloadProgress;

  const TafsirOption({
    required this.id,
    required this.name,
    this.isDownloaded = true,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
  });

  /// Factory helper to build the localized list of Tafsir options for the given context.
  static List<TafsirOption> getLocalizedOptions(
    BuildContext context, {
    required Set<int> downloadedIds,
    Map<int, double>? progressMap,
    int? activeDownloadingId,
    double? activeDownloadProgress,
  }) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final l10n = AppLocalizations.of(context)!;

    final rawList = isEn
        ? [
            (169, l10n.tafsirEnIbnKathir),
            (168, l10n.tafsirEnMaarif),
            (817, l10n.tafsirEnTazkirul),
          ]
        : [
            (16, l10n.tafsirAlMuyassar),
            (14, l10n.tafsirIbnKathir),
            (91, l10n.tafsirAlSaadi),
            (15, l10n.tafsirAlTabari),
            (90, l10n.tafsirAlQurtubi),
            (93, l10n.tafsirAlWaseet),
            (94, l10n.tafsirAlBaghawi),
          ];

    return rawList.map((item) {
      final id = item.$1;
      final name = item.$2;
      final isDownloaded = id == 16 ||
          downloadedIds.contains(id) ||
          (progressMap != null && progressMap[id] == 1.0);

      final isDownloading = !isDownloaded &&
          ((activeDownloadingId == id) ||
              (progressMap != null &&
                  progressMap.containsKey(id) &&
                  progressMap[id]! > 0.0 &&
                  progressMap[id]! < 1.0));

      final progress = activeDownloadingId == id
          ? (activeDownloadProgress ?? 0.0)
          : (progressMap?[id] ?? 0.0);

      return TafsirOption(
        id: id,
        name: name,
        isDownloaded: isDownloaded,
        isDownloading: isDownloading,
        downloadProgress: progress,
      );
    }).toList();
  }
}

/// A smart popup dropdown menu for selecting Tafsir, featuring auto-scrolling
/// to center the active item, custom gold scrollbar, and download indicators.
class TafsirSelectorMenu extends StatelessWidget {
  final int selectedId;
  final List<TafsirOption> options;
  final ValueChanged<int> onSelected;
  final Widget? trigger;
  final double itemHeight;
  final double? maxHeight;
  final double itemFontSize;
  final double? menuWidth;
  final bool openUpwards;

  const TafsirSelectorMenu({
    super.key,
    required this.selectedId,
    required this.options,
    required this.onSelected,
    this.trigger,
    this.itemHeight = 38.0,
    this.maxHeight,
    this.itemFontSize = 14.0,
    this.menuWidth,
    this.openUpwards = false,
  });

  @override
  Widget build(BuildContext context) {
    final itemH = itemHeight;
    final maxH = maxHeight ?? math.min(220.0, options.length * itemH);
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final effectiveWidth = menuWidth ?? (isEn ? 190.0 : 120.0);

    return PopupMenuButton<int>(
      splashRadius: 0.1,
      position: openUpwards ? PopupMenuPosition.over : PopupMenuPosition.under,
      offset: openUpwards ? Offset(0, -maxH - 6) : const Offset(0, 4),
      color: AppColors.cardCream,
      elevation: 4,
      menuPadding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: effectiveWidth,
        maxWidth: effectiveWidth,
        maxHeight: maxH,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(
          color: AppColors.accentGold.withValues(alpha: 0.2),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem<int>(
          enabled: false,
          padding: EdgeInsets.zero,
          height: maxH,
          child: Directionality(
            textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
            child: _TafsirMenuScrollableContent(
              options: options,
              selectedId: selectedId,
              maxHeight: maxH,
              itemHeight: itemH,
              itemFontSize: itemFontSize,
            ),
          ),
        ),
      ],
      child: trigger ??
          Padding(
            padding: EdgeInsets.all(8.0.r),
            child: Icon(
              Icons.tune_rounded,
              color: AppColors.accentGold,
              size: 22.r,
            ),
          ),
    );
  }
}

class _TafsirMenuScrollableContent extends StatefulWidget {
  final List<TafsirOption> options;
  final int selectedId;
  final double maxHeight;
  final double itemHeight;
  final double itemFontSize;

  const _TafsirMenuScrollableContent({
    required this.options,
    required this.selectedId,
    required this.maxHeight,
    required this.itemHeight,
    required this.itemFontSize,
  });

  @override
  State<_TafsirMenuScrollableContent> createState() =>
      _TafsirMenuScrollableContentState();
}

class _TafsirMenuScrollableContentState
    extends State<_TafsirMenuScrollableContent> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final index = widget.options.indexWhere((o) => o.id == widget.selectedId);
    double offset = 0;
    final totalHeight = widget.options.length * widget.itemHeight;
    if (index != -1 && totalHeight > widget.maxHeight) {
      offset = (index * widget.itemHeight) -
          (widget.maxHeight / 2) +
          (widget.itemHeight / 2);
      if (offset < 0) offset = 0;
      final maxScroll = totalHeight - widget.maxHeight;
      if (offset > maxScroll) offset = maxScroll;
    }
    _scrollController = ScrollController(initialScrollOffset: offset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalContentHeight = widget.options.length * widget.itemHeight;
    final contentHeight = math.min(widget.maxHeight, totalContentHeight);

    return SizedBox(
      height: contentHeight,
      child: RawScrollbar(
        controller: _scrollController,
        thumbVisibility:
            widget.options.length * widget.itemHeight > widget.maxHeight,
        thickness: 4.0.w,
        radius: Radius.circular(8.r),
        thumbColor: AppColors.accentGold.withValues(alpha: 0.5),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.options.map((option) {
              final isSelected = option.id == widget.selectedId;
              return InkWell(
                onTap: () => Navigator.pop(context, option.id),
                child: Container(
                  width: MediaQuery.sizeOf(context).width,
                  height: widget.itemHeight,
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  alignment: AlignmentDirectional.centerStart,
                  color: isSelected
                      ? AppColors.accentGold.withValues(alpha: 0.12)
                      : Colors.transparent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (isSelected)
                              Padding(
                                padding:
                                    EdgeInsetsDirectional.only(end: 6.w),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: AppColors.accentGold,
                                  size: 16.r,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                option.name,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.menuItemText.copyWith(
                                  fontSize: widget.itemFontSize,
                                  color: isSelected
                                      ? AppColors.accentGold
                                      : AppColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (option.isDownloading)
                        Text(
                          '${(option.downloadProgress * 100).toInt()}%',
                          style: AppTextStyles.menuItemText.copyWith(
                            fontSize: widget.itemFontSize - 2,
                            color: AppColors.accentGold,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else if (!option.isDownloaded)
                        Icon(
                          Icons.download_rounded,
                          size: 16.r,
                          color: AppColors.accentGold.withValues(alpha: 0.7),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
