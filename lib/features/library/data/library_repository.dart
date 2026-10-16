import 'package:tuniq/features/library/data/device_library_source.dart';
import 'package:tuniq/features/library/domain/library_permission.dart';
import 'package:tuniq/features/library/domain/song.dart';

class LibraryRepository {
  LibraryRepository(this._source);

  final DeviceLibrarySource _source;

  Future<LibraryPermission> permissionStatus() => _source.permissionStatus();

  Future<LibraryPermission> requestPermission() => _source.requestPermission();

  Future<void> openSettings() => _source.openSettings();

  /// All playable songs, sorted by title.
  Future<List<Song>> loadSongs() async {
    final songs = [...await _source.fetchSongs()]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return List.unmodifiable(songs);
  }
}
