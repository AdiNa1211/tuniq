import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuniq/features/library/data/device_library_source.dart';
import 'package:tuniq/features/library/data/library_repository.dart';
import 'package:tuniq/features/settings/data/settings_repository.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  getIt
    ..registerLazySingleton<SettingsRepository>(
      () => SettingsRepository(SharedPreferencesAsync()),
    )
    ..registerLazySingleton<DeviceLibrarySource>(MethodChannelLibrarySource.forPlatform)
    ..registerLazySingleton<LibraryRepository>(
      () => LibraryRepository(getIt<DeviceLibrarySource>()),
    );
}
