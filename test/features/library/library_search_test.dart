import 'package:flutter_test/flutter_test.dart';
import 'package:tuniq/features/library/domain/library_search.dart';

import '../../helpers/fixtures.dart';

void main() {
  group('searchLibrary', () {
    test('returns nothing for a blank query', () {
      expect(searchLibrary(testSongs, '   '), SearchResults.empty);
    });

    test('matches songs by title, ignoring case', () {
      final results = searchLibrary(testSongs, 'NEON');
      expect(results.songs.map((s) => s.title), ['Neon Rain']);
    });

    test('requires every word to match', () {
      final results = searchLibrary(testSongs, 'nova tide');
      expect(results.songs.map((s) => s.title), ['Low Tide']);
    });

    test('finds artists and their albums', () {
      final results = searchLibrary(testSongs, 'quiet static');
      expect(results.artists.map((a) => a.title), ['The Quiet Static']);
      expect(results.albums.map((a) => a.title), ['Afterglow']);
      expect(results.songs, hasLength(2));
    });

    test('caps the number of songs', () {
      final results = searchLibrary(testSongs, 'a', songLimit: 3);
      expect(results.songs, hasLength(3));
    });

    test('reports no results', () {
      expect(searchLibrary(testSongs, 'zzz').isEmpty, isTrue);
    });
  });
}
