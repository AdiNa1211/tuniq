import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tuniq/core/utils/duration_format.dart';
import 'package:tuniq/features/library/presentation/widgets/song_artwork.dart';
import 'package:tuniq/features/queue/presentation/cubit/queue_cubit.dart';

/// Play order: drag the handle to reorder, swipe a song away to remove it.
class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Queue')),
      body: BlocBuilder<QueueCubit, QueueState>(
        builder: (context, state) {
          if (state.entries.isEmpty) {
            return const Center(child: Text('Your queue is empty'));
          }
          final cubit = context.read<QueueCubit>();
          final primary = Theme.of(context).colorScheme.primary;

          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: state.entries.length,
            onReorder: cubit.reorder,
            itemBuilder: (context, i) {
              final song = state.entries[i].song;
              final isCurrent = i == state.currentIndex;
              final tile = ListTile(
                selected: isCurrent,
                leading: SongArtwork(song: song, size: 40),
                title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  isCurrent ? 'Now playing' : formatDuration(song.duration),
                  maxLines: 1,
                ),
                trailing: ReorderableDragStartListener(
                  index: i,
                  child: Icon(
                    isCurrent ? Icons.graphic_eq : Icons.drag_handle,
                    color: isCurrent ? primary : null,
                    semanticLabel: 'Reorder ${song.title}',
                  ),
                ),
                onTap: isCurrent ? null : () => cubit.skipTo(i),
              );
              // The playing song can be moved but not removed.
              return isCurrent
                  ? KeyedSubtree(key: ValueKey(state.entries[i].id), child: tile)
                  : Dismissible(
                      key: ValueKey(state.entries[i].id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Theme.of(context).colorScheme.errorContainer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: const Icon(Icons.delete_outline),
                      ),
                      onDismissed: (_) => cubit.remove(i),
                      child: tile,
                    );
            },
          );
        },
      ),
    );
  }
}
