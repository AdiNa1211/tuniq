import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuniq/core/audio/app_audio_handler.dart';
import 'package:tuniq/core/audio/interruptions.dart';
import 'package:tuniq/core/audio/playback_engine.dart';
import 'package:tuniq/core/audio/player_slot.dart';
import 'package:tuniq/features/library/data/artwork_repository.dart';
import 'package:tuniq/features/library/data/device_library_source.dart';
import 'package:tuniq/features/library/data/imported_songs_source.dart';
import 'package:tuniq/features/library/data/library_cache.dart';
import 'package:tuniq/features/library/data/library_repository.dart';
import 'package:tuniq/features/settings/data/settings_repository.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
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
    );

  // Music app behaviour: pause for calls, resume after, pause on unplug.
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  final engine = await AudioService.init(
    builder: () => AppAudioHandler(
      slot: JustAudioSlot(),
      fadeSlot: JustAudioSlot(),
      interruptions: AudioSessionInterruptions(session),
    ),
    config: _audioServiceConfig,
  );
  getIt.registerSingleton<PlaybackEngine>(engine, dispose: (engine) => engine.dispose());
}

/// Media notification, lock screen and headset buttons.
const _audioServiceConfig = AudioServiceConfig(
  androidNotificationChannelId: 'com.nodz.tuniq.playback',
  androidNotificationChannelName: 'Playback',
  androidNotificationChannelDescription: 'What is playing, with playback controls',
  androidNotificationIcon: 'drawable/ic_stat_tuniq',
  // Swipeable only while paused, when the service also leaves the foreground.
  androidNotificationOngoing: true,
  androidStopForegroundOnPause: true,
);
