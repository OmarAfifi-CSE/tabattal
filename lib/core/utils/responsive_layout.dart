import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

/// Clean, adaptive responsive layout builder for Tabattal.
///
/// Dynamically routes to the optimal layout variant based on active viewport width:
/// - On Web: Routes to [mobileBody] when viewport < 600 dp (mobile browsers),
///   and [webBody] for all browser desktop/tablet viewports.
/// - On Mobile/Tablet OS (Android & iOS): Routes to [mobileBody] if width < 600 dp,
///   and [tabletBody] for all tablet screens (including landscape 2560x1600).
/// - On Desktop OS (Windows, macOS, Linux): Routes to [desktopBody] when width >= 1100 dp,
///   [tabletBody] when 600 <= width < 1100 dp, and [mobileBody] when width < 600 dp.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobileBody;
  final Widget tabletBody;
  final Widget desktopBody;
  final Widget? webBody;

  const ResponsiveLayout({
    super.key,
    required this.mobileBody,
    required this.tabletBody,
    required this.desktopBody,
    this.webBody,
  });

  /// Standard breakpoint for native mobile vs tablet devices (Android & iOS).
  static const double mobileBreakpoint = 600.0;

  /// Responsive window resizing breakpoint for Web & Desktop platforms.
  static const double webAndDesktopMobileBreakpoint = 500.0;

  /// Multi-page / large viewport breakpoint for Desktop.
  static const double tabletBreakpoint = 1100.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (kIsWeb) {
          if (width < webAndDesktopMobileBreakpoint) {
            return mobileBody;
          }
          return webBody ?? desktopBody;
        }

        // On mobile/tablet operating systems (Android & iOS)
        if (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) {
          if (width < mobileBreakpoint) {
            return mobileBody;
          }
          return tabletBody;
        }

        // On native desktop operating systems (Windows, macOS, Linux)
        if (width >= tabletBreakpoint) {
          return desktopBody;
        } else if (width >= webAndDesktopMobileBreakpoint) {
          return tabletBody;
        } else {
          return mobileBody;
        }
      },
    );
  }
}
