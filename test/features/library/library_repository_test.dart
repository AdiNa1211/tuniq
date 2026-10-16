import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tuniq/features/library/data/library_cache.dart';
import 'package:tuniq/features/library/data/library_repository.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  late Directory dir;
  late MockDeviceLibrarySource source;
  late LibraryRepository repository;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('library_repository_test');
    source = MockDeviceLibrarySource();
    repository = LibraryRepository(source, LibraryCache(directory: () async => dir));
  });

  tearDown(() => dir.delete(recursive: true));

  group('LibraryRepository', () {
    test('sorts songs by title, ignoring case', () async {
      when(() => source.fetchSongs()).thenAnswer((_) async => testSongs.reversed.toList());
      final titles = (await repository.loadSongs()).map((s) => s.title).toList();
      expect(titles, [...titles]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())));
    });

    test('caches the latest scan', () async {
      when(() => source.fetchSongs()).thenAnswer((_) async => testSongs);
      final songs = await repository.loadSongs();
      expect(await repository.cachedSongs(), songs);
    });

    test('clearCache forgets the last scan', () async {
      when(() => source.fetchSongs()).thenAnswer((_) async => testSongs);
      await repository.loadSongs();
      await repository.clearCache();
      expect(await repository.cachedSongs(), isNull);
    });
  });
}
