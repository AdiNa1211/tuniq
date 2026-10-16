import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tuniq/core/audio/crossfade.dart';
import 'package:tuniq/features/settings/presentation/cubit/settings_cubit.dart';

import '../../helpers/mocks.dart';

void main() {
  late MockSettingsRepository repository;

  setUpAll(registerSettingsFallbacks);

  setUp(() => repository = defaultSettingsRepository());

  group('SettingsCubit', () {
    blocTest<SettingsCubit, SettingsState>(
      'load emits the saved theme and crossfade',
      setUp: () {
        when(() => repository.loadThemeMode()).thenAnswer((_) async => ThemeMode.dark);
        when(() => repository.loadCrossfade())
            .thenAnswer((_) async => const CrossfadeSettings(enabled: true, seconds: 9));
      },
      build: () => SettingsCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        const SettingsState(
          themeMode: ThemeMode.dark,
          crossfade: CrossfadeSettings(enabled: true, seconds: 9),
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'load emits nothing when everything is the default',
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

    blocTest<SettingsCubit, SettingsState>(
      'crossfade is off by default and can be turned on',
      build: () => SettingsCubit(repository),
      act: (cubit) => cubit.setCrossfadeEnabled(true),
      expect: () => [
        const SettingsState(crossfade: CrossfadeSettings(enabled: true)),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'setCrossfadeSeconds saves the length, ignoring repeats',
      build: () => SettingsCubit(repository),
      act: (cubit) async {
        await cubit.setCrossfadeSeconds(10);
        await cubit.setCrossfadeSeconds(10);
      },
      expect: () => [const SettingsState(crossfade: CrossfadeSettings(seconds: 10))],
      verify: (_) => verify(
        () => repository.saveCrossfade(const CrossfadeSettings(seconds: 10)),
      ).called(1),
    );
  });

  group('CrossfadeSettings', () {
    test('defaults to off, 6 seconds', () {
      const settings = CrossfadeSettings();
      expect(settings.enabled, isFalse);
      expect(settings.duration, const Duration(seconds: 6));
    });

    test('keeps the length between 1 and 12 seconds', () {
      expect(const CrossfadeSettings(seconds: 0).seconds, 1);
      expect(const CrossfadeSettings(seconds: 30).seconds, 12);
    });
  });

  group('crossfadeVolumes', () {
    test('starts on the outgoing song and ends on the incoming one', () {
      expect(crossfadeVolumes(0), (1.0, 0.0));
      final (outgoing, incoming) = crossfadeVolumes(1);
      expect(outgoing, closeTo(0, 1e-9));
      expect(incoming, 1);
    });

    test('keeps the combined power steady', () {
      for (final t in [0.1, 0.25, 0.5, 0.9]) {
        final (a, b) = crossfadeVolumes(t);
        expect(a * a + b * b, closeTo(1, 1e-9));
      }
      final (a, b) = crossfadeVolumes(0.5);
      expect(a, closeTo(b, 1e-9));
    });

    test('clamps progress outside 0 to 1', () {
      expect(crossfadeVolumes(-1), crossfadeVolumes(0));
      expect(crossfadeVolumes(2), crossfadeVolumes(1));
    });
  });
}
