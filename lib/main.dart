import 'package:flutter/material.dart';
import 'package:tuniq/app/app.dart';
import 'package:tuniq/app/di.dart';
import 'package:tuniq/core/audio/playback_engine.dart';
import 'package:tuniq/features/library/data/artwork_repository.dart';
import 'package:tuniq/features/library/data/library_repository.dart';
import 'package:tuniq/features/settings/data/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(
    TuniqApp(
      settingsRepository: getIt<SettingsRepository>(),
      libraryRepository: getIt<LibraryRepository>(),
      artworkRepository: getIt<ArtworkRepository>(),
      engine: getIt<PlaybackEngine>(),
    ),
  );
}
