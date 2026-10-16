import 'package:flutter_test/flutter_test.dart';
import 'package:tuniq/core/utils/duration_format.dart';
import 'package:tuniq/features/library/domain/song.dart';
import 'package:tuniq/features/library/domain/song_group.dart';

import '../../helpers/fixtures.dart';

void main() {
  Song song(String title, {int? track, String album = 'A', String albumId = 'x'}) => Song(
        id: title,
        uri: Uri.parse('content://$title'),
        title: title,
        artist: 'Artist',
        album: album,
        albumId: albumId,
        duration: const Duration(minutes: 3),
        trackNumber: track,
      );

  group('groupedBy', () {
    test('sorts groups by title, ignoring case', () {
      final groups = testSongs.groupedBy((s) => s.artist);
      expect(groups.map((g) => g.title), ['Ira Moss', 'Nova Lane', 'The Quiet Static']);
    });

    test('keeps song order inside a group', () {
      final ira = testSongs.groupedBy((s) => s.artist).first;
      expect(
        ira.songs.map((s) => s.title),
        ['Small Victories', 'Northbound', 'Last Train Home'],
      );
    });

    test('uses titleOf for the title and keyOf for the key', () {
      final group = testSongs.groupedBy((s) => s.albumKey, titleOf: (s) => s.albumTitle).first;
      expect(group.key, 'a2');
      expect(group.title, 'Afterglow');
    });
  });

  group('song keys', () {
    test('albumKey prefers the album ID over the name', () {
      expect(song('t', albumId: '42').albumKey, '42');
      expect(song('t', album: 'Blue', albumId: '').albumKey, 'album:blue');
    });

    test('names unknown albums and artists', () {
      final unknown = Song(
        id: '1',
        uri: Uri.parse('content://1'),
        title: 't',
        artist: '',
        album: '',
        albumId: '',
        duration: Duration.zero,
      );
      expect(unknown.albumTitle, 'Unknown album');
      expect(unknown.artistName, 'Unknown artist');
      expect(unknown.artistKey, isEmpty);
    });
  });

  group('albumTracks', () {
    test('orders by track number, unnumbered tracks last', () {
      final tracks = albumTracks([
        song('Bonus'),
        song('Second', track: 2),
        song('First', track: 1),
        song('Other album', track: 1, albumId: 'y'),
      ], 'x');
      expect(tracks.map((s) => s.title), ['First', 'Second', 'Bonus']);
    });
  });

  group('artistSongs', () {
    test('groups by album, then track', () {
      final songs = artistSongs([
        song('B2', track: 2, album: 'Beta'),
        song('A1', track: 1, album: 'Alpha'),
        song('B1', track: 1, album: 'Beta'),
      ], 'artist');
      expect(songs.map((s) => s.title), ['A1', 'B1', 'B2']);
    });
  });

  group('formatDuration', () {
    test('formats minutes and seconds', () {
      expect(formatDuration(const Duration(seconds: 5)), '0:05');
      expect(formatDuration(const Duration(minutes: 3, seconds: 42)), '3:42');
    });

    test('adds hours when needed', () {
      expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    });

    test('formats album lengths', () {
      expect(formatTotalDuration(const Duration(minutes: 42, seconds: 50)), '42 min');
      expect(formatTotalDuration(const Duration(hours: 1, minutes: 5)), '1 hr 5 min');
    });
  });
}
