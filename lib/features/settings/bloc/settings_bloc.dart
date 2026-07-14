import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/mushaf_theme.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SharedPreferences prefs;

  static const String _themeModeKey = 'settings_theme_mode';
  static const String _mushafThemeKey = 'settings_mushaf_theme';
  static const String _scrollDirectionKey = 'settings_scroll_direction';

  SettingsBloc({required this.prefs}) : super(SettingsState.initial()) {
    on<LoadSettings>(_onLoadSettings);
    on<ToggleThemeMode>(_onToggleThemeMode);
    on<ChangeMushafTheme>(_onChangeMushafTheme);
    on<ChangeScrollDirection>(_onChangeScrollDirection);

    add(LoadSettings());
  }

  void _onLoadSettings(LoadSettings event, Emitter<SettingsState> emit) {
    final themeModeStr = prefs.getString(_themeModeKey) ?? 'light';
    final themeMode = themeModeStr == 'dark' ? ThemeMode.dark : ThemeMode.light;

    final mushafThemeId = prefs.getString(_mushafThemeKey) ?? MushafTheme.cream.id;
    final mushafTheme = MushafTheme.fromId(mushafThemeId);

    final scrollStr = prefs.getString(_scrollDirectionKey) ?? 'horizontal';
    final scrollDirection = scrollStr == 'vertical' ? Axis.vertical : Axis.horizontal;

    emit(state.copyWith(
      themeMode: themeMode,
      mushafTheme: mushafTheme,
      scrollDirection: scrollDirection,
    ));
  }

  void _onToggleThemeMode(ToggleThemeMode event, Emitter<SettingsState> emit) async {
    final modeStr = event.themeMode == ThemeMode.dark ? 'dark' : 'light';
    await prefs.setString(_themeModeKey, modeStr);
    emit(state.copyWith(themeMode: event.themeMode));
  }

  void _onChangeMushafTheme(ChangeMushafTheme event, Emitter<SettingsState> emit) async {
    await prefs.setString(_mushafThemeKey, event.themeId);
    final newTheme = MushafTheme.fromId(event.themeId);
    emit(state.copyWith(mushafTheme: newTheme));
  }

  void _onChangeScrollDirection(ChangeScrollDirection event, Emitter<SettingsState> emit) async {
    final str = event.direction == Axis.vertical ? 'vertical' : 'horizontal';
    await prefs.setString(_scrollDirectionKey, str);
    emit(state.copyWith(scrollDirection: event.direction));
  }
}

