enum VideoAspectRatio {
  portrait9x16,
  square1x1,
  landscape16x9;

  double get ratio {
    switch (this) {
      case VideoAspectRatio.portrait9x16:
        return 9 / 16;
      case VideoAspectRatio.square1x1:
        return 1.0;
      case VideoAspectRatio.landscape16x9:
        return 16 / 9;
    }
  }

  int get targetWidth {
    switch (this) {
      case VideoAspectRatio.portrait9x16:
        return 1080;
      case VideoAspectRatio.square1x1:
        return 1080;
      case VideoAspectRatio.landscape16x9:
        return 1920;
    }
  }

  int get targetHeight {
    switch (this) {
      case VideoAspectRatio.portrait9x16:
        return 1920;
      case VideoAspectRatio.square1x1:
        return 1080;
      case VideoAspectRatio.landscape16x9:
        return 1080;
    }
  }

  int getTargetWidth([VideoQuality quality = VideoQuality.fhd1080p]) {
    final scale = quality == VideoQuality.uhd4k ? 2.0 : (quality == VideoQuality.hd720p ? 0.6667 : 1.0);
    return ((targetWidth * scale).round() ~/ 2) * 2;
  }

  int getTargetHeight([VideoQuality quality = VideoQuality.fhd1080p]) {
    final scale = quality == VideoQuality.uhd4k ? 2.0 : (quality == VideoQuality.hd720p ? 0.6667 : 1.0);
    return ((targetHeight * scale).round() ~/ 2) * 2;
  }

  String get label {
    switch (this) {
      case VideoAspectRatio.portrait9x16:
        return '9:16 (Story / Reel)';
      case VideoAspectRatio.square1x1:
        return '1:1 (Post)';
      case VideoAspectRatio.landscape16x9:
        return '16:9 (Landscape)';
    }
  }

  String get shortLabel {
    switch (this) {
      case VideoAspectRatio.portrait9x16:
        return '9:16';
      case VideoAspectRatio.square1x1:
        return '1:1';
      case VideoAspectRatio.landscape16x9:
        return '16:9';
    }
  }
}

enum VideoQuality {
  fhd1080p,
  hd720p,
  uhd4k;

  String get label {
    switch (this) {
      case VideoQuality.fhd1080p:
        return '1080p (عالية الدقة FHD)';
      case VideoQuality.hd720p:
        return '720p (سريعة HD)';
      case VideoQuality.uhd4k:
        return '4K (فائقة الدقة 4K)';
    }
  }

  String get shortLabel {
    switch (this) {
      case VideoQuality.fhd1080p:
        return '1080p';
      case VideoQuality.hd720p:
        return '720p';
      case VideoQuality.uhd4k:
        return '4K';
    }
  }

  int get bitrateKbps {
    switch (this) {
      case VideoQuality.fhd1080p:
        return 12000;
      case VideoQuality.hd720p:
        return 6000;
      case VideoQuality.uhd4k:
        return 24000;
    }
  }

  int get maxrateKbps {
    switch (this) {
      case VideoQuality.fhd1080p:
        return 16000;
      case VideoQuality.hd720p:
        return 8000;
      case VideoQuality.uhd4k:
        return 32000;
    }
  }

  int get bufsizeKbps {
    switch (this) {
      case VideoQuality.fhd1080p:
        return 24000;
      case VideoQuality.hd720p:
        return 12000;
      case VideoQuality.uhd4k:
        return 48000;
    }
  }

  int get qscale {
    switch (this) {
      case VideoQuality.fhd1080p:
        return 1;
      case VideoQuality.hd720p:
        return 2;
      case VideoQuality.uhd4k:
        return 1;
    }
  }

  int get crf {
    switch (this) {
      case VideoQuality.fhd1080p:
        return 22;
      case VideoQuality.hd720p:
        return 24;
      case VideoQuality.uhd4k:
        return 20;
    }
  }
}

enum VideoBackgroundType {
  gradient,
  solid,
  ambientLoop,
  customImage;
}

enum VideoTextStyle {
  modernCentered,
  framedCard,
  minimalKinetic;

  String get labelArabic {
    switch (this) {
      case VideoTextStyle.modernCentered:
        return 'عصري متمركز';
      case VideoTextStyle.framedCard:
        return 'بطاقة إسلامية مؤطرة';
      case VideoTextStyle.minimalKinetic:
        return 'سرد حركي هادئ';
    }
  }

  String get labelEnglish {
    switch (this) {
      case VideoTextStyle.modernCentered:
        return 'Modern Centered';
      case VideoTextStyle.framedCard:
        return 'Framed Islamic Card';
      case VideoTextStyle.minimalKinetic:
        return 'Minimal Kinetic';
    }
  }
}

enum VideoRenderPhase {
  idle,
  downloadingAudio,
  generatingOverlays,
  encodingVideo,
  completed,
  failed,
  cancelled;
}

enum VideoExportAction {
  saveToGallery,
  share;
}

enum VideoTextDisplayMode {
  lineByLine,
  staticFull;

  String get labelArabic {
    switch (this) {
      case VideoTextDisplayMode.lineByLine:
        return 'سطر بسطر';
      case VideoTextDisplayMode.staticFull:
        return 'الآية كاملة';
    }
  }

  String get labelEnglish {
    switch (this) {
      case VideoTextDisplayMode.lineByLine:
        return 'Line by Line';
      case VideoTextDisplayMode.staticFull:
        return 'Full Ayah';
    }
  }
}

