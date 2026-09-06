import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabattal/core/bloc/volume/app_volume_cubit.dart';
import 'package:tabattal/core/services/audio_preferences_service.dart';
import 'package:tabattal/core/widgets/desktop_title_bar.dart';
import 'package:tabattal/core/widgets/desktop_title_bar_volume_control.dart';
import 'package:tabattal/features/settings/presentation/bloc/settings_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'isMaximized') {
          return false;
        }
        return null;
      },
    );
  });

  testWidgets('DesktopTitleBar renders in MaterialApp.builder layout with zero errors and zero overflows',
      (tester) async {
    SharedPreferences.setMockInitialValues({'audio_app_volume': 0.7});
    final prefs = await SharedPreferences.getInstance();
    final audioPrefs = await AudioPreferencesService.create();
    final settingsBloc = SettingsBloc(prefs: prefs);
    final volumeCubit = AppVolumeCubit(audioPrefs: audioPrefs);

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
          BlocProvider<AppVolumeCubit>.value(value: volumeCubit),
        ],
        child: MaterialApp(
          home: const Scaffold(body: Center(child: Text('Home'))),
          builder: (context, child) {
            return Column(
              children: [
                const DesktopTitleBar(),
                Expanded(child: child!),
              ],
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify no exceptions were thrown
    expect(tester.takeException(), isNull);

    // Verify title bar and volume control are rendered
    expect(find.byType(DesktopTitleBar), findsOneWidget);
    expect(find.byType(DesktopTitleBarVolumeControl), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
    expect(find.textContaining('Tabattal'), findsOneWidget);
  });
}
