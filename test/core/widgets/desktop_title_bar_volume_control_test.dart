import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabattal/core/bloc/volume/app_volume_cubit.dart';
import 'package:tabattal/core/services/audio_preferences_service.dart';
import 'package:tabattal/core/widgets/desktop_title_bar_volume_control.dart';
import 'package:tabattal/features/settings/presentation/bloc/settings_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DesktopTitleBarVolumeControl renders without Overlay and handles mute toggle', (tester) async {
    SharedPreferences.setMockInitialValues({'audio_app_volume': 0.8});
    final prefs = await SharedPreferences.getInstance();
    final audioPrefs = await AudioPreferencesService.create();
    final settingsBloc = SettingsBloc(prefs: prefs);
    final volumeCubit = AppVolumeCubit(audioPrefs: audioPrefs);

    // Build directly inside Directionality + Material without Overlay or Navigator
    // to simulate DesktopTitleBar in MaterialApp.builder
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
          BlocProvider<AppVolumeCubit>.value(value: volumeCubit),
        ],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            child: SizedBox(
              width: 800,
              height: 38,
              child: Row(
                children: [
                  Text('Branding'),
                  Expanded(child: SizedBox()),
                  DesktopTitleBarVolumeControl(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 46, height: 38),
                      SizedBox(width: 46, height: 38),
                      SizedBox(width: 46, height: 38),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Must be ZERO exceptions thrown!
    final exception = tester.takeException();
    expect(exception, isNull);

    // Verify UI elements
    expect(find.byType(DesktopTitleBarVolumeControl), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('80%'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    // Tap mute icon
    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pumpAndSettle();

    expect(find.text('0%'), findsOneWidget);
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    expect(volumeCubit.state.isMuted, isTrue);

    // Tap again to unmute
    await tester.tap(find.byIcon(Icons.volume_off_rounded));
    await tester.pumpAndSettle();

    expect(find.text('80%'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(volumeCubit.state.isMuted, isFalse);

    // Tap on micro-slider at 50% width
    final sliderFinder = find.byType(CustomPaint).first;
    await tester.tapAt(tester.getCenter(sliderFinder));
    await tester.pumpAndSettle();

    expect(volumeCubit.state.volume, closeTo(0.5, 0.05));
    expect(find.text('50%'), findsOneWidget);

    // Ensure zero overflow errors
    expect(tester.takeException(), isNull);
  });

  testWidgets('DesktopTitleBarVolumeControl handles drag and clamping', (tester) async {
    SharedPreferences.setMockInitialValues({'audio_app_volume': 0.5});
    final prefs = await SharedPreferences.getInstance();
    final audioPrefs = await AudioPreferencesService.create();
    final settingsBloc = SettingsBloc(prefs: prefs);
    final volumeCubit = AppVolumeCubit(audioPrefs: audioPrefs);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
          BlocProvider<AppVolumeCubit>.value(value: volumeCubit),
        ],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            child: DesktopTitleBarVolumeControl(),
          ),
        ),
      ),
    );

    final sliderFinder = find.byType(CustomPaint).first;

    // Drag far right beyond 100%
    await tester.drag(sliderFinder, const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(volumeCubit.state.volume, equals(1.0));
    expect(find.text('100%'), findsOneWidget);

    // Drag far left below 0%
    await tester.drag(sliderFinder, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(volumeCubit.state.volume, equals(0.0));
    expect(find.text('0%'), findsOneWidget);
    expect(volumeCubit.state.isMuted, isTrue);

    expect(tester.takeException(), isNull);
  });

  testWidgets('DesktopTitleBarVolumeControl handles mouse scroll wheel signal', (tester) async {
    SharedPreferences.setMockInitialValues({'audio_app_volume': 0.5});
    final prefs = await SharedPreferences.getInstance();
    final audioPrefs = await AudioPreferencesService.create();
    final settingsBloc = SettingsBloc(prefs: prefs);
    final volumeCubit = AppVolumeCubit(audioPrefs: audioPrefs);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
          BlocProvider<AppVolumeCubit>.value(value: volumeCubit),
        ],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            child: DesktopTitleBarVolumeControl(),
          ),
        ),
      ),
    );

    final controlFinder = find.byType(DesktopTitleBarVolumeControl);

    // Scroll up (negative dy) -> increases volume by 0.05
    final center = tester.getCenter(controlFinder);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -20)));
    await tester.pumpAndSettle();

    expect(volumeCubit.state.volume, closeTo(0.55, 0.001));

    // Scroll down (positive dy) -> decreases volume by 0.05
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 20)));
    await tester.pumpAndSettle();

    expect(volumeCubit.state.volume, closeTo(0.50, 0.001));
    expect(tester.takeException(), isNull);
  });
}
