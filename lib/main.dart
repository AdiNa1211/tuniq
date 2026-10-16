import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:tuniq/app/app.dart';
import 'package:tuniq/app/di.dart';
import 'package:tuniq/core/audio/playback_engine.dart';
import 'package:tuniq/features/library/data/artwork_repository.dart';
import 'package:tuniq/features/library/data/library_repository.dart';
import 'package:tuniq/features/settings/data/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Music app behaviour: pause for calls, duck under navigation prompts.
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  configureDependencies();
  runApp(
    TuniqApp(
      settingsRepository: getIt<SettingsRepository>(),
      libraryRepository: getIt<LibraryRepository>(),
      artworkRepository: getIt<ArtworkRepository>(),
      engine: getIt<PlaybackEngine>(),
    ),
  );
}
