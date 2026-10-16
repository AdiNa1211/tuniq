import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuniq/features/library/data/imported_songs_source.dart';

/// A tiny valid WAV (silence, no tags), enough for the import path.
Uint8List _silentWav() {
  const sampleRate = 8000;
  const samples = 800;
  final data = ByteData(44 + samples * 2)
    ..setUint32(0, 0x52494646) // "RIFF"
    ..setUint32(4, 36 + samples * 2, Endian.little)
    ..setUint32(8, 0x57415645) // "WAVE"
    ..setUint32(12, 0x666d7420) // "fmt "
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x64617461) // "data"
    ..setUint32(40, samples * 2, Endian.little);
  return data.buffer.asUint8List();
}

void main() {
  late Directory docs;
  late Directory picks;
  late ImportedSongsSource source;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('imported_docs');
    picks = await Directory.systemTemp.createTemp('imported_picks');
    source = ImportedSongsSource(documents: () async => docs);
  });

  tearDown(() async {
    await docs.delete(recursive: true);
    await picks.delete(recursive: true);
  });

  Future<String> pickedFile(String name) async {
    final file = File('${picks.path}/$name');
    await file.writeAsBytes(_silentWav());
    return file.path;
  }

  group('ImportedSongsSource', () {
    test('copies playable files and skips other formats', () async {
      final added = await source.importFiles([
        await pickedFile('Morning.wav'),
        await pickedFile('notes.txt'),
        await pickedFile('Song.ogg'),
      ]);
      expect(added, 1);
      expect(File('${docs.path}/Imported/Morning.wav').existsSync(), isTrue);
    });

    test('keeps both files when names collide', () async {
      final path = await pickedFile('Song.wav');
      await source.importFiles([path]);
      await source.importFiles([path]);
      expect(File('${docs.path}/Imported/Song (1).wav').existsSync(), isTrue);
    });

    test('lists imported songs, titled by file name when untagged', () async {
      await source.importFiles([await pickedFile('Evening Walk.wav')]);
      final songs = await source.fetchSongs();

      final song = songs.single;
      expect(song.title, 'Evening Walk');
      expect(song.id, 'imported:Evening Walk.wav');
      expect(song.uri.isScheme('file'), isTrue);
      expect(song.folderPath, 'Imported');
    });

    test('has no artwork for an untagged file', () async {
      await source.importFiles([await pickedFile('Plain.wav')]);
      final song = (await source.fetchSongs()).single;
      expect(await source.fetchArtwork(song), isNull);
    });
  });
}
