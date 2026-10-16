import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuniq/features/library/data/device_library_source.dart';
import 'package:tuniq/features/library/domain/library_permission.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mockChannel(String name, Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async => handler(call));
  }

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(
        const MethodChannel(MethodChannelLibrarySource.androidChannel),
        null,
      )
      ..setMockMethodCallHandler(
        const MethodChannel(MethodChannelLibrarySource.iosChannel),
        null,
      );
  });

  Map<String, Object?> songMap(String id, {Map<String, Object?> extra = const {}}) => {
        'id': id,
        'title': 'Song $id',
        'artist': 'Artist',
        'album': 'Album',
        'albumId': '42',
        'durationMs': 185000,
        'trackNumber': 3,
        'dateAdded': 1700000000,
        'folder': 'Music/Artist',
        'assetUrl': 'content://media/external/audio/media/$id',
        'isCloudItem': false,
        'hasProtectedAsset': false,
        ...extra,
      };

  group('MethodChannelLibrarySource', () {
    test('maps a song map to a Song', () async {
      mockChannel(MethodChannelLibrarySource.androidChannel, (_) => [songMap('1')]);
      final songs = await MethodChannelLibrarySource(isIOS: false).fetchSongs();

      final song = songs.single;
      expect(song.id, '1');
      expect(song.uri, Uri.parse('content://media/external/audio/media/1'));
      expect(song.duration, const Duration(seconds: 185));
      expect(song.trackNumber, 3);
      expect(song.folderPath, 'Music/Artist');
      expect(song.dateAdded, DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000));
    });

    test('skips cloud-only, protected and URL-less songs', () async {
      mockChannel(MethodChannelLibrarySource.iosChannel, (_) => [
            songMap('1'),
            songMap('2', extra: {'isCloudItem': true}),
            songMap('3', extra: {'hasProtectedAsset': true}),
            songMap('4', extra: {'assetUrl': null}),
          ]);
      final songs = await MethodChannelLibrarySource(isIOS: true).fetchSongs();
      expect(songs.map((s) => s.id), ['1']);
    });

    test('treats a zero track number as unknown', () async {
      mockChannel(
        MethodChannelLibrarySource.iosChannel,
        (_) => [songMap('1', extra: {'trackNumber': 0})],
      );
      final songs = await MethodChannelLibrarySource(isIOS: true).fetchSongs();
      expect(songs.single.trackNumber, isNull);
    });

    test('maps Android permission results', () async {
      final source = MethodChannelLibrarySource(isIOS: false);
      for (final (status, expected) in [
        ('authorized', LibraryPermission.granted),
        ('denied', LibraryPermission.denied),
        ('permanentlyDenied', LibraryPermission.permanentlyDenied),
      ]) {
        mockChannel(MethodChannelLibrarySource.androidChannel, (_) => status);
        expect(await source.requestPermission(), expected, reason: status);
      }
    });

    test('treats an iOS denial as permanent', () async {
      final source = MethodChannelLibrarySource(isIOS: true);
      for (final (status, expected) in [
        ('authorized', LibraryPermission.granted),
        ('notDetermined', LibraryPermission.denied),
        ('denied', LibraryPermission.permanentlyDenied),
        ('restricted', LibraryPermission.permanentlyDenied),
      ]) {
        mockChannel(MethodChannelLibrarySource.iosChannel, (_) => status);
        expect(await source.permissionStatus(), expected, reason: status);
      }
    });
  });
}
