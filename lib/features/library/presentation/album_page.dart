import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tuniq/app/routes.dart';
import 'package:tuniq/core/utils/duration_format.dart';
import 'package:tuniq/features/library/domain/song_group.dart';
import 'package:tuniq/features/library/presentation/bloc/library_bloc.dart';
import 'package:tuniq/features/library/presentation/widgets/play_buttons.dart';
import 'package:tuniq/features/library/presentation/widgets/song_artwork.dart';
import 'package:tuniq/features/player/presentation/cubit/player_cubit.dart';

class AlbumPage extends StatelessWidget {
  const AlbumPage({required this.albumKey, required this.basePath, super.key});

  final String albumKey;

  /// Tab the page was opened from, so links stay in that tab.
  final String basePath;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBloc, LibraryState>(
      builder: (context, state) {
        final tracks = albumTracks(state.songs, albumKey);
        if (tracks.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('This album is no longer in your library.')),
          );
        }
        final first = tracks.first;
        final total = tracks.fold(Duration.zero, (sum, s) => sum + s.duration);
        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(title: Text(first.albumTitle)),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              const SizedBox(height: 16),
              Center(child: SongArtwork(song: first, size: 200, borderRadius: 12)),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  first.albumTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: first.artistKey.isEmpty
                      ? null
                      : () => context.push(AppRoutes.artist(basePath, first.artistKey)),
                  child: Text(first.artistName),
                ),
              ),
              Text(
                '${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'} · '
                '${formatTotalDuration(total)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              PlayButtons(songs: tracks),
              for (var i = 0; i < tracks.length; i++)
                ListTile(
                  leading: SizedBox(
                    width: 32,
                    child: Center(child: Text('${tracks[i].trackNumber ?? i + 1}')),
                  ),
                  title: Text(tracks[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  // Compilations: show the artist only when it differs.
                  subtitle: tracks[i].artist != first.artist && tracks[i].artist.isNotEmpty
                      ? Text(tracks[i].artist, maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: Text(formatDuration(tracks[i].duration)),
                  onTap: () => context.read<PlayerCubit>().playQueue(tracks, startIndex: i),
                ),
            ],
          ),
        );
      },
    );
  }
}
