import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuniq/core/audio/app_audio_handler.dart';
import 'package:tuniq/core/audio/playback_engine.dart';
import 'package:tuniq/core/audio/player_slot.dart';
import 'package:tuniq/features/library/data/artwork_repository.dart';
import 'package:tuniq/features/library/data/device_library_source.dart';
import 'package:tuniq/features/library/data/imported_songs_source.dart';
import 'package:tuniq/features/library/data/library_cache.dart';
import 'package:tuniq/features/library/data/library_repository.dart';
import 'package:tuniq/features/settings/data/settings_repository.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  // Android sees every music file through MediaStore; only iOS needs import.
  final imported = Platform.isIOS ? ImportedSongsSource() : null;
  getIt
    ..registerLazySingleton<SettingsRepository>(
      () => SettingsRepository(SharedPreferencesAsync()),
    )
    ..registerLazySingleton<DeviceLibrarySource>(MethodChannelLibrarySource.forPlatform)
    ..registerLazySingleton<LibraryRepository>(
      () => LibraryRepository(
        getIt<DeviceLibrarySource>(),
        LibraryCache(),
        imported: imported,
      ),
    )
    ..registerLazySingleton<ArtworkRepository>(
      () => ArtworkRepository(getIt<DeviceLibrarySource>(), imported: imported),
    )
    // Phase 6 hands this handler to AudioService.init for system controls.
    ..registerLazySingleton<PlaybackEngine>(
      () => AppAudioHandler(slot: JustAudioSlot()),
      dispose: (engine) => engine.dispose(),
    );
}
