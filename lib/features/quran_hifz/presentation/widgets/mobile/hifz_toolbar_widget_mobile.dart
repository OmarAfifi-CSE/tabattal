import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../bloc/hifz_bloc.dart';
import '../../bloc/hifz_event.dart';
import '../../bloc/hifz_state.dart';

class HifzToolbarWidgetMobile extends StatefulWidget {
  const HifzToolbarWidgetMobile({super.key});

  @override
  State<HifzToolbarWidgetMobile> createState() => _HifzToolbarWidgetMobileState();
}

class _HifzToolbarWidgetMobileState extends State<HifzToolbarWidgetMobile> {
  double? _top;
  double? _left;
  bool _isMinimized = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<HifzBloc, HifzState>(
      buildWhen: (prev, curr) =>
          prev.isHifzModeActive != curr.isHifzModeActive ||
          prev.maskingType != curr.maskingType,
      builder: (context, state) {
        if (!state.isHifzModeActive) return const SizedBox.shrink();

        final screenSize = MediaQuery.sizeOf(context);
        final double bubbleSize = 42.r;
        final double toolbarHeight = 42.r;
        final double minMargin = 8.w;
        final double maxTop = (screenSize.height - toolbarHeight - 110.h).clamp(4.0, screenSize.height);

        // Default position at VERY TOP LEFT
        _top ??= 4.h.clamp(4.0, maxTop);
        _left ??= minMargin;

        return Builder(
          builder: (builderContext) {
            final double maxLeft = (screenSize.width - (_isMinimized ? bubbleSize : 340.w) - minMargin).clamp(minMargin, screenSize.width);
            final bool isOnRightHalf = (_left! + bubbleSize / 2) > (screenSize.width / 2);
            final Alignment transitionAlignment = isOnRightHalf ? Alignment.centerRight : Alignment.centerLeft;

            return Positioned(
              top: _top!.clamp(4.0, maxTop),
              left: isOnRightHalf ? null : _left!.clamp(minMargin, maxLeft),
              right: isOnRightHalf ? (screenSize.width - _left! - bubbleSize).clamp(minMargin, screenSize.width - bubbleSize - minMargin) : null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  setState(() {
                    _left = (_left! + details.delta.dx).clamp(minMargin, maxLeft);
                    _top = (_top! + details.delta.dy).clamp(4.0, maxTop);
                  });
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  reverseDuration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: transitionAlignment,
                    children: [
                      ...previousChildren,
                      ?currentChild,
                    ],
                  ),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: animation,
                      alignment: transitionAlignment,
                      child: child,
                    ),
                  ),
                  child: _isMinimized
                      ? InkWell(
                          key: const ValueKey('minimized_bubble'),
                          onTap: () => setState(() => _isMinimized = false),
                          borderRadius: BorderRadius.circular(bubbleSize / 2),
                          child: Material(
                            color: Colors.transparent,
                            elevation: 6,
                            shape: const CircleBorder(),
                            child: Container(
                              width: bubbleSize,
                              height: bubbleSize,
                              decoration: BoxDecoration(
                                color: AppColors.background.withValues(alpha: 0.96),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.accentGold,
                                  width: 1.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accentGold.withValues(alpha: 0.3),
                                    blurRadius: 9,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.auto_stories_rounded,
                                  color: AppColors.accentGold,
                                  size: 20.sp,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Material(
                          key: const ValueKey('expanded_toolbar'),
                          color: Colors.transparent,
                          elevation: 6,
                          borderRadius: BorderRadius.circular(toolbarHeight / 2),
                          child: Container(
                            height: toolbarHeight,
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(toolbarHeight / 2),
                              border: Border.all(
                                color: AppColors.accentGold.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.drag_indicator_rounded,
                                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                                  size: 20.sp,
                                ),
                                SizedBox(width: 6.w),
                                _HifzTypeChipMobile(
                                  type: HifzMaskingType.fullVerse,
                                  label: l10n.hifzMaskFull,
                                  isSelected: state.maskingType == HifzMaskingType.fullVerse,
                                ),
                                SizedBox(width: 5.w),
                                _HifzTypeChipMobile(
                                  type: HifzMaskingType.wordByWord,
                                  label: l10n.hifzMaskWord,
                                  isSelected: state.maskingType == HifzMaskingType.wordByWord,
                                ),
                                SizedBox(width: 10.w),
                                _HifzActionIconMobile(
                                  icon: Icons.refresh_rounded,
                                  color: AppColors.accentGold,
                                  onTap: () {
                                    context.read<HifzBloc>().add(const ClearRevealedItems());
                                  },
                                ),
                                SizedBox(width: 3.w),
                                _HifzActionIconMobile(
                                  icon: Icons.unfold_less_rounded,
                                  color: AppColors.textSecondary,
                                  onTap: () {
                                    setState(() => _isMinimized = true);
                                  },
                                ),
                                SizedBox(width: 3.w),
                                _HifzActionIconMobile(
                                  icon: Icons.close_rounded,
                                  color: Colors.redAccent,
                                  onTap: () {
                                    context
                                        .read<HifzBloc>()
                                        .add(const ToggleHifzMode(enabled: false));
                                  },
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
      },
    );
  }
}

class _HifzActionIconMobile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HifzActionIconMobile({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 5.w,
          vertical: 4.h,
        ),
        child: Icon(
          icon,
          color: color,
          size: 18.sp,
        ),
      ),
    );
  }
}

class _HifzTypeChipMobile extends StatelessWidget {
  final HifzMaskingType type;
  final String label;
  final bool isSelected;

  const _HifzTypeChipMobile({
    required this.type,
    required this.label,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        context.read<HifzBloc>().add(SetHifzMaskingType(type));
      },
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 10.w,
          vertical: 4.h,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentGold
              : AppColors.cardBackground.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5.sp,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
