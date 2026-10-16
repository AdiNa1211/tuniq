import 'package:tuniq/features/library/data/device_library_source.dart';
import 'package:tuniq/features/library/data/imported_songs_source.dart';
import 'package:tuniq/features/library/data/library_cache.dart';
import 'package:tuniq/features/library/domain/library_permission.dart';
import 'package:tuniq/features/library/domain/song.dart';

class LibraryRepository {
  LibraryRepository(this._source, this._cache, {ImportedSongsSource? imported})
      : _imported = imported;

  final DeviceLibrarySource _source;
  final LibraryCache _cache;
  final ImportedSongsSource? _imported;

  bool get supportsImport => _imported != null;

  Future<LibraryPermission> permissionStatus() => _source.permissionStatus();

  Future<LibraryPermission> requestPermission() => _source.requestPermission();

  Future<void> openSettings() => _source.openSettings();

  /// The last scan, if any, for an instant first screen.
  Future<List<Song>?> cachedSongs() => _cache.read();

  /// Scans the device (plus imported files), sorts by title and refreshes
  /// the cache.
  Future<List<Song>> loadSongs() async {
    final imported = await _imported?.fetchSongs() ?? const <Song>[];
    final songs = List<Song>.unmodifiable(
      [...await _source.fetchSongs(), ...imported]
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())),
    );
    try {
      await _cache.write(songs);
    } on Object {
      // A failed cache write only costs the next cold start; keep the scan.
    }
    return songs;
  }

  /// Opens the Files picker; returns how many songs were added.
  Future<int> importFiles() async => await _imported?.pickAndImport() ?? 0;

  /// Removes the cached song list, e.g. after access is revoked.
  Future<void> clearCache() => _cache.clear();
}
