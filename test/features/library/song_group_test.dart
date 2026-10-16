import 'package:flutter_test/flutter_test.dart';
import 'package:tuniq/core/utils/duration_format.dart';
import 'package:tuniq/features/library/domain/song_group.dart';

import '../../helpers/fixtures.dart';

void main() {
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
  });

  group('formatDuration', () {
    test('formats minutes and seconds', () {
      expect(formatDuration(const Duration(seconds: 5)), '0:05');
      expect(formatDuration(const Duration(minutes: 3, seconds: 42)), '3:42');
    });

    test('adds hours when needed', () {
      expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    });
  });
}
