import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';

/// A reusable, styled selector dropdown button with auto-scroll and centering
/// used across Audio Settings bottom sheets and the Audio Download Manager view.
class AudioSelectorButton<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final String Function(T) labelBuilder;
  final double height;
  final double? maxHeight;
  final double? itemHeight;
  final double labelFontSize;
  final double valueFontSize;
  final double itemFontSize;
  final double iconSize;

  const AudioSelectorButton({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.labelBuilder,
    this.height = 48.0,
    this.maxHeight,
    this.itemHeight,
    this.labelFontSize = 10.0,
    this.valueFontSize = 14.0,
    this.itemFontSize = 14.5,
    this.iconSize = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    final itemH = itemHeight ?? 42.0;
    final maxH = maxHeight ?? math.min(210.0, items.length * itemH);

    return LayoutBuilder(
      builder: (context, layoutConstraints) {
        return PopupMenuButton<T>(
          splashRadius: 0.1,
          position: PopupMenuPosition.under,
          offset: const Offset(0, 4),
          color: AppColors.cardCream,
          elevation: 4,
          menuPadding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: layoutConstraints.maxWidth,
            maxWidth: layoutConstraints.maxWidth,
            maxHeight: maxH,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
            side: BorderSide(
              color: AppColors.accentGold.withValues(alpha: 0.15),
            ),
          ),
          clipBehavior: Clip.hardEdge,
          onSelected: onChanged,
          itemBuilder: (context) => [
            PopupMenuItem<T>(
              enabled: false,
              padding: EdgeInsets.zero,
              height: maxH,
              child: Directionality(
                textDirection: Directionality.of(context),
                child: _PopupMenuScrollableContent<T>(
                  items: items,
                  value: value,
                  labelBuilder: labelBuilder,
                  maxHeight: maxH,
                  itemHeight: itemH,
                  itemFontSize: itemFontSize,
                ),
              ),
            ),
          ],
          child: Container(
            constraints: BoxConstraints(minHeight: height),
            width: MediaQuery.sizeOf(context).width,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.surfaceCream,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: AppColors.accentGold.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.accentGold, size: iconSize),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: labelFontSize,
                          color: AppColors.accentGold,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                      Text(
                        labelBuilder(value),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: valueFontSize,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.accentGold,
                  size: 20.r,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PopupMenuScrollableContent<T> extends StatefulWidget {
  final List<T> items;
  final T value;
  final String Function(T) labelBuilder;
  final double maxHeight;
  final double itemHeight;
  final double itemFontSize;

  const _PopupMenuScrollableContent({
    required this.items,
    required this.value,
    required this.labelBuilder,
    required this.maxHeight,
    required this.itemHeight,
    required this.itemFontSize,
  });

  @override
  State<_PopupMenuScrollableContent<T>> createState() =>
      _PopupMenuScrollableContentState<T>();
}

class _PopupMenuScrollableContentState<T>
    extends State<_PopupMenuScrollableContent<T>> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final index = widget.items.indexOf(widget.value);
    double offset = 0;
    final totalHeight = widget.items.length * widget.itemHeight;
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
    final totalContentHeight = widget.items.length * widget.itemHeight;
    final contentHeight = math.min(widget.maxHeight, totalContentHeight);

    return SizedBox(
      height: contentHeight,
      child: RawScrollbar(
        controller: _scrollController,
        thumbVisibility:
            widget.items.length * widget.itemHeight > widget.maxHeight,
        thickness: 4.0.w,
        radius: Radius.circular(8.r),
        thumbColor: AppColors.accentGold.withValues(alpha: 0.5),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.items.map((item) {
              final isSelected = item == widget.value;
              return InkWell(
                onTap: () => Navigator.pop(context, item),
                child: Container(
                  width: MediaQuery.sizeOf(context).width,
                  height: widget.itemHeight,
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  alignment: AlignmentDirectional.centerStart,
                  color: isSelected
                      ? AppColors.accentGold.withValues(alpha: 0.1)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      if (isSelected)
                        Padding(
                          padding: EdgeInsetsDirectional.only(end: 8.w),
                          child: Icon(
                            Icons.check_rounded,
                            color: AppColors.accentGold,
                            size: 15.r,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          widget.labelBuilder(item),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: widget.itemFontSize,
                            color: AppColors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
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
