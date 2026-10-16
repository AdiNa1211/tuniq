import 'package:tuniq/features/library/domain/song.dart';

/// Eight songs across three albums and artists.
final List<Song> testSongs = List.unmodifiable([
  _song(1, 'Golden Hour Drive', 'Nova Lane', 'Coastline', 'a1', 3, 42),
  _song(2, 'Paper Satellites', 'Nova Lane', 'Coastline', 'a1', 4, 5),
  _song(3, 'Low Tide', 'Nova Lane', 'Coastline', 'a1', 2, 58),
  _song(4, 'Neon Rain', 'The Quiet Static', 'Afterglow', 'a2', 3, 27),
  _song(5, 'Midnight Ferry', 'The Quiet Static', 'Afterglow', 'a2', 4, 12),
  _song(6, 'Small Victories', 'Ira Moss', 'Daylight Saving', 'a3', 3, 9),
  _song(7, 'Northbound', 'Ira Moss', 'Daylight Saving', 'a3', 3, 51),
  _song(8, 'Last Train Home', 'Ira Moss', 'Daylight Saving', 'a3', 4, 33),
]);

Song _song(
  int n,
  String title,
  String artist,
  String album,
  String albumId,
  int minutes,
  int seconds,
) =>
    Song(
      id: 'test-$n',
      uri: Uri.parse('content://media/external/audio/media/$n'),
      title: title,
      artist: artist,
      album: album,
      albumId: albumId,
      duration: Duration(minutes: minutes, seconds: seconds),
      folderPath: 'Music/$artist',
    );
