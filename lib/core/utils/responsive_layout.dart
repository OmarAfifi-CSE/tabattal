import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobileBody;
  final Widget webBody;

  const ResponsiveLayout({
    super.key,
    required this.mobileBody,
    required this.webBody,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Threshold for web/tablet vs mobile
        if (constraints.maxWidth > 600) {
          return webBody;
        } else {
          return mobileBody;
        }
      },
    );
  }
}
