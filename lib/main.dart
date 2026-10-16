import 'package:flutter/material.dart';
import 'package:tuniq/app/app.dart';
import 'package:tuniq/app/di.dart';
import 'package:tuniq/features/settings/data/settings_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  runApp(TuniqApp(settingsRepository: getIt<SettingsRepository>()));
}
