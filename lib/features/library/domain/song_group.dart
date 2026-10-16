import 'package:equatable/equatable.dart';
import 'package:tuniq/features/library/domain/song.dart';

/// Songs sharing an album, artist or folder.
class SongGroup extends Equatable {
  const SongGroup({required this.key, required this.title, required this.songs});

  /// Stable identity (album ID, lowercased artist, folder path).
  final String key;
  final String title;
  final List<Song> songs;

  @override
  List<Object?> get props => [key, title, songs];
}

extension SongGrouping on Iterable<Song> {
  /// Groups songs by [keyOf], keeping song order inside each group and
  /// sorting groups by title, case-insensitively. [titleOf] defaults to the key.
  List<SongGroup> groupedBy(
    String Function(Song song) keyOf, {
    String Function(Song song)? titleOf,
  }) {
    final groups = <String, List<Song>>{};
    final titles = <String, String>{};
    for (final song in this) {
      final key = keyOf(song);
      groups.putIfAbsent(key, () => []).add(song);
      titles.putIfAbsent(key, () => (titleOf ?? keyOf)(song));
    }
    return [
      for (final entry in groups.entries)
        SongGroup(
          key: entry.key,
          title: titles[entry.key]!,
          songs: List.unmodifiable(entry.value),
        ),
    ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }
}

extension SongKeys on Song {
  /// Album ID when the platform gives one, so two albums sharing a name
  /// stay apart; otherwise the album name.
  String get albumKey => albumId.isNotEmpty ? albumId : 'album:${album.toLowerCase()}';

  /// Empty for songs without an artist.
  String get artistKey => artist.toLowerCase();

  String get albumTitle => album.isEmpty ? 'Unknown album' : album;

  String get artistName => artist.isEmpty ? 'Unknown artist' : artist;
}

/// Tracks of one album in track order (unnumbered tracks last, by title).
List<Song> albumTracks(Iterable<Song> songs, String albumKey) =>
    songs.where((s) => s.albumKey == albumKey).toList()..sort(_byTrack);

/// One artist's songs, grouped by album and in track order within each.
List<Song> artistSongs(Iterable<Song> songs, String artistKey) =>
    songs.where((s) => s.artistKey == artistKey).toList()
      ..sort((a, b) {
        final byAlbum = a.album.toLowerCase().compareTo(b.album.toLowerCase());
        return byAlbum != 0 ? byAlbum : _byTrack(a, b);
      });

int _byTrack(Song a, Song b) {
  final ta = a.trackNumber;
  final tb = b.trackNumber;
  if (ta != null && tb != null && ta != tb) return ta.compareTo(tb);
  if (ta != null && tb == null) return -1;
  if (ta == null && tb != null) return 1;
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}
