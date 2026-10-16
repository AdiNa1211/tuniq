import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tuniq/core/utils/duration_format.dart';
import 'package:tuniq/features/library/domain/song.dart';
import 'package:tuniq/features/library/presentation/widgets/song_artwork.dart';
import 'package:tuniq/features/queue/presentation/cubit/queue_cubit.dart';

/// Tap plays; long-press offers Play next and Add to queue.
class SongTile extends StatelessWidget {
  const SongTile({required this.song, required this.onTap, super.key});

  final Song song;
  final VoidCallback onTap;

  void _showActions(BuildContext context) {
    final queue = context.read<QueueCubit>();
    final messenger = ScaffoldMessenger.of(context);
    void done(BuildContext sheetContext, String message) {
      Navigator.of(sheetContext).pop();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_play),
              title: const Text('Play next'),
              onTap: () {
                queue.playNext(song);
                done(sheetContext, '"${song.title}" plays next');
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: const Text('Add to queue'),
              onTap: () {
                queue.addToQueue(song);
                done(sheetContext, 'Added "${song.title}" to the queue');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = [song.artist, song.album].where((s) => s.isNotEmpty).join(' · ');
    return ListTile(
      leading: SongArtwork(song: song, size: 48),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(formatDuration(song.duration)),
      onTap: onTap,
      onLongPress: () => _showActions(context),
    );
  }
}
