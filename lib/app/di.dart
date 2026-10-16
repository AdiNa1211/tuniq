import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuniq/features/settings/data/settings_repository.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepository(SharedPreferencesAsync()),
  );
}
