import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tuniq/features/library/data/artwork_repository.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockDeviceLibrarySource source;
  final song = testSongs.first;
  final bytes = Uint8List.fromList([1, 2, 3]);

  setUpAll(() => registerFallbackValue(song));

  setUp(() => source = MockDeviceLibrarySource());

  void stubArtwork(Future<Uint8List?> Function() answer) {
    when(() => source.fetchArtwork(any(), sizePx: any(named: 'sizePx')))
        .thenAnswer((_) => answer());
  }

  group('ArtworkRepository', () {
    test('rounds sizes up to a bucket', () {
      expect(ArtworkRepository.bucketFor(48, 2), 128);
      expect(ArtworkRepository.bucketFor(48, 3), 256);
      expect(ArtworkRepository.bucketFor(320, 3), 1024);
      expect(ArtworkRepository.bucketFor(600, 3), 1024);
    });

    test('loads once and serves later requests from memory', () async {
      stubArtwork(() async => bytes);
      final repository = ArtworkRepository(source);

      expect(await repository.load(song, 256), bytes);
      expect(repository.isCached(song, 256), isTrue);
      expect(repository.cached(song, 256), bytes);
      expect(await repository.load(song, 256), bytes);
      verify(() => source.fetchArtwork(song, sizePx: 256)).called(1);
    });

    test('shares one platform call between simultaneous requests', () async {
      stubArtwork(() async => bytes);
      final repository = ArtworkRepository(source);

      await Future.wait([repository.load(song, 256), repository.load(song, 256)]);
      verify(() => source.fetchArtwork(song, sizePx: 256)).called(1);
    });

    test('remembers songs without artwork', () async {
      stubArtwork(() async => null);
      final repository = ArtworkRepository(source);

      expect(await repository.load(song, 256), isNull);
      expect(repository.isCached(song, 256), isTrue);
      await repository.load(song, 256);
      verify(() => source.fetchArtwork(song, sizePx: 256)).called(1);
    });

    test('treats a platform error as no artwork', () async {
      stubArtwork(() async => throw Exception('boom'));
      final repository = ArtworkRepository(source);
      expect(await repository.load(song, 256), isNull);
    });

    test('evicts the least recently used entry', () async {
      stubArtwork(() async => bytes);
      final repository = ArtworkRepository(source, maxEntries: 2);
      final [a, b, c] = testSongs.take(3).toList();

      await repository.load(a, 128);
      await repository.load(b, 128);
      repository.cached(a, 128); // a is now more recent than b
      await repository.load(c, 128);

      expect(repository.isCached(a, 128), isTrue);
      expect(repository.isCached(b, 128), isFalse);
      expect(repository.isCached(c, 128), isTrue);
    });
  });
}
