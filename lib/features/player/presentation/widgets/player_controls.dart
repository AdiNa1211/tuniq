import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tuniq/features/player/presentation/cubit/player_cubit.dart';
import 'package:tuniq/features/player/presentation/cubit/player_state.dart';

class PlayerControls extends StatelessWidget {
  const PlayerControls({required this.state, super.key});

  final PlayerState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PlayerCubit>();
    final repeatLabel = switch (state.repeatMode) {
      PlayerRepeatMode.off => 'Repeat off',
      PlayerRepeatMode.all => 'Repeat all',
      PlayerRepeatMode.one => 'Repeat one',
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          tooltip: state.shuffle ? 'Shuffle on' : 'Shuffle off',
          isSelected: state.shuffle,
          icon: const Icon(Icons.shuffle),
          onPressed: cubit.toggleShuffle,
        ),
        IconButton(
          tooltip: 'Previous',
          iconSize: 36,
          icon: const Icon(Icons.skip_previous),
          onPressed: cubit.previous,
        ),
        IconButton.filled(
          tooltip: state.playing ? 'Pause' : 'Play',
          iconSize: 40,
          icon: Icon(state.playing ? Icons.pause : Icons.play_arrow),
          onPressed: cubit.togglePlay,
        ),
        IconButton(
          tooltip: 'Next',
          iconSize: 36,
          icon: const Icon(Icons.skip_next),
          onPressed: cubit.next,
        ),
        IconButton(
          tooltip: repeatLabel,
          isSelected: state.repeatMode != PlayerRepeatMode.off,
          icon: Icon(state.repeatMode == PlayerRepeatMode.one ? Icons.repeat_one : Icons.repeat),
          onPressed: cubit.cycleRepeat,
        ),
      ],
    );
  }
}
