import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuniq/core/audio/engine_state.dart';
import 'package:tuniq/core/audio/queue_controller.dart';

import '../../helpers/fixtures.dart';

void main() {
  late QueueController queue;
  final songs = testSongs.take(4).toList();

  setUp(() => queue = QueueController(random: Random(7)));

  List<String> titles() => queue.entries.map((e) => e.song.title).toList();

  group('replace', () {
    test('starts at the chosen song', () {
      queue.replace(songs, startIndex: 2);
      expect(queue.current!.song, songs[2]);
      expect(titles(), songs.map((s) => s.title));
    });

    test('shuffle play turns shuffle on and keeps every song', () {
      queue.replace(songs, shufflePlay: true);
      expect(queue.shuffle, isTrue);
      expect(queue.currentIndex, 0);
      expect(queue.entries.map((e) => e.song), unorderedEquals(songs));
    });

    test('with shuffle already on, the tapped song plays first', () {
      queue
        ..replace(songs)
        ..setShuffle(true)
        ..replace(songs, startIndex: 2);
      expect(queue.current!.song, songs[2]);
      expect(queue.currentIndex, 0);
      expect(queue.entries.map((e) => e.song), unorderedEquals(songs));
    });

    test('gives duplicate songs separate entries', () {
      queue.replace([songs[0], songs[0]]);
      expect(queue.entries[0].id, isNot(queue.entries[1].id));
    });
  });

  group('next and previous', () {
    test('steps through and stops at the end with repeat off', () {
      queue.replace(songs, startIndex: 3);
      expect(queue.nextIndex(userInitiated: false), isNull);
      expect(queue.previousIndex(), 2);
    });

    test('wraps with repeat all', () {
      queue
        ..replace(songs, startIndex: 3)
        ..repeat = PlayerRepeatMode.all;
      expect(queue.nextIndex(userInitiated: false), 0);
      queue.moveTo(0);
      expect(queue.previousIndex(), 3);
    });

    test('repeat one replays only when the track ends by itself', () {
      queue
        ..replace(songs, startIndex: 1)
        ..repeat = PlayerRepeatMode.one;
      expect(queue.nextIndex(userInitiated: false), 1);
      expect(queue.nextIndex(userInitiated: true), 2);
    });
  });

  group('setShuffle', () {
    test('keeps the current song and restores the original order', () {
      queue.replace(songs, startIndex: 2);
      queue.setShuffle(true);
      expect(queue.current!.song, songs[2]);
      expect(queue.currentIndex, 0);

      queue.setShuffle(false);
      expect(queue.current!.song, songs[2]);
      expect(queue.currentIndex, 2);
      expect(titles(), songs.map((s) => s.title));
    });
  });

  group('edits', () {
    test('move keeps the current song selected', () {
      queue.replace(songs, startIndex: 1);
      queue.move(0, 3);
      expect(titles(), [songs[1], songs[2], songs[3], songs[0]].map((s) => s.title));
      expect(queue.current!.song, songs[1]);
      expect(queue.currentIndex, 0);
    });

    test('removeAt refuses the current song', () {
      queue.replace(songs, startIndex: 1);
      expect(queue.removeAt(1), isFalse);
      expect(queue.length, 4);
    });

    test('removeAt before the current song shifts the index', () {
      queue.replace(songs, startIndex: 2);
      expect(queue.removeAt(0), isTrue);
      expect(queue.current!.song, songs[2]);
      expect(queue.currentIndex, 1);
    });

    test('insertNext puts the song right after the current one', () {
      queue.replace(songs, startIndex: 1);
      queue.insertNext(testSongs[6]);
      expect(queue.entries[2].song, testSongs[6]);
    });

    test('insertNext survives turning shuffle off', () {
      queue
        ..replace(songs, startIndex: 1)
        ..setShuffle(true)
        ..insertNext(testSongs[6])
        ..setShuffle(false);
      expect(queue.entries[2].song, testSongs[6]);
    });

    test('enqueue appends', () {
      queue
        ..replace(songs)
        ..enqueue(testSongs[7]);
      expect(queue.entries.last.song, testSongs[7]);
    });
  });
}
