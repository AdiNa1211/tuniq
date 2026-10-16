import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:tuniq/features/library/domain/song.dart';

/// Last scanned library as a JSON file, so the app can show songs instantly
/// while a fresh scan runs.
class LibraryCache {
  LibraryCache({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  static const _fileName = 'library_cache.json';
  // Bump when the stored shape changes; older files are then ignored.
  static const _version = 1;

  /// Null when there is no cache or it can't be read.
  Future<List<Song>?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
      if (json['version'] != _version) return null;
      return [
        for (final entry in json['songs']! as List<Object?>)
          _songFromJson(entry! as Map<String, Object?>),
      ];
    } on Object {
      return null;
    }
  }

  /// Writes to a temp file first so a crash mid-write can't corrupt the cache.
  Future<void> write(List<Song> songs) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode({'version': _version, 'songs': songs.map(_songToJson).toList()}),
    );
    await temp.rename(file.path);
  }

  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');

  static Map<String, Object?> _songToJson(Song song) => {
        'id': song.id,
        'uri': song.uri.toString(),
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'albumId': song.albumId,
        'durationMs': song.duration.inMilliseconds,
        'artworkRef': song.artworkRef,
        'trackNumber': song.trackNumber,
        'folderPath': song.folderPath,
        'dateAddedMs': song.dateAdded?.millisecondsSinceEpoch,
      };

  static Song _songFromJson(Map<String, Object?> json) {
    final addedMs = json['dateAddedMs'] as int?;
    return Song(
      id: json['id']! as String,
      uri: Uri.parse(json['uri']! as String),
      title: json['title']! as String,
      artist: json['artist']! as String,
      album: json['album']! as String,
      albumId: json['albumId']! as String,
      duration: Duration(milliseconds: json['durationMs']! as int),
      artworkRef: json['artworkRef'] as String?,
      trackNumber: json['trackNumber'] as int?,
      folderPath: json['folderPath'] as String?,
      dateAdded: addedMs == null ? null : DateTime.fromMillisecondsSinceEpoch(addedMs),
    );
  }
}
