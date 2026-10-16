import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tuniq/app/routes.dart';
import 'package:tuniq/core/audio/app_audio_handler.dart';
import 'package:tuniq/features/library/data/artwork_repository.dart';
import 'package:tuniq/features/library/domain/library_permission.dart';
import 'package:tuniq/features/library/domain/song_group.dart';
import 'package:tuniq/features/library/presentation/album_page.dart';
import 'package:tuniq/features/library/presentation/artist_page.dart';
import 'package:tuniq/features/library/presentation/bloc/library_bloc.dart';
import 'package:tuniq/features/player/presentation/cubit/player_cubit.dart';

import '../../helpers/fake_player_slot.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockLibraryRepository repository;
  late AppAudioHandler engine;
  late PlayerCubit player;

  setUp(() {
    repository = MockLibraryRepository();
    when(() => repository.permissionStatus())
        .thenAnswer((_) async => LibraryPermission.granted);
    when(() => repository.loadSongs()).thenAnswer((_) async => testSongs);
    when(() => repository.cachedSongs()).thenAnswer((_) async => null);
    when(() => repository.supportsImport).thenReturn(false);
    engine = AppAudioHandler(slot: FakePlayerSlot());
    player = PlayerCubit(engine);
  });

  tearDown(() async {
    await player.close();
    await engine.dispose();
  });

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      RepositoryProvider<ArtworkRepository>.value(
        value: noArtworkRepository(),
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => LibraryBloc(repository)..add(const LibraryStarted()),
            ),
            BlocProvider.value(value: player),
          ],
          child: MaterialApp(home: page),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AlbumPage', () {
    final coastline = albumTracks(testSongs, 'a1');

    testWidgets('lists the album with its length', (tester) async {
      await pumpPage(tester, const AlbumPage(albumKey: 'a1', basePath: AppRoutes.library));
      expect(find.widgetWithText(AppBar, 'Coastline'), findsOneWidget);
      expect(find.text('3 songs · 10 min'), findsOneWidget);
      for (final track in coastline) {
        expect(find.text(track.title), findsOneWidget);
      }
    });

    testWidgets('plays the album from the top', (tester) async {
      await pumpPage(tester, const AlbumPage(albumKey: 'a1', basePath: AppRoutes.library));
      await tester.tap(find.text('Play'));
      await tester.pump();
      expect(player.state.queue, coastline);
      expect(player.state.currentIndex, 0);
    });

    testWidgets('plays from the tapped track', (tester) async {
      await pumpPage(tester, const AlbumPage(albumKey: 'a1', basePath: AppRoutes.library));
      await tester.tap(find.text(coastline[1].title));
      await tester.pump();
      expect(player.state.currentIndex, 1);
    });

    testWidgets('shuffles the album', (tester) async {
      await pumpPage(tester, const AlbumPage(albumKey: 'a1', basePath: AppRoutes.library));
      await tester.tap(find.text('Shuffle'));
      await tester.pump();
      expect(player.state.queue, unorderedEquals(coastline));
      expect(player.state.shuffle, isTrue);
    });

    testWidgets('explains a missing album', (tester) async {
      await pumpPage(tester, const AlbumPage(albumKey: 'gone', basePath: AppRoutes.library));
      expect(find.text('This album is no longer in your library.'), findsOneWidget);
    });
  });

  group('ArtistPage', () {
    testWidgets('lists albums and songs', (tester) async {
      await pumpPage(tester, const ArtistPage(artistKey: 'ira moss', basePath: AppRoutes.library));
      expect(find.widgetWithText(AppBar, 'Ira Moss'), findsOneWidget);
      expect(find.text('1 album · 3 songs'), findsOneWidget);
      expect(find.text('Daylight Saving'), findsOneWidget);
      expect(find.text('Northbound'), findsOneWidget);
    });

    testWidgets('plays all of the artist', (tester) async {
      await pumpPage(tester, const ArtistPage(artistKey: 'ira moss', basePath: AppRoutes.library));
      await tester.tap(find.text('Play'));
      await tester.pump();
      expect(player.state.queue, artistSongs(testSongs, 'ira moss'));
    });
  });
}
