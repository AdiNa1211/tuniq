import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tuniq/features/library/domain/library_permission.dart';
import 'package:tuniq/features/library/domain/song.dart';

/// Reads music already on the device.
abstract interface class DeviceLibrarySource {
  Future<LibraryPermission> permissionStatus();
  Future<LibraryPermission> requestPermission();
  Future<void> openSettings();
  Future<List<Song>> fetchSongs();

  /// JPEG artwork scaled to about [sizePx] square, or null if the song has none.
  Future<Uint8List?> fetchArtwork(Song song, {required int sizePx});
}

/// Talks to the native channels: MediaStoreChannel.kt on Android and
/// MediaLibraryChannel in AppDelegate.swift on iOS. Both use the same
/// method names and song map keys.
class MethodChannelLibrarySource implements DeviceLibrarySource {
  MethodChannelLibrarySource({required bool isIOS})
      : _isIOS = isIOS,
        _channel = MethodChannel(isIOS ? iosChannel : androidChannel);

  factory MethodChannelLibrarySource.forPlatform() =>
      MethodChannelLibrarySource(isIOS: Platform.isIOS);

  static const androidChannel = 'tuniq/media_store';
  static const iosChannel = 'tuniq/ios_media_library';

  final bool _isIOS;
  final MethodChannel _channel;

  @override
  Future<LibraryPermission> permissionStatus() async =>
      _toPermission(await _channel.invokeMethod<String>('authorizationStatus'));

  @override
  Future<LibraryPermission> requestPermission() async =>
      _toPermission(await _channel.invokeMethod<String>('requestAuthorization'));

  @override
  Future<void> openSettings() => _channel.invokeMethod<void>('openSettings');

  @override
  Future<List<Song>> fetchSongs() async {
    final raw =
        await _channel.invokeListMethod<Map<Object?, Object?>>('querySongs') ?? const [];
    return [
      for (final map in raw)
        if (_isPlayable(map)) _toSong(map),
    ];
  }

  @override
  Future<Uint8List?> fetchArtwork(Song song, {required int sizePx}) =>
      _channel.invokeMethod<Uint8List>('artwork', {
        'id': song.id,
        'uri': song.uri.toString(),
        'albumId': song.albumId,
        'size': sizePx,
      });

  LibraryPermission _toPermission(String? status) => switch (status) {
        'authorized' => LibraryPermission.granted,
        'permanentlyDenied' || 'restricted' => LibraryPermission.permanentlyDenied,
        // iOS shows its prompt only once; after a denial only Settings helps.
        'denied' when _isIOS => LibraryPermission.permanentlyDenied,
        _ => LibraryPermission.denied,
      };

  // iOS: cloud-only and DRM-protected (Apple Music) items can't be played.
  static bool _isPlayable(Map<Object?, Object?> map) =>
      map['assetUrl'] is String &&
      map['isCloudItem'] != true &&
      map['hasProtectedAsset'] != true;

  static Song _toSong(Map<Object?, Object?> map) {
    final track = (map['trackNumber'] as num?)?.toInt();
    final addedSeconds = (map['dateAdded'] as num?)?.toInt();
    return Song(
      id: map['id']! as String,
      uri: Uri.parse(map['assetUrl']! as String),
      title: map['title'] as String? ?? '',
      artist: map['artist'] as String? ?? '',
      album: map['album'] as String? ?? '',
      albumId: map['albumId'] as String? ?? '',
      duration: Duration(milliseconds: (map['durationMs'] as num?)?.toInt() ?? 0),
      trackNumber: track == null || track <= 0 ? null : track,
      folderPath: map['folder'] as String?,
      dateAdded: addedSeconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(addedSeconds * 1000),
    );
  }
}
