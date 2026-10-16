import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuniq/features/library/data/library_cache.dart';
import 'package:tuniq/features/library/domain/song.dart';

import '../../helpers/fixtures.dart';

void main() {
  late Directory dir;
  late LibraryCache cache;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('library_cache_test');
    cache = LibraryCache(directory: () async => dir);
  });

  tearDown(() => dir.delete(recursive: true));

  group('LibraryCache', () {
    test('returns null when nothing is cached', () async {
      expect(await cache.read(), isNull);
    });

    test('round-trips songs, including optional fields', () async {
      final song = Song(
        id: '9',
        uri: Uri.parse('ipod-library://item/item.m4a?id=9'),
        title: 'Title',
        artist: 'Artist',
        album: 'Album',
        albumId: '77',
        duration: const Duration(minutes: 3, seconds: 1),
        trackNumber: 4,
        folderPath: 'Music',
        dateAdded: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      await cache.write([...testSongs, song]);
      expect(await cache.read(), [...testSongs, song]);
    });

    test('ignores a corrupt file', () async {
      await File('${dir.path}/library_cache.json').writeAsString('{not json');
      expect(await cache.read(), isNull);
    });

    test('ignores a file from another version', () async {
      await File('${dir.path}/library_cache.json')
          .writeAsString('{"version": 999, "songs": []}');
      expect(await cache.read(), isNull);
    });

    test('clear removes the cache', () async {
      await cache.write(testSongs);
      await cache.clear();
      expect(await cache.read(), isNull);
    });
  });
}
