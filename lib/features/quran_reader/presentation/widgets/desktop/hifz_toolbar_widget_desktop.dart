import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../bloc/hifz/hifz_bloc.dart';
import '../../../bloc/hifz/hifz_event.dart';
import '../../../bloc/hifz/hifz_state.dart';

class HifzToolbarWidgetDesktop extends StatefulWidget {
  const HifzToolbarWidgetDesktop({super.key});

  @override
  State<HifzToolbarWidgetDesktop> createState() => _HifzToolbarWidgetDesktopState();
}

class _HifzToolbarWidgetDesktopState extends State<HifzToolbarWidgetDesktop> {
  double? _top;
  double? _left;
  bool _isMinimized = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return BlocBuilder<HifzBloc, HifzState>(
      buildWhen: (prev, curr) =>
          prev.isHifzModeActive != curr.isHifzModeActive ||
          prev.maskingType != curr.maskingType,
      builder: (context, state) {
        if (!state.isHifzModeActive) return const SizedBox.shrink();

        final screenSize = MediaQuery.sizeOf(context);
        final double bubbleSize = (isLandscape ? 52.0 : 56.0).r;
        final double toolbarHeight = (isLandscape ? 52.0 : 54.0).r;
        final double minMargin = (isLandscape ? 12.0 : 10.0).w;
        final double maxTop = (screenSize.height - toolbarHeight - (isLandscape ? 70.0.h : 90.0.h)).clamp(4.0, screenSize.height);

        // Default position at TOP LEFT
        _top ??= (isLandscape ? 12.0.h : 10.0.h).clamp(4.0, maxTop);
        _left ??= minMargin;

        return Builder(
          builder: (builderContext) {
            final double expandedWidth = (isLandscape ? 440.0 : 420.0).w;
            final double maxLeft = (screenSize.width - (_isMinimized ? bubbleSize : expandedWidth) - minMargin).clamp(minMargin, screenSize.width);
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
                          key: const ValueKey('desktop_minimized_bubble'),
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
                                  width: 2.0.r,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accentGold.withValues(alpha: 0.3),
                                    blurRadius: 9.r,
                                    spreadRadius: 1.r,
                                    offset: Offset(0, 2.h),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.auto_stories_rounded,
                                  color: AppColors.accentGold,
                                  size: (isLandscape ? 26.0 : 28.0).sp,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Material(
                          key: const ValueKey('desktop_expanded_toolbar'),
                          color: Colors.transparent,
                          elevation: 6,
                          borderRadius: BorderRadius.circular(toolbarHeight / 2),
                          child: Container(
                            height: toolbarHeight,
                            padding: EdgeInsets.symmetric(
                              horizontal: (isLandscape ? 14.0 : 14.0).w,
                              vertical: (isLandscape ? 4.0 : 4.0).h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(toolbarHeight / 2),
                              border: Border.all(
                                color: AppColors.accentGold.withValues(alpha: 0.6),
                                width: 1.5.r,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 12.r,
                                  offset: Offset(0, 4.h),
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
                                  size: (isLandscape ? 22.0 : 24.0).sp,
                                ),
                                SizedBox(width: (isLandscape ? 8.0 : 8.0).w),
                                _DesktopHifzTypeChip(
                                  type: HifzMaskingType.fullVerse,
                                  label: l10n.hifzMaskFull,
                                  isSelected: state.maskingType == HifzMaskingType.fullVerse,
                                  isLandscape: isLandscape,
                                ),
                                SizedBox(width: (isLandscape ? 8.0 : 8.0).w),
                                _DesktopHifzTypeChip(
                                  type: HifzMaskingType.wordByWord,
                                  label: l10n.hifzMaskWord,
                                  isSelected: state.maskingType == HifzMaskingType.wordByWord,
                                  isLandscape: isLandscape,
                                ),
                                SizedBox(width: (isLandscape ? 12.0 : 12.0).w),
                                _DesktopHifzActionIcon(
                                  icon: Icons.refresh_rounded,
                                  color: AppColors.accentGold,
                                  isLandscape: isLandscape,
                                  onTap: () {
                                    context.read<HifzBloc>().add(const ClearRevealedItems());
                                  },
                                ),
                                SizedBox(width: (isLandscape ? 6.0 : 6.0).w),
                                _DesktopHifzActionIcon(
                                  icon: Icons.unfold_less_rounded,
                                  color: AppColors.textSecondary,
                                  isLandscape: isLandscape,
                                  onTap: () {
                                    setState(() => _isMinimized = true);
                                  },
                                ),
                                SizedBox(width: (isLandscape ? 6.0 : 6.0).w),
                                _DesktopHifzActionIcon(
                                  icon: Icons.close_rounded,
                                  color: Colors.redAccent,
                                  isLandscape: isLandscape,
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

class _DesktopHifzActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLandscape;

  const _DesktopHifzActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.isLandscape,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: (isLandscape ? 6.0 : 6.0).w,
          vertical: (isLandscape ? 5.0 : 5.0).h,
        ),
        child: Icon(
          icon,
          color: color,
          size: (isLandscape ? 22.0 : 22.0).sp,
        ),
      ),
    );
  }
}

class _DesktopHifzTypeChip extends StatelessWidget {
  final HifzMaskingType type;
  final String label;
  final bool isSelected;
  final bool isLandscape;

  const _DesktopHifzTypeChip({
    required this.type,
    required this.label,
    required this.isSelected,
    required this.isLandscape,
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
          horizontal: (isLandscape ? 12.0 : 12.0).w,
          vertical: (isLandscape ? 6.0 : 6.0).h,
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
            fontSize: (isLandscape ? 14.0 : 15.0).sp,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
