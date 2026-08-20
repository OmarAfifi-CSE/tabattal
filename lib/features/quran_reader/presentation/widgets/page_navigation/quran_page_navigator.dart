import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/constants/quran_constants.dart';

typedef QuranPageSpreadBuilder =
    Widget Function(BuildContext context, int pageNumber);

/// Navigates Quran pages in a fixed viewport and commits changes after a swipe.
class QuranPageNavigator extends StatefulWidget {
  final int currentPage;
  final int totalPages;
  final int pageStep;
  final Axis scrollDirection;
  final QuranPageSpreadBuilder pageBuilder;
  final ValueChanged<int> onPageChanged;
  final VoidCallback? onInteractionStart;

  const QuranPageNavigator({
    super.key,
    required this.currentPage,
    this.totalPages = QuranConstants.totalPages,
    this.pageStep = 1,
    this.scrollDirection = Axis.horizontal,
    required this.pageBuilder,
    required this.onPageChanged,
    this.onInteractionStart,
  });

  @override
  State<QuranPageNavigator> createState() => QuranPageNavigatorState();
}

class QuranPageNavigatorState extends State<QuranPageNavigator> {
  double _dragAccumulator = 0.0;

  /// Commits a programmatic page change in the existing viewport.
  void navigateToPage(int targetPage) {
    if (targetPage == widget.currentPage) return;
    final clamped = targetPage.clamp(1, widget.totalPages);

    widget.onInteractionStart?.call();
    setState(() => _dragAccumulator = 0.0);
    widget.onPageChanged(clamped);
  }

  void _onDragStart(DragStartDetails _) {
    _dragAccumulator = 0.0;
    widget.onInteractionStart?.call();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.scrollDirection != Axis.horizontal) return;
    _dragAccumulator += details.primaryDelta ?? 0.0;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (widget.scrollDirection != Axis.vertical) return;
    _dragAccumulator += details.primaryDelta ?? 0.0;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (widget.scrollDirection != Axis.horizontal) return;
    _finalizeDrag(details.primaryVelocity ?? 0.0);
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (widget.scrollDirection != Axis.vertical) return;
    _finalizeDrag(details.primaryVelocity ?? 0.0);
  }

  void _finalizeDrag(double velocity) {
    final size = MediaQuery.sizeOf(context);
    final totalDimension = widget.scrollDirection == Axis.horizontal
        ? size.width
        : size.height;
    final direction = _dragAccumulator == 0 ? velocity : _dragAccumulator;
    final isNextSwipe = widget.scrollDirection == Axis.horizontal
        ? direction > 0
        : direction < 0;
    final targetPage = isNextSwipe
        ? (widget.currentPage + widget.pageStep).clamp(1, widget.totalPages)
        : (widget.currentPage - widget.pageStep).clamp(1, widget.totalPages);
    final bool velocityFavorsCompletion =
        widget.scrollDirection == Axis.horizontal
        ? (isNextSwipe ? velocity > 250 : velocity < -250)
        : (isNextSwipe ? velocity < -250 : velocity > 250);

    final fraction = totalDimension > 0
        ? _dragAccumulator.abs() / totalDimension
        : 0.0;
    final shouldComplete =
        targetPage != widget.currentPage &&
        (fraction >= 0.18 || velocityFavorsCompletion);

    if (shouldComplete) {
      HapticFeedback.selectionClick();
      widget.onPageChanged(targetPage);
    }
    setState(() => _dragAccumulator = 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: widget.scrollDirection == Axis.horizontal
          ? _onDragStart
          : null,
      onHorizontalDragUpdate: widget.scrollDirection == Axis.horizontal
          ? _onHorizontalDragUpdate
          : null,
      onHorizontalDragEnd: widget.scrollDirection == Axis.horizontal
          ? _onHorizontalDragEnd
          : null,
      onVerticalDragStart: widget.scrollDirection == Axis.vertical
          ? _onDragStart
          : null,
      onVerticalDragUpdate: widget.scrollDirection == Axis.vertical
          ? _onVerticalDragUpdate
          : null,
      onVerticalDragEnd: widget.scrollDirection == Axis.vertical
          ? _onVerticalDragEnd
          : null,
      child: RepaintBoundary(
        child: widget.pageBuilder(context, widget.currentPage),
      ),
    );
  }
}
