import 'package:equatable/equatable.dart';
import '../../../quran_reader/data/models/verse_model.dart';
import '../../domain/entities/video_enums.dart';
import '../../domain/entities/video_theme_preset.dart';

abstract class VideoStudioEvent extends Equatable {
  const VideoStudioEvent();

  @override
  List<Object?> get props => [];
}

class VideoStudioInitRequested extends VideoStudioEvent {
  final int surahNumber;
  final int startAyah;
  final int endAyah;
  final List<VerseModel> verses;

  const VideoStudioInitRequested({
    required this.surahNumber,
    required this.startAyah,
    required this.endAyah,
    required this.verses,
  });

  @override
  List<Object?> get props => [surahNumber, startAyah, endAyah, verses];
}

class VideoStudioReciterChanged extends VideoStudioEvent {
  final String reciterName;
  final String reciterCategory;
  final String reciterPath;

  const VideoStudioReciterChanged({
    required this.reciterName,
    required this.reciterCategory,
    required this.reciterPath,
  });

  @override
  List<Object?> get props => [reciterName, reciterCategory, reciterPath];
}

class VideoStudioVerseRangeChanged extends VideoStudioEvent {
  final int startAyah;
  final int endAyah;
  final List<VerseModel> verses;

  const VideoStudioVerseRangeChanged({
    required this.startAyah,
    required this.endAyah,
    this.verses = const [],
  });

  @override
  List<Object?> get props => [startAyah, endAyah, verses];
}

class VideoStudioAspectRatioChanged extends VideoStudioEvent {
  final VideoAspectRatio aspectRatio;

  const VideoStudioAspectRatioChanged(this.aspectRatio);

  @override
  List<Object?> get props => [aspectRatio];
}

class VideoStudioThemeChanged extends VideoStudioEvent {
  final VideoThemePreset theme;

  const VideoStudioThemeChanged(this.theme);

  @override
  List<Object?> get props => [theme];
}

class VideoStudioBackgroundTypeChanged extends VideoStudioEvent {
  final VideoBackgroundType backgroundType;

  const VideoStudioBackgroundTypeChanged(this.backgroundType);

  @override
  List<Object?> get props => [backgroundType];
}

class VideoStudioCustomImageSelected extends VideoStudioEvent {
  final String? imagePath;

  const VideoStudioCustomImageSelected(this.imagePath);

  @override
  List<Object?> get props => [imagePath];
}

class VideoStudioDimmingChanged extends VideoStudioEvent {
  final double dimming;

  const VideoStudioDimmingChanged(this.dimming);

  @override
  List<Object?> get props => [dimming];
}

class VideoStudioTextStyleChanged extends VideoStudioEvent {
  final VideoTextStyle textStyle;

  const VideoStudioTextStyleChanged(this.textStyle);

  @override
  List<Object?> get props => [textStyle];
}

class VideoStudioOptionToggled extends VideoStudioEvent {
  final bool? showSurahBadge;
  final bool? showReciterName;
  final bool? showTafsir;
  final bool? showEnglishTranslation;
  final bool? showAudioWaveform;

  const VideoStudioOptionToggled({
    this.showSurahBadge,
    this.showReciterName,
    this.showTafsir,
    this.showEnglishTranslation,
    this.showAudioWaveform,
  });

  @override
  List<Object?> get props => [
        showSurahBadge,
        showReciterName,
        showTafsir,
        showEnglishTranslation,
        showAudioWaveform,
      ];
}

class VideoStudioPlaybackToggled extends VideoStudioEvent {
  const VideoStudioPlaybackToggled();
}

class VideoStudioPlaybackStateChanged extends VideoStudioEvent {
  final bool isPlaying;

  const VideoStudioPlaybackStateChanged(this.isPlaying);

  @override
  List<Object?> get props => [isPlaying];
}

class VideoStudioActiveVerseIndexChanged extends VideoStudioEvent {
  final int activeIndex;

  const VideoStudioActiveVerseIndexChanged(this.activeIndex);

  @override
  List<Object?> get props => [activeIndex];
}

class VideoStudioQualityChanged extends VideoStudioEvent {
  final VideoQuality quality;

  const VideoStudioQualityChanged(this.quality);

  @override
  List<Object?> get props => [quality];
}

class VideoStudioExportStarted extends VideoStudioEvent {
  final VideoExportAction action;

  const VideoStudioExportStarted({this.action = VideoExportAction.saveToGallery});

  @override
  List<Object?> get props => [action];
}

class VideoStudioExportCancelled extends VideoStudioEvent {
  const VideoStudioExportCancelled();
}
