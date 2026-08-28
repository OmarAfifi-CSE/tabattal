import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';

/// Represents a single selectable timer option.
class SleepTimerOption {
  final int minutes;
  final String label;

  const SleepTimerOption({
    required this.minutes,
    required this.label,
  });

  /// Factory to generate standard localized timer options.
  static List<SleepTimerOption> getLocalizedOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      SleepTimerOption(minutes: 0, label: l10n.timerStop),
      SleepTimerOption(minutes: 5, label: l10n.timerMinutes5),
      SleepTimerOption(minutes: 10, label: l10n.timerMinutes10),
      SleepTimerOption(minutes: 15, label: l10n.timerMinutes15),
      SleepTimerOption(minutes: 30, label: l10n.timerMinutes30),
      SleepTimerOption(minutes: 60, label: l10n.timerMinutes60),
    ];
  }
}

/// A premium, scrollable popup menu for selecting the sleep timer duration.
/// Displays above the trigger button with auto-scrolling to the selected option,
/// a custom gold scrollbar, and matching application theme aesthetics.
class SleepTimerSelectorMenu extends StatelessWidget {
  final int? selectedMinutes;
  final ValueChanged<int> onSelected;
  final Widget trigger;
  final double itemHeight;
  final double? maxHeight;
  final double itemFontSize;
  final double menuWidth;

  const SleepTimerSelectorMenu({
    super.key,
    required this.selectedMinutes,
    required this.onSelected,
    required this.trigger,
    this.itemHeight = 36.0,
    this.maxHeight,
    this.itemFontSize = 13.0,
    this.menuWidth = 145.0,
  });

  @override
  Widget build(BuildContext context) {
    final options = SleepTimerOption.getLocalizedOptions(context);
    final itemH = itemHeight;
    final maxH = maxHeight ?? math.min(150.0, options.length * itemH);
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final activeMinutes = selectedMinutes ?? 0;

    return PopupMenuButton<int>(
      splashRadius: 0.1,
      offset: Offset(0, -maxH - 8),
      color: AppColors.cardCream,
      elevation: 4,
      menuPadding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: menuWidth,
        maxWidth: menuWidth + 20,
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
            child: _SleepTimerScrollableContent(
              options: options,
              selectedMinutes: activeMinutes,
              maxHeight: maxH,
              itemHeight: itemH,
              itemFontSize: itemFontSize,
            ),
          ),
        ),
      ],
      child: trigger,
    );
  }
}

class _SleepTimerScrollableContent extends StatefulWidget {
  final List<SleepTimerOption> options;
  final int selectedMinutes;
  final double maxHeight;
  final double itemHeight;
  final double itemFontSize;

  const _SleepTimerScrollableContent({
    required this.options,
    required this.selectedMinutes,
    required this.maxHeight,
    required this.itemHeight,
    required this.itemFontSize,
  });

  @override
  State<_SleepTimerScrollableContent> createState() =>
      _SleepTimerScrollableContentState();
}

class _SleepTimerScrollableContentState
    extends State<_SleepTimerScrollableContent> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final index = widget.options.indexWhere(
      (o) => o.minutes == widget.selectedMinutes,
    );
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
        thumbVisibility: totalContentHeight > widget.maxHeight,
        thickness: 4.0.w,
        radius: Radius.circular(8.r),
        thumbColor: AppColors.accentGold.withValues(alpha: 0.5),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.options.map((option) {
              final isSelected = option.minutes == widget.selectedMinutes;
              return InkWell(
                onTap: () => Navigator.pop(context, option.minutes),
                child: Container(
                  width: MediaQuery.sizeOf(context).width,
                  height: widget.itemHeight,
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  alignment: AlignmentDirectional.centerStart,
                  color: isSelected
                      ? AppColors.accentGold.withValues(alpha: 0.12)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      if (isSelected)
                        Padding(
                          padding: EdgeInsetsDirectional.only(end: 6.w),
                          child: Icon(
                            Icons.check_rounded,
                            color: AppColors.accentGold,
                            size: 16.r,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          option.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
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
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
