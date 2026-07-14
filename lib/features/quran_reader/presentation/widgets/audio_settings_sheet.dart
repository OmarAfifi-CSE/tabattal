import 'package:flutter/material.dart';
import 'mobile/audio_settings_sheet_mobile.dart';
import 'tablet/audio_settings_sheet_tablet.dart';
import 'desktop/audio_settings_sheet_desktop.dart';

void showAudioSettingsSheet(BuildContext context, {int? verseId}) {
  final w = MediaQuery.sizeOf(context).width;
  if (w > 1000) {
    showAudioSettingsSheetDesktop(context, verseId: verseId);
  } else if (w > 600) {
    showAudioSettingsSheetTablet(context, verseId: verseId);
  } else {
    showAudioSettingsSheetMobile(context, verseId: verseId);
  }
}
