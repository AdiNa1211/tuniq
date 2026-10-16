import 'package:flutter_test/flutter_test.dart';
import 'package:tuniq/core/audio/app_audio_handler.dart';
import 'package:tuniq/features/player/presentation/cubit/player_cubit.dart';
import 'package:tuniq/features/player/presentation/cubit/player_state.dart';

import '../../helpers/fake_player_slot.dart';
import '../../helpers/fixtures.dart';

void main() {
  late FakePlayerSlot slot;
  late AppAudioHandler engine;
  late PlayerCubit cubit;
  final songs = testSongs.take(3).toList();

  setUp(() {
    slot = FakePlayerSlot();
    engine = AppAudioHandler(slot: slot);
    cubit = PlayerCubit(engine);
  });

  tearDown(() async {
    await cubit.close();
    await engine.dispose();
  });

  // Commands go through the engine and come back as states.
  Future<void> settle() => pumpEventQueue();

  group('PlayerCubit', () {
    test('starts empty and paused', () {
      expect(cubit.state, const PlayerState());
      expect(cubit.state.currentSong, isNull);
    });

    test('mirrors the engine queue', () async {
      cubit.playQueue(songs, startIndex: 1);
      await settle();
      expect(cubit.state.queue, songs);
      expect(cubit.state.currentSong, songs[1]);
      expect(cubit.state.playing, isTrue);
    });

    test('togglePlay pauses and resumes', () async {
      cubit.playQueue(songs);
      await settle();
      cubit.togglePlay();
      await settle();
      expect(slot.playing, isFalse);
      expect(cubit.state.playing, isFalse);
      cubit.togglePlay();
      await settle();
      expect(slot.playing, isTrue);
    });

    test('togglePlay does nothing without a queue', () async {
      cubit.togglePlay();
      await settle();
      expect(slot.loaded, isEmpty);
    });

    test('follows the playback position', () async {
      cubit.playQueue(songs);
      await settle();
      slot.emitPosition(const Duration(seconds: 12));
      await settle();
      expect(cubit.state.position, const Duration(seconds: 12));
    });

    test('resets the position for a new song', () async {
      cubit.playQueue(songs);
      await settle();
      slot.emitPosition(const Duration(seconds: 12));
      await settle();
      cubit.next();
      await settle();
      expect(cubit.state.currentSong, songs[1]);
      expect(cubit.state.position, Duration.zero);
    });

    test('seek updates the position immediately', () async {
      cubit.playQueue(songs);
      await settle();
      cubit.seek(const Duration(seconds: 30));
      expect(cubit.state.position, const Duration(seconds: 30));
      await settle();
      expect(slot.position, const Duration(seconds: 30));
    });

    test('cycleRepeat goes off → all → one → off', () async {
      final modes = <PlayerRepeatMode>[];
      for (var i = 0; i < 3; i++) {
        cubit.cycleRepeat();
        await settle();
        modes.add(cubit.state.repeatMode);
      }
      expect(modes, [PlayerRepeatMode.all, PlayerRepeatMode.one, PlayerRepeatMode.off]);
    });

    test('toggleShuffle turns shuffle on', () async {
      cubit.playQueue(songs);
      await settle();
      cubit.toggleShuffle();
      await settle();
      expect(cubit.state.shuffle, isTrue);
    });

    test('shuffle play keeps every song', () async {
      cubit.playQueue(testSongs, startIndex: 3, shuffle: true);
      await settle();
      expect(cubit.state.queue, unorderedEquals(testSongs));
      expect(cubit.state.shuffle, isTrue);
      expect(cubit.state.currentIndex, 0);
    });

    test('uses the decoder duration when known', () async {
      slot.reportedDuration = const Duration(minutes: 9);
      cubit.playQueue(songs);
      await settle();
      expect(cubit.state.duration, const Duration(minutes: 9));
    });
  });
}
