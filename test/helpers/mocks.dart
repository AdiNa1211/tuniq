import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tuniq/core/audio/crossfade.dart';
import 'package:tuniq/features/library/data/artwork_repository.dart';
import 'package:tuniq/features/library/data/device_library_source.dart';
import 'package:tuniq/features/library/data/library_repository.dart';
import 'package:tuniq/features/library/domain/song.dart';
import 'package:tuniq/features/settings/data/settings_repository.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockLibraryRepository extends Mock implements LibraryRepository {}

class MockDeviceLibrarySource extends Mock implements DeviceLibrarySource {}

class _NoArtworkSource extends Fake implements DeviceLibrarySource {
  @override
  Future<Uint8List?> fetchArtwork(Song song, {required int sizePx}) async => null;
}

/// Artwork cache that always falls back to the placeholder.
ArtworkRepository noArtworkRepository() => ArtworkRepository(_NoArtworkSource());

/// Stubs every settings call with the defaults.
MockSettingsRepository defaultSettingsRepository() {
  final repository = MockSettingsRepository();
  when(() => repository.loadThemeMode()).thenAnswer((_) async => ThemeMode.system);
  when(() => repository.saveThemeMode(any())).thenAnswer((_) async {});
  when(() => repository.loadCrossfade()).thenAnswer((_) async => const CrossfadeSettings());
  when(() => repository.saveCrossfade(any())).thenAnswer((_) async {});
  return repository;
}

void registerSettingsFallbacks() {
  registerFallbackValue(ThemeMode.system);
  registerFallbackValue(const CrossfadeSettings());
}
