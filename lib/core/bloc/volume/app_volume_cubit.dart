import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/audio_preferences_service.dart';
import 'app_volume_state.dart';

class AppVolumeCubit extends Cubit<AppVolumeState> {
  final AudioPreferencesService _audioPrefs;
  final Set<AudioPlayer> _registeredPlayers = {};

  AppVolumeCubit({
    required AudioPreferencesService audioPrefs,
  })  : _audioPrefs = audioPrefs,
        super(AppVolumeState.initial(initialVolume: audioPrefs.volume));

  /// Registers an active [AudioPlayer] instance to receive volume changes.
  /// Immediately synchronizes the player to the current application volume.
  void registerPlayer(AudioPlayer player) {
    if (_registeredPlayers.add(player)) {
      try {
        player.setVolume(state.volume);
      } catch (_) {
        // Player may be disposing or in an invalid state.
      }
    }
  }

  /// Unregisters an [AudioPlayer] instance when disposed or no longer active.
  void unregisterPlayer(AudioPlayer player) {
    _registeredPlayers.remove(player);
  }

  /// Sets the application playback volume in the range [0.0, 1.0].
  Future<void> setVolume(double newVolume) async {
    final clamped = newVolume.clamp(0.0, 1.0);
    final isMuted = clamped == 0.0;
    final lastNonZero = clamped > 0.0 ? clamped : state.lastNonZeroVolume;

    emit(state.copyWith(
      volume: clamped,
      isMuted: isMuted,
      lastNonZeroVolume: lastNonZero,
    ));

    final playersSnapshot = List<AudioPlayer>.of(_registeredPlayers);
    for (final player in playersSnapshot) {
      try {
        await player.setVolume(clamped);
      } catch (_) {
        // Player may be disposing or in an invalid state.
      }
    }

    await _audioPrefs.saveVolume(clamped);
  }

  /// Toggles between mute (0.0) and the previous non-zero volume.
  Future<void> toggleMute() async {
    if (state.isMuted || state.volume == 0.0) {
      final restore = state.lastNonZeroVolume > 0.0 ? state.lastNonZeroVolume : 1.0;
      await setVolume(restore);
    } else {
      await setVolume(0.0);
    }
  }

  @override
  Future<void> close() {
    _registeredPlayers.clear();
    return super.close();
  }
}
