import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tuniq/app/routes.dart';
import 'package:tuniq/features/library/domain/song_group.dart';
import 'package:tuniq/features/library/presentation/bloc/library_bloc.dart';
import 'package:tuniq/features/library/presentation/widgets/play_buttons.dart';
import 'package:tuniq/features/library/presentation/widgets/song_artwork.dart';
import 'package:tuniq/features/library/presentation/widgets/song_tile.dart';
import 'package:tuniq/features/player/presentation/cubit/player_cubit.dart';

class ArtistPage extends StatelessWidget {
  const ArtistPage({required this.artistKey, required this.basePath, super.key});

  final String artistKey;

  /// Tab the page was opened from, so links stay in that tab.
  final String basePath;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBloc, LibraryState>(
      builder: (context, state) {
        final songs = artistSongs(state.songs, artistKey);
        if (songs.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('This artist is no longer in your library.')),
          );
        }
        final name = songs.first.artistName;
        final albums = songs.groupedBy((s) => s.albumKey, titleOf: (s) => s.albumTitle);
        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(title: Text(name)),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              const SizedBox(height: 16),
              Center(
                child: ClipOval(child: SongArtwork(song: songs.first, size: 160, borderRadius: 0)),
              ),
              const SizedBox(height: 16),
              Text(name, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                '${albums.length} ${albums.length == 1 ? 'album' : 'albums'} · '
                '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              PlayButtons(songs: songs),
              _Header('Albums', style: theme.textTheme.titleMedium),
              for (final album in albums)
                ListTile(
                  leading: SongArtwork(song: album.songs.first, size: 48),
                  title: Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${album.songs.length} ${album.songs.length == 1 ? 'song' : 'songs'}',
                  ),
                  onTap: () => context.push(AppRoutes.album(basePath, album.key)),
                ),
              _Header('Songs', style: theme.textTheme.titleMedium),
              for (var i = 0; i < songs.length; i++)
                SongTile(
                  song: songs[i],
                  onTap: () => context.read<PlayerCubit>().playQueue(songs, startIndex: i),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, {this.style});

  final String title;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Semantics(header: true, child: Text(title, style: style)),
    );
  }
}
