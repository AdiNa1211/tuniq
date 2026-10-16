import 'package:equatable/equatable.dart';

class Song extends Equatable {
  const Song({
    required this.id,
    required this.uri,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumId,
    required this.duration,
    this.artworkRef,
    this.trackNumber,
    this.folderPath,
    this.dateAdded,
  });

  final String id;
  final Uri uri;
  final String title;
  final String artist;
  final String album;
  final String albumId;
  final Duration duration;
  final String? artworkRef;
  final int? trackNumber;
  final String? folderPath;
  final DateTime? dateAdded;

  @override
  List<Object?> get props => [
        id,
        uri,
        title,
        artist,
        album,
        albumId,
        duration,
        artworkRef,
        trackNumber,
        folderPath,
        dateAdded,
      ];
}
