import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class ToggleThemeMode extends SettingsEvent {
  final ThemeMode themeMode;
  const ToggleThemeMode(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}

class ChangeMushafTheme extends SettingsEvent {
  final String themeId;
  const ChangeMushafTheme(this.themeId);

  @override
  List<Object?> get props => [themeId];
}

class LoadSettings extends SettingsEvent {}
