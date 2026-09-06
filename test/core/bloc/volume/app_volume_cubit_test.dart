import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabattal/core/bloc/volume/app_volume_cubit.dart';
import 'package:tabattal/core/services/audio_preferences_service.dart';

class FakeAudioPlayer extends Fake implements AudioPlayer {
  double currentVolume = -1.0;

  @override
  Future<void> setVolume(double volume) async {
    currentVolume = volume;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AudioPreferencesService prefsService;
  late FakeAudioPlayer fakePlayer;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'audio_app_volume': 0.75,
    });
    prefsService = await AudioPreferencesService.create();
    fakePlayer = FakeAudioPlayer();
  });

  group('AppVolumeCubit', () {
    test('initial state loads volume from preferences', () {
      final cubit = AppVolumeCubit(audioPrefs: prefsService);

      expect(cubit.state.volume, equals(0.75));
      expect(cubit.state.isMuted, isFalse);
      expect(cubit.state.lastNonZeroVolume, equals(0.75));

      cubit.close();
    });

    test('registerPlayer immediately synchronizes player volume', () {
      final cubit = AppVolumeCubit(audioPrefs: prefsService);
      expect(fakePlayer.currentVolume, equals(-1.0));

      cubit.registerPlayer(fakePlayer);
      expect(fakePlayer.currentVolume, equals(0.75));

      cubit.close();
    });

    test('setVolume updates state, registered player, and preferences', () async {
      final cubit = AppVolumeCubit(audioPrefs: prefsService);
      cubit.registerPlayer(fakePlayer);

      await cubit.setVolume(0.4);

      expect(cubit.state.volume, equals(0.4));
      expect(cubit.state.isMuted, isFalse);
      expect(cubit.state.lastNonZeroVolume, equals(0.4));
      expect(fakePlayer.currentVolume, equals(0.4));
      expect(prefsService.volume, equals(0.4));

      cubit.close();
    });

    test('setVolume clamps values between 0.0 and 1.0', () async {
      final cubit = AppVolumeCubit(audioPrefs: prefsService);

      await cubit.setVolume(1.5);
      expect(cubit.state.volume, equals(1.0));

      await cubit.setVolume(-0.5);
      expect(cubit.state.volume, equals(0.0));
      expect(cubit.state.isMuted, isTrue);

      cubit.close();
    });

    test('toggleMute mutes and restores previous non-zero volume', () async {
      final cubit = AppVolumeCubit(audioPrefs: prefsService);
      cubit.registerPlayer(fakePlayer);

      // Current is 0.75. Toggle mute -> 0.0
      await cubit.toggleMute();
      expect(cubit.state.volume, equals(0.0));
      expect(cubit.state.isMuted, isTrue);
      expect(cubit.state.lastNonZeroVolume, equals(0.75));
      expect(fakePlayer.currentVolume, equals(0.0));

      // Toggle unmute -> restores 0.75
      await cubit.toggleMute();
      expect(cubit.state.volume, equals(0.75));
      expect(cubit.state.isMuted, isFalse);
      expect(fakePlayer.currentVolume, equals(0.75));

      cubit.close();
    });

    test('unregisterPlayer stops updating the unregistered player', () async {
      final cubit = AppVolumeCubit(audioPrefs: prefsService);
      cubit.registerPlayer(fakePlayer);
      cubit.unregisterPlayer(fakePlayer);

      await cubit.setVolume(0.2);

      // Player volume should remain at whatever it was when registered (0.75)
      expect(fakePlayer.currentVolume, equals(0.75));
      expect(cubit.state.volume, equals(0.2));

      cubit.close();
    });
  });
}
