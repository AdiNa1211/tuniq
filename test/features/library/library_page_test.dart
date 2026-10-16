import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tuniq/features/library/domain/library_permission.dart';
import 'package:tuniq/features/library/presentation/bloc/library_bloc.dart';
import 'package:tuniq/features/library/presentation/library_page.dart';
import 'package:tuniq/features/player/presentation/cubit/player_cubit.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockLibraryRepository repository;

  setUp(() {
    repository = MockLibraryRepository();
    when(() => repository.loadSongs()).thenAnswer((_) async => testSongs);
    when(() => repository.openSettings()).thenAnswer((_) async {});
  });

  Future<void> pumpPage(WidgetTester tester, LibraryPermission permission) async {
    when(() => repository.permissionStatus()).thenAnswer((_) async => permission);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => LibraryBloc(repository)..add(const LibraryStarted()),
          ),
          BlocProvider(create: (_) => PlayerCubit()),
        ],
        child: const MaterialApp(home: LibraryPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('LibraryPage', () {
    testWidgets('lists songs when access is granted', (tester) async {
      await pumpPage(tester, LibraryPermission.granted);
      expect(find.text(testSongs.first.title), findsOneWidget);
    });

    testWidgets('asks for access and requests it on tap', (tester) async {
      when(() => repository.requestPermission())
          .thenAnswer((_) async => LibraryPermission.granted);
      await pumpPage(tester, LibraryPermission.denied);
      expect(find.text('Let Tuniq find your music'), findsOneWidget);

      await tester.tap(find.text('Allow access'));
      await tester.pumpAndSettle();
      verify(() => repository.requestPermission()).called(1);
      expect(find.text(testSongs.first.title), findsOneWidget);
    });

    testWidgets('offers Settings after a permanent denial', (tester) async {
      await pumpPage(tester, LibraryPermission.permanentlyDenied);
      expect(find.text('Allow access'), findsNothing);

      await tester.tap(find.text('Open Settings'));
      await tester.pump();
      verify(() => repository.openSettings()).called(1);
    });

    testWidgets('shows an empty state with a rescan button', (tester) async {
      when(() => repository.loadSongs()).thenAnswer((_) async => []);
      await pumpPage(tester, LibraryPermission.granted);
      expect(find.text('No music found'), findsOneWidget);

      await tester.tap(find.text('Scan again'));
      await tester.pumpAndSettle();
      verify(() => repository.loadSongs()).called(2);
    });

    testWidgets('shows an error with a retry button', (tester) async {
      when(() => repository.loadSongs()).thenThrow(Exception('boom'));
      await pumpPage(tester, LibraryPermission.granted);
      expect(find.text("Couldn't read your music. Try again."), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets(
      'shows the Folders tab on Android',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
        await pumpPage(tester, LibraryPermission.granted);
        expect(find.widgetWithText(Tab, 'Folders'), findsOneWidget);
      },
    );

    testWidgets(
      'hides the Folders tab on iOS',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        await pumpPage(tester, LibraryPermission.granted);
        expect(find.widgetWithText(Tab, 'Folders'), findsNothing);
      },
    );
  });
}
