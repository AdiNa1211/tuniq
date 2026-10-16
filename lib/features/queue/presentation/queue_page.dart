import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tuniq/core/utils/duration_format.dart';
import 'package:tuniq/features/library/presentation/widgets/song_artwork.dart';
import 'package:tuniq/features/player/presentation/cubit/player_cubit.dart';
import 'package:tuniq/features/player/presentation/cubit/player_state.dart';

/// Read-only queue for Phase 2; reorder and remove arrive with QueueCubit in Phase 4.
class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Queue')),
      body: BlocBuilder<PlayerCubit, PlayerState>(
        builder: (context, state) {
          if (state.queue.isEmpty) {
            return const Center(child: Text('Your queue is empty'));
          }
          final primary = Theme.of(context).colorScheme.primary;
          return ListView.builder(
            itemCount: state.queue.length,
            itemBuilder: (context, i) {
              final song = state.queue[i];
              final isCurrent = i == state.currentIndex;
              return ListTile(
                selected: isCurrent,
                leading: SongArtwork(song: song, size: 40),
                title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: isCurrent
                    ? Icon(Icons.graphic_eq, color: primary, semanticLabel: 'Now playing')
                    : Text(formatDuration(song.duration)),
                onTap: () => context.read<PlayerCubit>().skipToIndex(i),
              );
            },
          );
        },
      ),
    );
  }
}
