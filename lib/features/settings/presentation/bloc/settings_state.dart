import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/mushaf_theme.dart';

class SettingsState extends Equatable {
  final ThemeMode themeMode;
  final MushafTheme mushafTheme;

  const SettingsState({
    required this.themeMode,
    required this.mushafTheme,
  });

  factory SettingsState.initial() {
    return const SettingsState(
      themeMode: ThemeMode.light,
      mushafTheme: MushafTheme.cream,
    );
  }

  // Helper to get the effective Mushaf Theme (handles Dark Mode override)
  MushafTheme get effectiveMushafTheme {
    if (themeMode == ThemeMode.dark) {
      return MushafTheme.dark;
    }
    return mushafTheme;
  }

  SettingsState copyWith({
    ThemeMode? themeMode,
    MushafTheme? mushafTheme,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      mushafTheme: mushafTheme ?? this.mushafTheme,
    );
  }

  @override
  List<Object?> get props => [themeMode, mushafTheme];
}
