import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';
import '../../features/settings/presentation/bloc/settings_bloc.dart';

/// Luxury custom desktop window title bar for Tabattal.
///
/// Seamlessly matches the active Mushaf theme and dark mode, offering:
/// - Smooth window dragging across the entire title bar area.
/// - Double-click to maximize / restore window.
/// - Themed minimize, maximize/restore, and close buttons with smooth hover feedback.
/// - Dual-script brand header with preserved Arabic ligatures.
class DesktopTitleBar extends StatefulWidget implements PreferredSizeWidget {
  const DesktopTitleBar({super.key});

  /// Standard desktop title bar height.
  static const double barHeight = 38.0;

  @override
  Size get preferredSize => const Size(0, barHeight);

  @override
  State<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends State<DesktopTitleBar> with WindowListener {
  bool _isMaximized = false;
  bool _isHoverMinimize = false;
  bool _isHoverMaximize = false;
  bool _isHoverClose = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.addListener(this);
      _checkMaximized();
    }
  }

  @override
  void dispose() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    try {
      final maximized = await windowManager.isMaximized();
      if (mounted) {
        setState(() => _isMaximized = maximized);
      }
    } catch (_) {}
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  Future<void> _toggleMaximize() async {
    try {
      final isMax = await windowManager.isMaximized();
      if (isMax) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) {
      return const SizedBox.shrink();
    }

    final settingsState = context.watch<SettingsBloc>().state;
    final theme = settingsState.effectiveMushafTheme;
    final isDark = theme.isDarkTheme;

    final Color barBackground = theme.backgroundColor;
    final Color textColor = theme.textColor;
    final Color goldColor = theme.goldColor;
    final Color buttonHoverColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    final double screenWidth = MediaQuery.sizeOf(context).width;

    return Material(
      color: barBackground,
      elevation: 0,
      child: SizedBox(
        width: screenWidth,
        height: DesktopTitleBar.barHeight,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              // 1. App Icon & Branding (Draggable Area)
              DragToMoveArea(
                child: Container(
                  height: DesktopTitleBar.barHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/app_icon_rounded.png',
                        width: 18.0,
                        height: 18.0,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.auto_stories_rounded,
                          size: 16.0,
                          color: goldColor,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            decoration: TextDecoration.none,
                            height: 1.0,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Tabattal',
                              style: TextStyle(
                                letterSpacing: 0.6,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            TextSpan(
                              text: '  •  ',
                              
                            ),
                            TextSpan(
                              text: 'تَـبَـتَّـلْ',
                              style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 13.5,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 2. Center Draggable & Double-Click Expand Area
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: _toggleMaximize,
                child: const DragToMoveArea(
                  child: SizedBox(
                    height: DesktopTitleBar.barHeight,
                  ),
                ),
              ),
            ),

            // 3. Desktop Window Controls (Minimize, Maximize / Restore, Close)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Minimize Button
                MouseRegion(
                  onEnter: (_) => setState(() => _isHoverMinimize = true),
                  onExit: (_) => setState(() => _isHoverMinimize = false),
                  child: GestureDetector(
                    onTap: () => windowManager.minimize(),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 46.0,
                      height: DesktopTitleBar.barHeight,
                      color: _isHoverMinimize ? buttonHoverColor : Colors.transparent,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.remove_rounded,
                        size: 16.0,
                        color: textColor.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),

                // Maximize / Restore Button
                MouseRegion(
                  onEnter: (_) => setState(() => _isHoverMaximize = true),
                  onExit: (_) => setState(() => _isHoverMaximize = false),
                  child: GestureDetector(
                    onTap: _toggleMaximize,
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 46.0,
                      height: DesktopTitleBar.barHeight,
                      color: _isHoverMaximize ? buttonHoverColor : Colors.transparent,
                      alignment: Alignment.center,
                      child: Icon(
                        _isMaximized
                            ? Icons.filter_none_rounded
                            : Icons.crop_square_rounded,
                        size: _isMaximized ? 12.0 : 13.5,
                        color: textColor.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),

                // Close Button
                MouseRegion(
                  onEnter: (_) => setState(() => _isHoverClose = true),
                  onExit: (_) => setState(() => _isHoverClose = false),
                  child: GestureDetector(
                    onTap: () => windowManager.close(),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 46.0,
                      height: DesktopTitleBar.barHeight,
                      color: _isHoverClose
                          ? const Color(0xFFE81123)
                          : Colors.transparent,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.close_rounded,
                        size: 15.0,
                        color: _isHoverClose
                            ? Colors.white
                            : textColor.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}
