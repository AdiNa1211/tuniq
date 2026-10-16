import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuniq/core/audio/app_audio_handler.dart';
import 'package:tuniq/core/audio/engine_state.dart';
import 'package:tuniq/core/audio/queue_controller.dart';
import 'package:tuniq/features/library/domain/song.dart';

import '../../helpers/fake_player_slot.dart';
import '../../helpers/fixtures.dart';

void main() {
  late FakePlayerSlot slot;
  late AppAudioHandler handler;
  final songs = testSongs.take(3).toList();

  setUp(() {
    slot = FakePlayerSlot();
    handler = AppAudioHandler(
      slot: slot,
      queueController: QueueController(random: Random(3)),
    );
  });

  tearDown(() => handler.dispose());

  Song current() => handler.state.current!.song;

  Future<void> finishTrack() async {
    slot.finishTrack();
    await pumpEventQueue();
  }

  group('playback', () {
    test('plays the chosen song', () async {
      await handler.playQueue(songs, startIndex: 1);
      expect(slot.loaded, [songs[1].uri]);
      expect(slot.playing, isTrue);
      expect(handler.state.playing, isTrue);
      expect(current(), songs[1]);
    });

    test('pauses and resumes', () async {
      await handler.playQueue(songs);
      await handler.pause();
      expect(slot.playing, isFalse);
      expect(handler.state.playing, isFalse);
      await handler.play();
      expect(slot.playing, isTrue);
    });

    test('reports the decoder duration', () async {
      slot.reportedDuration = const Duration(minutes: 5);
      await handler.playQueue(songs);
      expect(handler.state.duration, const Duration(minutes: 5));
    });

    test('seeks', () async {
      await handler.playQueue(songs);
      await handler.seek(const Duration(seconds: 42));
      expect(slot.position, const Duration(seconds: 42));
    });
  });

  group('track changes', () {
    test('skipToNext loads the next song', () async {
      await handler.playQueue(songs);
      await handler.skipToNext();
      expect(current(), songs[1]);
      expect(slot.loaded.last, songs[1].uri);
    });

    test('a skip while paused stays paused', () async {
      await handler.playQueue(songs);
      await handler.pause();
      await handler.skipToNext();
      expect(slot.playing, isFalse);
    });

    test('a finished track starts the next one', () async {
      await handler.playQueue(songs);
      await finishTrack();
      expect(current(), songs[1]);
      expect(slot.playing, isTrue);
    });

    test('stops after the last song with repeat off', () async {
      await handler.playQueue(songs, startIndex: 2);
      slot.position = const Duration(seconds: 30);
      await finishTrack();
      expect(handler.state.playing, isFalse);
      expect(slot.position, Duration.zero);
      expect(current(), songs[2]);
    });

    test('repeat one replays the song when it ends', () async {
      await handler.playQueue(songs);
      await handler.setRepeat(PlayerRepeatMode.one);
      await finishTrack();
      expect(current(), songs[0]);
      expect(slot.loaded, [songs[0].uri, songs[0].uri]);
    });

    test('repeat all wraps to the first song', () async {
      await handler.playQueue(songs, startIndex: 2);
      await handler.setRepeat(PlayerRepeatMode.all);
      await finishTrack();
      expect(current(), songs[0]);
    });

    test('previous restarts the song after 3 seconds', () async {
      await handler.playQueue(songs, startIndex: 1);
      slot.position = const Duration(seconds: 10);
      await handler.skipToPrevious();
      expect(current(), songs[1]);
      expect(slot.position, Duration.zero);
      expect(slot.loaded, hasLength(1));
    });

    test('previous goes back near the start', () async {
      await handler.playQueue(songs, startIndex: 1);
      slot.position = const Duration(seconds: 1);
      await handler.skipToPrevious();
      expect(current(), songs[0]);
    });

    test('rapid skips land on the right song', () async {
      await handler.playQueue(testSongs);
      await Future.wait([for (var i = 0; i < 5; i++) handler.skipToNext()]);
      expect(handler.state.currentIndex, 5);
      expect(current(), testSongs[5]);
    });

    test('skipToQueueItem jumps and plays', () async {
      await handler.playQueue(songs);
      await handler.pause();
      await handler.skipToQueueItem(2);
      expect(current(), songs[2]);
      expect(slot.playing, isTrue);
    });
  });

  group('errors', () {
    test('skips an unplayable song and reports it', () async {
      slot.failing.add(songs[0].uri);
      await handler.playQueue(songs);
      expect(current(), songs[1]);
      expect(slot.playing, isTrue);
      expect(handler.state.errorMessage, contains(songs[0].title));
      expect(handler.state.errorId, 1);
    });

    test('gives up after three unplayable songs in a row', () async {
      final four = testSongs.take(4).toList();
      slot.failing.addAll(four.take(3).map((s) => s.uri));
      await handler.playQueue(four);
      expect(handler.state.playing, isFalse);
      expect(handler.state.errorId, 3);
      expect(current(), four[2]);
    });
  });

  group('queue', () {
    test('play next, add to queue, move and remove', () async {
      await handler.playQueue(songs);
      await handler.playNext(testSongs[5]);
      expect(handler.state.queue[1].song, testSongs[5]);

      await handler.enqueue(testSongs[6]);
      expect(handler.state.queue.last.song, testSongs[6]);

      await handler.moveQueueItem(4, 1);
      expect(handler.state.queue[1].song, testSongs[6]);

      await handler.removeQueueItemAt(1);
      expect(handler.state.queue.map((e) => e.song), isNot(contains(testSongs[6])));

      await handler.removeQueueItemAt(0); // the playing song stays
      expect(current(), songs[0]);
    });

    test('play next on an empty queue starts playing', () async {
      await handler.playNext(testSongs[4]);
      expect(current(), testSongs[4]);
      expect(slot.playing, isTrue);
    });

    test('shuffle keeps the current song', () async {
      await handler.playQueue(testSongs, startIndex: 3);
      await handler.setShuffleEnabled(true);
      expect(current(), testSongs[3]);
      expect(handler.state.shuffle, isTrue);

      await handler.setShuffleEnabled(false);
      expect(current(), testSongs[3]);
      expect(handler.state.currentIndex, 3);
    });
  });

  group('audio_service', () {
    test('publishes the media item, queue and playback state', () async {
      await handler.playQueue(songs);
      expect(handler.mediaItem.value?.title, songs[0].title);
      expect(handler.queue.value, hasLength(3));
      expect(handler.playbackState.value.playing, isTrue);
      expect(handler.playbackState.value.queueIndex, 0);
    });

    test('maps system repeat and shuffle modes', () async {
      await handler.playQueue(songs);
      await handler.setRepeatMode(AudioServiceRepeatMode.all);
      await handler.setShuffleMode(AudioServiceShuffleMode.all);
      expect(handler.state.repeatMode, PlayerRepeatMode.all);
      expect(handler.state.shuffle, isTrue);
    });
  });
}
