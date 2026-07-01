import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/audio_preferences_service.dart';

/// Manages the app-wide locale, persisting it between sessions.
class LocaleCubit extends Cubit<Locale> {
  final AudioPreferencesService _prefs;

  LocaleCubit(this._prefs) : super(Locale(_prefs.appLocale));

  void setLocale(String languageCode) {
    _prefs.saveAppLocale(languageCode);
    emit(Locale(languageCode));
  }

  bool get isArabic => state.languageCode == 'ar';
}
