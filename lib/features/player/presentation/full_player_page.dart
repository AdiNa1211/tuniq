import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tuniq/app/routes.dart';
import 'package:tuniq/features/player/presentation/cubit/player_cubit.dart';
import 'package:tuniq/features/player/presentation/cubit/player_state.dart';
import 'package:tuniq/features/player/presentation/widgets/now_playing_artwork.dart';
import 'package:tuniq/features/player/presentation/widgets/player_controls.dart';
import 'package:tuniq/features/player/presentation/widgets/seek_bar.dart';

/// Full-screen player. Swipe down to close: the page follows the finger and
/// springs back unless dragged far or flung fast enough.
class FullPlayerPage extends StatefulWidget {
  const FullPlayerPage({super.key});

  @override
  State<FullPlayerPage> createState() => _FullPlayerPageState();
}

class _FullPlayerPageState extends State<FullPlayerPage>
    with SingleTickerProviderStateMixin {
  static const _dismissDistance = 140.0;
  static const _dismissVelocity = 700.0;

  late final AnimationController _snapBack = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..addListener(_onSnapBackTick);

  double _dragOffset = 0;
  double _snapFrom = 0;

  @override
  void dispose() {
    _snapBack.dispose();
    super.dispose();
  }

  void _onSnapBackTick() {
    setState(() {
      _dragOffset = _snapFrom * (1 - Curves.easeOutCubic.transform(_snapBack.value));
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _snapBack.stop();
    setState(() => _dragOffset = math.max(0, _dragOffset + details.delta.dy));
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset > _dismissDistance || velocity > _dismissVelocity) {
      context.pop();
      return;
    }
    _snapFrom = _dragOffset;
    _snapBack.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Transform.translate(
        offset: Offset(0, _dragOffset),
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Close player',
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: () => context.pop(),
            ),
            title: const Text('Now playing'),
            actions: [
              IconButton(
                tooltip: 'Queue',
                icon: const Icon(Icons.queue_music),
                onPressed: () => context.push(AppRoutes.queue),
              ),
            ],
          ),
          body: SafeArea(
            child: BlocBuilder<PlayerCubit, PlayerState>(
              builder: (context, state) {
                final song = state.currentSong;
                if (song == null) {
                  return const Center(child: Text('Nothing is playing'));
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final art = Center(
                      child: NowPlayingArtwork(song: song, borderRadius: 16),
                    );
                    final details = _Details(state: state);
                    // Landscape and tablets put artwork beside the controls.
                    if (constraints.maxWidth > constraints.maxHeight) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Expanded(child: art),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Center(child: SingleChildScrollView(child: details)),
                            ),
                          ],
                        ),
                      );
                    }
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Expanded(child: art),
                              const SizedBox(height: 24),
                              details,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.state});

  final PlayerState state;

  @override
  Widget build(BuildContext context) {
    final song = state.currentSong!;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: text.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: text.titleMedium,
        ),
        // Remove in Phase 4, when the real audio engine plays songs.
        const SizedBox(height: 8),
        Text(
          'Sound arrives in Phase 4',
          textAlign: TextAlign.center,
          style: text.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SeekBar(
          position: state.position,
          duration: state.duration,
          onSeek: context.read<PlayerCubit>().seek,
        ),
        const SizedBox(height: 8),
        PlayerControls(state: state),
      ],
    );
  }
}
