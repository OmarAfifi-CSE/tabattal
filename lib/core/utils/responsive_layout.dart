import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1000) {
          return desktopBody;
        } else if (constraints.maxWidth >= 600) {
          return tabletBody;
        } else {
          return mobileBody;
        }
      },
    );
  }
}
