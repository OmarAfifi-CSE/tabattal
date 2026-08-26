import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

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

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && webBody != null) {
      return webBody!;
    }
    final isDesktopPlatform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);

    final shortestSide = MediaQuery.sizeOf(context).shortestSide;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (isDesktopPlatform) {
          if (constraints.maxWidth >= 1000) {
            return desktopBody;
          } else if (constraints.maxWidth >= 600) {
            return tabletBody;
          } else {
            return mobileBody;
          }
        }

        // On Android / iOS:
        if (shortestSide >= 600) {
          return tabletBody;
        } else {
          return mobileBody;
        }
      },
    );
  }
}
