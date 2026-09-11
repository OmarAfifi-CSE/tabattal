import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabattal/core/utils/responsive_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  Widget buildTestWidget({Widget? webBody}) {
    return MaterialApp(
      home: Scaffold(
        body: ResponsiveLayout(
          mobileBody: const Text('MobileView'),
          tabletBody: const Text('TabletView'),
          desktopBody: const Text('DesktopView'),
          webBody: webBody,
        ),
      ),
    );
  }

  group('ResponsiveLayout routing', () {
    testWidgets(
        'routes to mobileBody when width < 600 dp on mobile/tablet platforms',
        (tester) async {
      tester.view.physicalSize = const Size(412, 917);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('MobileView'), findsOneWidget);
      expect(find.text('TabletView'), findsNothing);
      expect(find.text('DesktopView'), findsNothing);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
        'routes to tabletBody when width >= 600 dp on Android/iOS platforms',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('TabletView'), findsOneWidget);
      expect(find.text('MobileView'), findsNothing);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
        'routes to desktopBody on Desktop platform when width >= 1100 dp',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('DesktopView'), findsOneWidget);
      expect(find.text('TabletView'), findsNothing);
      expect(find.text('MobileView'), findsNothing);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
        'routes to tabletBody on Desktop platform when 600 <= width < 1100 dp',
        (tester) async {
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('TabletView'), findsOneWidget);
      expect(find.text('DesktopView'), findsNothing);
      expect(find.text('MobileView'), findsNothing);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
        'routes to mobileBody on Desktop platform when window width < 500 dp',
        (tester) async {
      tester.view.physicalSize = const Size(480, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('MobileView'), findsOneWidget);
      expect(find.text('TabletView'), findsNothing);
      expect(find.text('DesktopView'), findsNothing);

      debugDefaultTargetPlatformOverride = null;
    });
  });
}
