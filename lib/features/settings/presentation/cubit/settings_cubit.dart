import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tuniq/core/audio/crossfade.dart';
import 'package:tuniq/features/settings/data/settings_repository.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.crossfade = const CrossfadeSettings(),
  });

  final ThemeMode themeMode;
  final CrossfadeSettings crossfade;

  SettingsState copyWith({ThemeMode? themeMode, CrossfadeSettings? crossfade}) =>
      SettingsState(
        themeMode: themeMode ?? this.themeMode,
        crossfade: crossfade ?? this.crossfade,
      );

  @override
  List<Object?> get props => [themeMode, crossfade];
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._repository) : super(const SettingsState());

  final SettingsRepository _repository;

  Future<void> load() async {
    final themeMode = await _repository.loadThemeMode();
    final crossfade = await _repository.loadCrossfade();
    if (isClosed) return;
    emit(state.copyWith(themeMode: themeMode, crossfade: crossfade));
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    emit(state.copyWith(themeMode: themeMode));
    await _repository.saveThemeMode(themeMode);
  }

  Future<void> setCrossfadeEnabled(bool enabled) =>
      _setCrossfade(state.crossfade.copyWith(enabled: enabled));

  Future<void> setCrossfadeSeconds(int seconds) =>
      _setCrossfade(state.crossfade.copyWith(seconds: seconds));

  Future<void> _setCrossfade(CrossfadeSettings crossfade) async {
    if (crossfade == state.crossfade) return;
    emit(state.copyWith(crossfade: crossfade));
    await _repository.saveCrossfade(crossfade);
  }
}
