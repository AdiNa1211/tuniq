import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tuniq/features/library/domain/song.dart';
import 'package:tuniq/features/player/presentation/cubit/player_cubit.dart';

/// Play / Shuffle row for album and artist pages.
class PlayButtons extends StatelessWidget {
  const PlayButtons({required this.songs, super.key});

  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerCubit>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => player.playQueue(songs),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => player.playQueue(songs, shuffle: true),
              icon: const Icon(Icons.shuffle),
              label: const Text('Shuffle'),
            ),
          ),
        ],
      ),
    );
  }
}
