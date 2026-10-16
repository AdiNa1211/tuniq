import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuniq/core/audio/crossfade.dart';

class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferencesAsync _prefs;

  static const _themeModeKey = 'theme_mode';
  static const _crossfadeEnabledKey = 'crossfade_enabled';
  static const _crossfadeSecondsKey = 'crossfade_seconds';

  Future<ThemeMode> loadThemeMode() async {
    final name = await _prefs.getString(_themeModeKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> saveThemeMode(ThemeMode mode) =>
      _prefs.setString(_themeModeKey, mode.name);

  Future<CrossfadeSettings> loadCrossfade() async => CrossfadeSettings(
        enabled: await _prefs.getBool(_crossfadeEnabledKey) ?? false,
        seconds: await _prefs.getInt(_crossfadeSecondsKey) ??
            CrossfadeSettings.defaultSeconds,
      );

  Future<void> saveCrossfade(CrossfadeSettings settings) async {
    await _prefs.setBool(_crossfadeEnabledKey, settings.enabled);
    await _prefs.setInt(_crossfadeSecondsKey, settings.seconds);
  }
}
