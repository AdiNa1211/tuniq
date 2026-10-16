import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tuniq/features/library/domain/song.dart';

/// Songs copied in through the Files picker (iOS fallback for music that
/// isn't in the Music app). They live in Documents/Imported.
class ImportedSongsSource {
  ImportedSongsSource({Future<Directory> Function()? documents})
      : _documents = documents ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documents;

  /// Formats AVPlayer can play; OGG, Opus and WebM are left out.
  static const playableExtensions = {
    '.mp3',
    '.m4a',
    '.mp4',
    '.aac',
    '.wav',
    '.aif',
    '.aiff',
    '.aifc',
    '.flac',
  };

  /// Opens the Files picker and copies the chosen songs in.
  /// Returns how many were added.
  Future<int> pickAndImport() async {
    final picked = await FilePicker.pickFiles(type: FileType.audio);
    return importFiles([
      for (final file in picked)
        if (file.path != null) file.path!,
    ]);
  }

  Future<int> importFiles(List<String> paths) async {
    final folder = await _folder();
    var added = 0;
    for (final path in paths) {
      final name = path.split('/').last;
      if (!playableExtensions.contains(_extension(name))) continue;
      await File(path).copy(_uniquePath(folder, name));
      added++;
    }
    return added;
  }

  Future<List<Song>> fetchSongs() async {
    final folder = await _folder();
    final paths = [
      await for (final entry in folder.list())
        if (entry is File && playableExtensions.contains(_extension(entry.path)))
          entry.path,
    ];
    // Tag parsing is synchronous file I/O; keep it off the UI isolate.
    return Isolate.run(() => [for (final path in paths) _readSong(path)]);
  }

  Future<Uint8List?> fetchArtwork(Song song) {
    final path = song.uri.toFilePath();
    return Isolate.run(() {
      try {
        final pictures = readMetadata(File(path), getImage: true).pictures;
        return pictures.isEmpty ? null : pictures.first.bytes;
      } on Object {
        return null;
      }
    });
  }

  Future<Directory> _folder() async {
    final folder = Directory('${(await _documents()).path}/Imported');
    await folder.create(recursive: true);
    return folder;
  }

  static Song _readSong(String path) {
    AudioMetadata? meta;
    try {
      meta = readMetadata(File(path));
    } on Object {
      // Untagged or unreadable tags: fall back to the file name below.
    }
    final name = path.split('/').last;
    final stem = name.substring(0, name.length - _extension(name).length);
    final album = meta?.album?.trim() ?? '';
    return Song(
      id: 'imported:$name',
      uri: Uri.file(path),
      title: _nonEmpty(meta?.title) ?? stem,
      artist: _nonEmpty(meta?.artist) ?? '',
      album: album,
      albumId: album.isEmpty ? '' : 'imported:${album.toLowerCase()}',
      duration: meta?.duration ?? Duration.zero,
      trackNumber: meta?.trackNumber,
      folderPath: 'Imported',
      dateAdded: File(path).statSync().modified,
    );
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _extension(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? '' : name.substring(dot).toLowerCase();
  }

  /// "Song.mp3" → "Song (1).mp3" when the name is taken.
  static String _uniquePath(Directory folder, String name) {
    final ext = _extension(name);
    final stem = name.substring(0, name.length - ext.length);
    var candidate = '${folder.path}/$name';
    for (var n = 1; File(candidate).existsSync(); n++) {
      candidate = '${folder.path}/$stem ($n)$ext';
    }
    return candidate;
  }
}
