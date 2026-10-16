import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuniq/core/audio/app_audio_handler.dart';
import 'package:tuniq/features/library/data/artwork_repository.dart';
import 'package:tuniq/features/queue/presentation/cubit/queue_cubit.dart';
import 'package:tuniq/features/queue/presentation/queue_page.dart';

import '../../helpers/fake_player_slot.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  late AppAudioHandler engine;
  final songs = testSongs.take(4).toList();

  setUp(() => engine = AppAudioHandler(slot: FakePlayerSlot()));
  tearDown(() => engine.dispose());

  List<String> queueTitles() => engine.state.queue.map((e) => e.song.title).toList();

  group('QueueCubit', () {
    test('reorder converts the list view index', () async {
      final cubit = QueueCubit(engine);
      await engine.playQueue(songs);
      await pumpEventQueue();

      // Dragging row 1 below row 3: the list view reports newIndex 4.
      cubit.reorder(1, 4);
      expect(cubit.state.entries.last.song, songs[1]);
      await pumpEventQueue();
      expect(queueTitles().last, songs[1].title);
      await cubit.close();
    });

    test('remove updates the list before the engine', () async {
      final cubit = QueueCubit(engine);
      await engine.playQueue(songs, startIndex: 2);
      await pumpEventQueue();

      cubit.remove(0);
      expect(cubit.state.entries, hasLength(3));
      expect(cubit.state.currentIndex, 1);
      await pumpEventQueue();
      expect(engine.state.queue, hasLength(3));
      await cubit.close();
    });

    test('will not remove the playing song', () async {
      final cubit = QueueCubit(engine);
      await engine.playQueue(songs);
      await pumpEventQueue();
      cubit.remove(0);
      expect(cubit.state.entries, hasLength(4));
      await cubit.close();
    });
  });

  group('QueuePage', () {
    Future<void> pumpQueue(WidgetTester tester) async {
      await engine.playQueue(songs);
      await tester.pumpWidget(
        RepositoryProvider<ArtworkRepository>.value(
          value: noArtworkRepository(),
          child: BlocProvider(
            create: (_) => QueueCubit(engine),
            child: const MaterialApp(home: QueuePage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('marks the playing song', (tester) async {
      await pumpQueue(tester);
      expect(find.text('Now playing'), findsOneWidget);
      expect(find.text(songs[3].title), findsOneWidget);
    });

    testWidgets('swiping removes an upcoming song', (tester) async {
      await pumpQueue(tester);
      await tester.drag(find.text(songs[2].title), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text(songs[2].title), findsNothing);
      expect(engine.state.queue, hasLength(3));
    });

    testWidgets('tapping a song plays it', (tester) async {
      await pumpQueue(tester);
      await tester.tap(find.text(songs[3].title));
      await tester.pumpAndSettle();
      expect(engine.state.current!.song, songs[3]);
    });
  });
}
