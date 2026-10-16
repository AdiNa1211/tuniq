import 'package:flutter/material.dart';
import 'package:tuniq/core/utils/duration_format.dart';
import 'package:tuniq/features/library/domain/song.dart';
import 'package:tuniq/features/library/presentation/widgets/song_artwork.dart';

class SongTile extends StatelessWidget {
  const SongTile({required this.song, required this.onTap, super.key});

  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [song.artist, song.album].where((s) => s.isNotEmpty).join(' · ');
    return ListTile(
      leading: SongArtwork(song: song, size: 48),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(formatDuration(song.duration)),
      onTap: onTap,
    );
  }
}
