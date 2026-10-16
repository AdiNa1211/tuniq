import 'package:equatable/equatable.dart';
import 'package:tuniq/features/library/domain/song.dart';
import 'package:tuniq/features/library/domain/song_group.dart';

class SearchResults extends Equatable {
  const SearchResults({
    this.songs = const [],
    this.albums = const [],
    this.artists = const [],
  });

  static const empty = SearchResults();

  final List<Song> songs;
  final List<SongGroup> albums;
  final List<SongGroup> artists;

  bool get isEmpty => songs.isEmpty && albums.isEmpty && artists.isEmpty;

  @override
  List<Object?> get props => [songs, albums, artists];
}

/// Case-insensitive search where every word must appear: "nova tide" finds
/// "Low Tide" by Nova Lane.
SearchResults searchLibrary(
  List<Song> songs,
  String query, {
  int songLimit = 50,
}) {
  final terms = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (terms.isEmpty) return SearchResults.empty;

  bool matches(String text) {
    final lower = text.toLowerCase();
    return terms.every(lower.contains);
  }

  return SearchResults(
    songs: songs
        .where((s) => matches('${s.title} ${s.artist} ${s.album}'))
        .take(songLimit)
        .toList(),
    albums: songs
        .where((s) => s.album.isNotEmpty && matches('${s.album} ${s.artist}'))
        .groupedBy((s) => s.albumKey, titleOf: (s) => s.albumTitle),
    artists: songs
        .where((s) => s.artist.isNotEmpty && matches(s.artist))
        .groupedBy((s) => s.artistKey, titleOf: (s) => s.artist),
  );
}
