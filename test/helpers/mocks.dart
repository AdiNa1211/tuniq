import 'package:mocktail/mocktail.dart';
import 'package:tuniq/features/library/data/library_repository.dart';
import 'package:tuniq/features/settings/data/settings_repository.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockLibraryRepository extends Mock implements LibraryRepository {}
