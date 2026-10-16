import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuniq/features/player/presentation/cubit/player_cubit.dart';
import 'package:tuniq/features/player/presentation/cubit/player_state.dart';

import '../../helpers/fixtures.dart';

void main() {
  final songs = testSongs.take(3).toList();
  final firstDuration = songs.first.duration;

  PlayerState playing({
    int index = 0,
    Duration position = Duration.zero,
    PlayerRepeatMode repeat = PlayerRepeatMode.off,
  }) =>
      PlayerState(
        queue: songs,
        currentIndex: index,
        playing: true,
        position: position,
        repeatMode: repeat,
      );

  group('PlayerCubit', () {
    test('starts with an empty, paused queue', () async {
      final cubit = PlayerCubit();
      expect(cubit.state, const PlayerState());
      expect(cubit.state.currentSong, isNull);
      await cubit.close();
    });

    group('playQueue', () {
      blocTest<PlayerCubit, PlayerState>(
        'starts playing at the chosen song',
        build: PlayerCubit.new,
        act: (cubit) => cubit.playQueue(songs, startIndex: 1),
        expect: () => [playing(index: 1)],
      );

      blocTest<PlayerCubit, PlayerState>(
        'ignores an empty list',
        build: PlayerCubit.new,
        act: (cubit) => cubit.playQueue(const []),
        expect: () => <PlayerState>[],
      );
    });

    group('togglePlay', () {
      blocTest<PlayerCubit, PlayerState>(
        'does nothing without a queue',
        build: PlayerCubit.new,
        act: (cubit) => cubit.togglePlay(),
        expect: () => <PlayerState>[],
      );

      blocTest<PlayerCubit, PlayerState>(
        'pauses a playing song',
        build: PlayerCubit.new,
        seed: playing,
        act: (cubit) => cubit.togglePlay(),
        expect: () => [playing().copyWith(playing: false)],
      );
    });

    group('next', () {
      blocTest<PlayerCubit, PlayerState>(
        'moves to the next song',
        build: PlayerCubit.new,
        seed: playing,
        act: (cubit) => cubit.next(),
        expect: () => [playing(index: 1)],
      );

      blocTest<PlayerCubit, PlayerState>(
        'wraps to the first song with repeat all',
        build: PlayerCubit.new,
        seed: () => playing(index: 2, repeat: PlayerRepeatMode.all),
        act: (cubit) => cubit.next(),
        expect: () => [playing(repeat: PlayerRepeatMode.all)],
      );

      blocTest<PlayerCubit, PlayerState>(
        'stops at the end of the queue with repeat off',
        build: PlayerCubit.new,
        seed: () => playing(index: 2, position: const Duration(seconds: 30)),
        act: (cubit) => cubit.next(),
        expect: () => [playing(index: 2).copyWith(playing: false)],
      );
    });

    group('previous', () {
      blocTest<PlayerCubit, PlayerState>(
        'restarts the song after 3 seconds',
        build: PlayerCubit.new,
        seed: () => playing(index: 1, position: const Duration(seconds: 10)),
        act: (cubit) => cubit.previous(),
        expect: () => [playing(index: 1)],
      );

      blocTest<PlayerCubit, PlayerState>(
        'goes to the previous song near the start',
        build: PlayerCubit.new,
        seed: () => playing(index: 1, position: const Duration(seconds: 1)),
        act: (cubit) => cubit.previous(),
        expect: () => [playing()],
      );
    });

    group('seek', () {
      blocTest<PlayerCubit, PlayerState>(
        'clamps past the end to the duration',
        build: PlayerCubit.new,
        seed: playing,
        act: (cubit) => cubit.seek(const Duration(hours: 1)),
        expect: () => [playing(position: firstDuration)],
      );

      blocTest<PlayerCubit, PlayerState>(
        'clamps negative positions to zero',
        build: PlayerCubit.new,
        seed: () => playing(position: const Duration(seconds: 10)),
        act: (cubit) => cubit.seek(const Duration(seconds: -5)),
        expect: () => [playing()],
      );
    });

    blocTest<PlayerCubit, PlayerState>(
      'cycleRepeat goes off → all → one → off',
      build: PlayerCubit.new,
      act: (cubit) => cubit
        ..cycleRepeat()
        ..cycleRepeat()
        ..cycleRepeat(),
      expect: () => [
        const PlayerState(repeatMode: PlayerRepeatMode.all),
        const PlayerState(repeatMode: PlayerRepeatMode.one),
        const PlayerState(),
      ],
    );

    blocTest<PlayerCubit, PlayerState>(
      'toggleShuffle flips the flag',
      build: PlayerCubit.new,
      act: (cubit) => cubit.toggleShuffle(),
      expect: () => [const PlayerState(shuffle: true)],
    );

    group('skipToIndex', () {
      blocTest<PlayerCubit, PlayerState>(
        'jumps to the song',
        build: PlayerCubit.new,
        seed: playing,
        act: (cubit) => cubit.skipToIndex(2),
        expect: () => [playing(index: 2)],
      );

      blocTest<PlayerCubit, PlayerState>(
        'ignores an out-of-range index',
        build: PlayerCubit.new,
        seed: playing,
        act: (cubit) => cubit.skipToIndex(9),
        expect: () => <PlayerState>[],
      );
    });

    group('advanceBy', () {
      blocTest<PlayerCubit, PlayerState>(
        'moves the position forward',
        build: PlayerCubit.new,
        seed: playing,
        act: (cubit) => cubit.advanceBy(const Duration(seconds: 5)),
        expect: () => [playing(position: const Duration(seconds: 5))],
      );

      blocTest<PlayerCubit, PlayerState>(
        'moves to the next song at the end',
        build: PlayerCubit.new,
        seed: () => playing(position: firstDuration - const Duration(seconds: 1)),
        act: (cubit) => cubit.advanceBy(const Duration(seconds: 2)),
        expect: () => [playing(index: 1)],
      );

      blocTest<PlayerCubit, PlayerState>(
        'restarts the song at the end with repeat one',
        build: PlayerCubit.new,
        seed: () => playing(
          position: firstDuration - const Duration(seconds: 1),
          repeat: PlayerRepeatMode.one,
        ),
        act: (cubit) => cubit.advanceBy(const Duration(seconds: 2)),
        expect: () => [playing(repeat: PlayerRepeatMode.one)],
      );

      blocTest<PlayerCubit, PlayerState>(
        'does nothing while paused',
        build: PlayerCubit.new,
        seed: () => playing().copyWith(playing: false),
        act: (cubit) => cubit.advanceBy(const Duration(seconds: 5)),
        expect: () => <PlayerState>[],
      );
    });
  });
}
