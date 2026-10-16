import 'dart:collection';
import 'dart:typed_data';

import 'package:tuniq/features/library/data/device_library_source.dart';
import 'package:tuniq/features/library/domain/song.dart';

/// In-memory artwork cache. Remembers "no artwork" too, so songs without
/// art don't hit the platform channel on every scroll.
class ArtworkRepository {
  ArtworkRepository(this._source, {this.maxEntries = 300});

  final DeviceLibrarySource _source;
  final int maxEntries;

  // Insertion order doubles as LRU order: a hit re-inserts its key.
  final _cache = LinkedHashMap<String, Uint8List?>();
  final _inFlight = <String, Future<Uint8List?>>{};

  static const _buckets = [128, 256, 512, 1024];

  /// Rounds a requested size up to a fixed bucket so a song isn't cached
  /// at many slightly different sizes.
  static int bucketFor(double logicalSize, double devicePixelRatio) {
    final px = logicalSize * devicePixelRatio;
    return _buckets.firstWhere((b) => px <= b, orElse: () => _buckets.last);
  }

  bool isCached(Song song, int sizePx) => _cache.containsKey(_key(song, sizePx));

  Uint8List? cached(Song song, int sizePx) {
    final key = _key(song, sizePx);
    if (!_cache.containsKey(key)) return null;
    final bytes = _cache.remove(key);
    _cache[key] = bytes;
    return bytes;
  }

  Future<Uint8List?> load(Song song, int sizePx) {
    final key = _key(song, sizePx);
    if (_cache.containsKey(key)) return Future.value(cached(song, sizePx));
    return _inFlight[key] ??= _fetch(song, sizePx, key);
  }

  Future<Uint8List?> _fetch(Song song, int sizePx, String key) async {
    Uint8List? bytes;
    try {
      bytes = await _source.fetchArtwork(song, sizePx: sizePx);
    } catch (_) {
      bytes = null;
    } finally {
      _inFlight.remove(key);
    }
    _cache[key] = bytes;
    while (_cache.length > maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    return bytes;
  }

  static String _key(Song song, int sizePx) => '${song.id}@$sizePx';
}
