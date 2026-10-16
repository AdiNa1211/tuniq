import 'package:flutter_test/flutter_test.dart';
import 'package:tuniq/core/audio/app_audio_handler.dart';
import 'package:tuniq/core/audio/crossfade.dart';
import 'package:tuniq/core/audio/engine_state.dart';
import 'package:tuniq/features/library/domain/song.dart';

import '../../helpers/fake_player_slot.dart';
import '../../helpers/fixtures.dart';

void main() {
  late FakePlayerSlot a;
  late FakePlayerSlot b;
  late AppAudioHandler handler;
  final songs = testSongs.take(3).toList();
  const length = Duration(minutes: 3);

  setUp(() {
    a = FakePlayerSlot()..reportedDuration = length;
    b = FakePlayerSlot()..reportedDuration = length;
    handler = AppAudioHandler(slot: a, fadeSlot: b)
      ..setCrossfade(const CrossfadeSettings(enabled: true));
  });

  tearDown(() => handler.dispose());

  Song current() => handler.state.current!.song;

  Future<void> at(FakePlayerSlot slot, Duration position) async {
    slot.emitPosition(position);
    await pumpEventQueue();
  }

  Duration before(int seconds) => length - Duration(seconds: seconds);

  group('crossfade', () {
    test('preloads the next song silently before the fade', () async {
      await handler.playQueue(songs);
      await at(a, before(10));
      expect(b.loaded, [songs[1].uri]);
      expect(b.volume, 0);
      expect(b.playing, isFalse);
      expect(current(), songs[0]);
    });

    test('fades the next song in while the current one fades out', () async {
      await handler.playQueue(songs);
      await at(a, before(10));
      await at(a, before(6));

      expect(current(), songs[1]);
      expect(a.playing && b.playing, isTrue);

      await at(a, before(3));
      expect(a.volume, closeTo(0.707, 0.01));
      expect(b.volume, closeTo(0.707, 0.01));

      await at(a, length);
      expect(a.playing, isFalse);
      expect(b.volume, 1);
      expect(b.loaded, [songs[1].uri]);
    });

    test('the outgoing song ending also finishes the fade', () async {
      await handler.playQueue(songs);
      await at(a, before(6));
      a.finishTrack();
      await pumpEventQueue();
      expect(a.stops, 1);
      expect(b.volume, 1);
      expect(current(), songs[1]);
    });

    test('the next fade goes back to the first player', () async {
      await handler.playQueue(songs);
      await at(a, before(6));
      await at(a, length);
      await at(b, before(6));
      expect(current(), songs[2]);
      expect(a.loaded.last, songs[2].uri);
      expect(a.playing, isTrue);
    });

    test('positions follow the song shown as current', () async {
      final positions = <Duration>[];
      final subscription = handler.positions.listen(positions.add);
      await handler.playQueue(songs);
      await at(a, before(6));
      positions.clear();

      await at(a, before(5)); // outgoing: drives the volume only
      await at(b, const Duration(seconds: 1));
      expect(positions, [const Duration(seconds: 1)]);
      await subscription.cancel();
    });

    test('uses the chosen length', () async {
      handler.setCrossfade(const CrossfadeSettings(enabled: true, seconds: 12));
      await handler.playQueue(songs);
      await at(a, before(12));
      expect(current(), songs[1]);
    });

    test('short songs fade over half their length at most', () async {
      a.reportedDuration = const Duration(seconds: 8);
      await handler.playQueue(songs);
      await at(a, const Duration(seconds: 3));
      expect(current(), songs[0]);
      await at(a, const Duration(seconds: 4));
      expect(current(), songs[1]);
    });
  });

  group('no crossfade', () {
    test('when turned off', () async {
      handler.setCrossfade(const CrossfadeSettings());
      await handler.playQueue(songs);
      await at(a, before(3));
      expect(b.loaded, isEmpty);
      a.finishTrack();
      await pumpEventQueue();
      expect(current(), songs[1]);
      expect(a.loaded.last, songs[1].uri);
    });

    test('after the last song with repeat off', () async {
      await handler.playQueue(songs, startIndex: 2);
      await at(a, before(3));
      expect(b.loaded, isEmpty);
      expect(current(), songs[2]);
    });

    test('with repeat one', () async {
      await handler.playQueue(songs);
      await handler.setRepeat(PlayerRepeatMode.one);
      await at(a, before(3));
      expect(b.loaded, isEmpty);
    });

    test('while paused', () async {
      await handler.playQueue(songs);
      await handler.pause();
      await at(a, before(3));
      expect(current(), songs[0]);
    });

    test('when the next song cannot be loaded', () async {
      b.failing.add(songs[1].uri);
      await handler.playQueue(songs);
      await at(a, before(10));
      await at(a, before(6));
      expect(current(), songs[0]);
      expect(a.playing, isTrue);
    });
  });

  group('during a fade', () {
    Future<void> startFade() async {
      await handler.playQueue(songs);
      await at(a, before(6));
      expect(current(), songs[1]);
    }

    test('skipping cuts the fading-out song', () async {
      await startFade();
      await handler.skipToNext();
      expect(a.playing, isFalse);
      expect(current(), songs[2]);
      expect(b.loaded.last, songs[2].uri);
      expect(b.volume, 1);
    });

    test('seeking cuts the fading-out song', () async {
      await startFade();
      await handler.seek(const Duration(seconds: 30));
      expect(a.playing, isFalse);
      expect(b.position, const Duration(seconds: 30));
      expect(b.volume, 1);
    });

    test('pause and play apply to both songs', () async {
      await startFade();
      await handler.pause();
      expect(a.playing || b.playing, isFalse);
      await handler.play();
      expect(a.playing && b.playing, isTrue);
    });

    test('a queue edit picks the new next song for the fade', () async {
      await handler.playQueue(songs);
      await at(a, before(10));
      await handler.playNext(testSongs[5]);
      await at(a, before(6));
      expect(current(), testSongs[5]);
      expect(b.loaded.last, testSongs[5].uri);
    });
  });
}
