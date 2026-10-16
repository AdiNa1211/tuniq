import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tuniq/core/audio/crossfade.dart';
import 'package:tuniq/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:tuniq/features/settings/presentation/settings_page.dart';

import '../../helpers/mocks.dart';

void main() {
  late MockSettingsRepository repository;
  late SettingsCubit cubit;

  setUpAll(registerSettingsFallbacks);

  setUp(() {
    repository = defaultSettingsRepository();
    cubit = SettingsCubit(repository);
  });

  tearDown(() => cubit.close());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('SettingsPage crossfade', () {
    testWidgets('is off, with the length hidden', (tester) async {
      await pumpPage(tester);
      final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.value, isFalse);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('turning it on shows the length and saves', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.text('Crossfade'));
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('6 s'), findsOneWidget);
      verify(() => repository.saveCrossfade(const CrossfadeSettings(enabled: true))).called(1);
    });

    testWidgets('dragging the slider to the end picks 12 seconds', (tester) async {
      await cubit.setCrossfadeEnabled(true);
      await pumpPage(tester);
      await tester.drag(find.byType(Slider), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(cubit.state.crossfade.seconds, 12);
      expect(find.text('12 s'), findsOneWidget);
    });
  });
}
