import 'package:equatable/equatable.dart';
import 'package:tuniq/features/library/domain/song.dart';

/// Songs sharing an album, artist or folder.
class SongGroup extends Equatable {
  const SongGroup({required this.title, required this.songs});

  final String title;
  final List<Song> songs;

  @override
  List<Object?> get props => [title, songs];
}

extension SongGrouping on Iterable<Song> {
  /// Groups songs by [keyOf], keeping song order inside each group and
  /// sorting groups by title, case-insensitively.
  List<SongGroup> groupedBy(String Function(Song song) keyOf) {
    final groups = <String, List<Song>>{};
    for (final song in this) {
      groups.putIfAbsent(keyOf(song), () => []).add(song);
    }
    return [
      for (final entry in groups.entries)
        SongGroup(title: entry.key, songs: List.unmodifiable(entry.value)),
    ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }
}
