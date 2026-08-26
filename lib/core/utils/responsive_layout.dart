import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Clean, adaptive responsive layout builder for Tabattal.
///
/// Dynamically routes to the optimal layout variant based on active viewport width:
/// - On Web: Routes to [mobileBody] when viewport < 600 dp (mobile browsers),
///   and [webBody] for all browser desktop/tablet viewports.
/// - On Native Platforms: Routes cleanly between [mobileBody], [tabletBody], and [desktopBody].
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

  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 1100.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (kIsWeb) {
          if (width < mobileBreakpoint) {
            return mobileBody;
          }
          return webBody ?? desktopBody;
        }

        // On Native Desktop / Tablet / Mobile platforms:
        if (width >= tabletBreakpoint) {
          return desktopBody;
        } else if (width >= mobileBreakpoint) {
          return tabletBody;
        } else {
          return mobileBody;
        }
      },
    );
  }
}
