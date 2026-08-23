import 'package:equatable/equatable.dart';
import '../../../../core/constants/reciter_catalog.dart';
import 'video_enums.dart';
import 'video_theme_preset.dart';

class VideoProjectConfig extends Equatable {
  final int surahNumber;
  final int startAyah;
  final int endAyah;
  final String reciterName;
  final String reciterCategory;
  final String reciterPath;
  final VideoAspectRatio aspectRatio;
  final VideoBackgroundType backgroundType;
  final VideoThemePreset themePreset;
  final String? customImagePath;
  final double backgroundDimming;
  final bool showSurahBadge;
  final bool showReciterName;
  final bool showCardFrame;
  final bool showTafsir;
  final bool showEnglishTranslation;
  final bool showAudioWaveform;
  final VideoTextStyle textStyle;
  final VideoQuality videoQuality;
  final VideoTextDisplayMode textDisplayMode;
  final bool isEnglish;

  const VideoProjectConfig({
    required this.surahNumber,
    required this.startAyah,
    required this.endAyah,
    this.reciterName = ReciterCatalog.defaultReciter,
    this.reciterCategory = ReciterCatalog.defaultCategory,
    this.reciterPath = ReciterCatalog.defaultReciterPath,
    this.aspectRatio = VideoAspectRatio.portrait9x16,
    this.backgroundType = VideoBackgroundType.gradient,
    this.themePreset = VideoThemePreset.cream,
    this.customImagePath,
    this.backgroundDimming = 0.35,
    this.showSurahBadge = true,
    this.showReciterName = true,
    this.showCardFrame = true,
    this.showTafsir = false,
    this.showEnglishTranslation = false,
    this.showAudioWaveform = true,
    this.textStyle = VideoTextStyle.modernCentered,
    this.videoQuality = VideoQuality.fhd1080p,
    this.textDisplayMode = VideoTextDisplayMode.lineByLine,
    this.isEnglish = false,
  });

  int get totalAyahsCount => (endAyah - startAyah + 1).clamp(1, 20);

  VideoProjectConfig copyWith({
    int? surahNumber,
    int? startAyah,
    int? endAyah,
    String? reciterName,
    String? reciterCategory,
    String? reciterPath,
    VideoAspectRatio? aspectRatio,
    VideoBackgroundType? backgroundType,
    VideoThemePreset? themePreset,
    String? customImagePath,
    bool clearCustomImage = false,
    double? backgroundDimming,
    bool? showSurahBadge,
    bool? showReciterName,
    bool? showCardFrame,
    bool? showTafsir,
    bool? showEnglishTranslation,
    bool? showAudioWaveform,
    VideoTextStyle? textStyle,
    VideoQuality? videoQuality,
    VideoTextDisplayMode? textDisplayMode,
    bool? isEnglish,
  }) {
    return VideoProjectConfig(
      surahNumber: surahNumber ?? this.surahNumber,
      startAyah: startAyah ?? this.startAyah,
      endAyah: endAyah ?? this.endAyah,
      reciterName: reciterName ?? this.reciterName,
      reciterCategory: reciterCategory ?? this.reciterCategory,
      reciterPath: reciterPath ?? this.reciterPath,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      backgroundType: backgroundType ?? this.backgroundType,
      themePreset: themePreset ?? this.themePreset,
      customImagePath:
          clearCustomImage ? null : (customImagePath ?? this.customImagePath),
      backgroundDimming: backgroundDimming ?? this.backgroundDimming,
      showSurahBadge: showSurahBadge ?? this.showSurahBadge,
      showReciterName: showReciterName ?? this.showReciterName,
      showCardFrame: showCardFrame ?? this.showCardFrame,
      showTafsir: showTafsir ?? this.showTafsir,
      showEnglishTranslation:
          showEnglishTranslation ?? this.showEnglishTranslation,
      showAudioWaveform: showAudioWaveform ?? this.showAudioWaveform,
      textStyle: textStyle ?? this.textStyle,
      videoQuality: videoQuality ?? this.videoQuality,
      textDisplayMode: textDisplayMode ?? this.textDisplayMode,
      isEnglish: isEnglish ?? this.isEnglish,
    );
  }

  @override
  List<Object?> get props => [
        surahNumber,
        startAyah,
        endAyah,
        reciterName,
        reciterCategory,
        reciterPath,
        aspectRatio,
        backgroundType,
        themePreset,
        customImagePath,
        backgroundDimming,
        showSurahBadge,
        showReciterName,
        showCardFrame,
        showTafsir,
        showEnglishTranslation,
        showAudioWaveform,
        textStyle,
        videoQuality,
        textDisplayMode,
        isEnglish,
      ];
}
