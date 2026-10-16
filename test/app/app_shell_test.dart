import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tuniq/app/app.dart';
import 'package:tuniq/features/library/domain/library_permission.dart';
import 'package:tuniq/features/player/presentation/full_player_page.dart';
import 'package:tuniq/features/player/presentation/widgets/mini_player.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';

void main() {
  late MockSettingsRepository settings;
  late MockLibraryRepository library;
  final song = testSongs.first;

  setUpAll(() => registerFallbackValue(ThemeMode.system));

  setUp(() {
    settings = MockSettingsRepository();
    when(() => settings.loadThemeMode()).thenAnswer((_) async => ThemeMode.system);
    when(() => settings.saveThemeMode(any())).thenAnswer((_) async {});

    library = MockLibraryRepository();
    when(() => library.permissionStatus())
        .thenAnswer((_) async => LibraryPermission.granted);
    when(() => library.loadSongs()).thenAnswer((_) async => testSongs);
    when(() => library.cachedSongs()).thenAnswer((_) async => null);
    when(() => library.clearCache()).thenAnswer((_) async {});
    when(() => library.supportsImport).thenReturn(false);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      TuniqApp(
        settingsRepository: settings,
        libraryRepository: library,
        artworkRepository: noArtworkRepository(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder navItem(String label) =>
      find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

  Finder inMiniPlayer(Finder finder) =>
      find.descendant(of: find.byType(MiniPlayer), matching: finder);

  group('AppShell', () {
    testWidgets('opens on Library and switches tabs', (tester) async {
      await pumpApp(tester);
      expect(find.widgetWithText(AppBar, 'Library'), findsOneWidget);

      await tester.tap(navItem('Search'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Search'), findsOneWidget);

      await tester.tap(navItem('Settings'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    });

    testWidgets('hides the mini-player until a song is played', (tester) async {
      await pumpApp(tester);
      expect(inMiniPlayer(find.text(song.title)), findsNothing);

      await tester.tap(find.text(song.title));
      await tester.pump();
      expect(inMiniPlayer(find.text(song.title)), findsOneWidget);
    });

    testWidgets('keeps the mini-player on every tab', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text(song.title));
      await tester.pump();

      for (final tab in ['Search', 'Settings', 'Library']) {
        await tester.tap(navItem(tab));
        await tester.pumpAndSettle();
        expect(inMiniPlayer(find.text(song.title)), findsOneWidget, reason: tab);
      }
    });

    testWidgets('opens the full player from the mini-player and closes it', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text(song.title));
      await tester.pump();

      await tester.tap(inMiniPlayer(find.text(song.title)));
      await tester.pumpAndSettle();
      expect(find.text('Now playing'), findsOneWidget);

      await tester.tap(find.byTooltip('Close player'));
      await tester.pumpAndSettle();
      expect(find.text('Now playing'), findsNothing);
    });

    testWidgets('opens the full player with a swipe up', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text(song.title));
      await tester.pump();

      await tester.fling(inMiniPlayer(find.text(song.title)), const Offset(0, -200), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Now playing'), findsOneWidget);
    });

    testWidgets('closes the full player with a swipe down', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text(song.title));
      await tester.pump();
      await tester.tap(inMiniPlayer(find.text(song.title)));
      await tester.pumpAndSettle();

      await tester.fling(find.byType(FullPlayerPage), const Offset(0, 300), 1500);
      await tester.pumpAndSettle();
      expect(find.text('Now playing'), findsNothing);
    });

    testWidgets('springs back after a short swipe down', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text(song.title));
      await tester.pump();
      await tester.tap(inMiniPlayer(find.text(song.title)));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(FullPlayerPage), const Offset(0, 60));
      await tester.pumpAndSettle();
      expect(find.text('Now playing'), findsOneWidget);
    });

    testWidgets('opens an album from the Albums tab', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.widgetWithText(Tab, 'Albums'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Coastline'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Coastline'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Low Tide'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Library'), findsOneWidget);
    });

    testWidgets('searches from the Search tab', (tester) async {
      await pumpApp(tester);
      await tester.tap(navItem('Search'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ira');
      await tester.pump(const Duration(milliseconds: 300));
      // Shown as the artist row and as the album's subtitle.
      expect(find.text('Ira Moss'), findsWidgets);
      expect(find.text('Northbound'), findsOneWidget);
    });

    testWidgets('pauses from the mini-player', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text(song.title));
      await tester.pump();

      await tester.tap(inMiniPlayer(find.byTooltip('Pause')));
      await tester.pump();
      expect(inMiniPlayer(find.byTooltip('Play')), findsOneWidget);
    });

    testWidgets('saves the chosen theme', (tester) async {
      await pumpApp(tester);
      await tester.tap(navItem('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      verify(() => settings.saveThemeMode(ThemeMode.dark)).called(1);
    });
  });

  group('LibraryPage folders tab', () {
    testWidgets(
      'is shown on Android',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
        await pumpApp(tester);
        expect(find.widgetWithText(Tab, 'Folders'), findsOneWidget);
      },
    );

    testWidgets(
      'is hidden on iOS',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        await pumpApp(tester);
        expect(find.widgetWithText(Tab, 'Folders'), findsNothing);
      },
    );
  });
}
