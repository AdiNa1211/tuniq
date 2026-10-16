import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tuniq/app/routes.dart';
import 'package:tuniq/features/player/presentation/cubit/player_cubit.dart';
import 'package:tuniq/features/player/presentation/cubit/player_state.dart';
import 'package:tuniq/features/player/presentation/widgets/now_playing_artwork.dart';

/// Compact player above the tab bar; hidden until something is queued.
/// Tap or swipe up to open the full player.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  static const _openVelocity = -300.0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerCubit, PlayerState>(
      builder: (context, state) {
        final song = state.currentSong;
        if (song == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final cubit = context.read<PlayerCubit>();
        void open() => context.push(AppRoutes.player);

        return GestureDetector(
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < _openVelocity) open();
          },
          child: Material(
            color: theme.colorScheme.surfaceContainerHigh,
            child: InkWell(
              onTap: open,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: state.progress, minHeight: 2),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    child: Row(
                      children: [
                        NowPlayingArtwork(song: song, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Semantics(
                            button: true,
                            label: 'Open player',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                                Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: state.playing ? 'Pause' : 'Play',
                          icon: Icon(state.playing ? Icons.pause : Icons.play_arrow),
                          onPressed: cubit.togglePlay,
                        ),
                        IconButton(
                          tooltip: 'Next',
                          icon: const Icon(Icons.skip_next),
                          onPressed: cubit.next,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
