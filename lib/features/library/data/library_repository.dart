import 'package:tuniq/features/library/data/device_library_source.dart';
import 'package:tuniq/features/library/data/library_cache.dart';
import 'package:tuniq/features/library/domain/library_permission.dart';
import 'package:tuniq/features/library/domain/song.dart';

class LibraryRepository {
  LibraryRepository(this._source, this._cache);

  final DeviceLibrarySource _source;
  final LibraryCache _cache;

  Future<LibraryPermission> permissionStatus() => _source.permissionStatus();

  Future<LibraryPermission> requestPermission() => _source.requestPermission();

  Future<void> openSettings() => _source.openSettings();

  /// The last scan, if any, for an instant first screen.
  Future<List<Song>?> cachedSongs() => _cache.read();

  /// Scans the device, sorts by title and refreshes the cache.
  Future<List<Song>> loadSongs() async {
    final songs = List<Song>.unmodifiable(
      [...await _source.fetchSongs()]
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())),
    );
    try {
      await _cache.write(songs);
    } on Object {
      // A failed cache write only costs the next cold start; keep the scan.
    }
    return songs;
  }

  /// Removes the cached song list, e.g. after access is revoked.
  Future<void> clearCache() => _cache.clear();
}
