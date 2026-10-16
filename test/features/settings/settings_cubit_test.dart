import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tuniq/features/settings/presentation/cubit/settings_cubit.dart';

import '../../helpers/mocks.dart';

void main() {
  late MockSettingsRepository repository;

  setUpAll(() => registerFallbackValue(ThemeMode.system));

  setUp(() {
    repository = MockSettingsRepository();
    when(() => repository.saveThemeMode(any())).thenAnswer((_) async {});
  });

  group('SettingsCubit', () {
    blocTest<SettingsCubit, SettingsState>(
      'load emits the saved theme',
      setUp: () => when(() => repository.loadThemeMode())
          .thenAnswer((_) async => ThemeMode.dark),
      build: () => SettingsCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => [const SettingsState(themeMode: ThemeMode.dark)],
    );

    blocTest<SettingsCubit, SettingsState>(
      'load emits nothing when the saved theme is the default',
      setUp: () => when(() => repository.loadThemeMode())
          .thenAnswer((_) async => ThemeMode.system),
      build: () => SettingsCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => <SettingsState>[],
    );

    blocTest<SettingsCubit, SettingsState>(
      'setThemeMode emits and saves the theme',
      build: () => SettingsCubit(repository),
      act: (cubit) => cubit.setThemeMode(ThemeMode.light),
      expect: () => [const SettingsState(themeMode: ThemeMode.light)],
      verify: (_) => verify(() => repository.saveThemeMode(ThemeMode.light)).called(1),
    );
  });
}
