import 'package:equatable/equatable.dart';

class AppVolumeState extends Equatable {
  final double volume; // 0.0 to 1.0
  final bool isMuted;
  final double lastNonZeroVolume;

  const AppVolumeState({
    required this.volume,
    required this.isMuted,
    required this.lastNonZeroVolume,
  });

  const AppVolumeState.initial({double initialVolume = 1.0})
      : volume = initialVolume,
        isMuted = initialVolume == 0.0,
        lastNonZeroVolume = initialVolume > 0.0 ? initialVolume : 1.0;

  AppVolumeState copyWith({
    double? volume,
    bool? isMuted,
    double? lastNonZeroVolume,
  }) {
    return AppVolumeState(
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      lastNonZeroVolume: lastNonZeroVolume ?? this.lastNonZeroVolume,
    );
  }

  @override
  List<Object?> get props => [volume, isMuted, lastNonZeroVolume];
}
