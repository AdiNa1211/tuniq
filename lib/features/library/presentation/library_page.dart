import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tuniq/core/widgets/artwork.dart';
import 'package:tuniq/features/library/data/demo_songs.dart';
import 'package:tuniq/features/library/domain/song.dart';
import 'package:tuniq/features/library/domain/song_group.dart';
import 'package:tuniq/features/library/presentation/widgets/song_tile.dart';
import 'package:tuniq/features/player/presentation/cubit/player_cubit.dart';

/// Library tabs over demo data. Phase 3 moves the data into LibraryBloc.
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    // iOS has no user-visible music folders, so the tab is Android-only.
    final showFolders = defaultTargetPlatform == TargetPlatform.android;
    final songs = demoSongs;

    return DefaultTabController(
      length: showFolders ? 4 : 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Songs'),
              const Tab(text: 'Albums'),
              const Tab(text: 'Artists'),
              if (showFolders) const Tab(text: 'Folders'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SongsTab(songs: songs),
            _GroupsTab(
              groups: songs.groupedBy((s) => s.album.isEmpty ? 'Unknown album' : s.album),
              icon: Icons.album,
            ),
            _GroupsTab(
              groups: songs.groupedBy((s) => s.artist.isEmpty ? 'Unknown artist' : s.artist),
              icon: Icons.person,
            ),
            if (showFolders)
              _GroupsTab(
                groups: songs.groupedBy((s) => s.folderPath ?? 'Unknown folder'),
                icon: Icons.folder,
              ),
          ],
        ),
      ),
    );
  }
}

class _SongsTab extends StatelessWidget {
  const _SongsTab({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: songs.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return const _DemoNotice();
        final index = i - 1;
        return SongTile(
          song: songs[index],
          onTap: () => context.read<PlayerCubit>().playQueue(songs, startIndex: index),
        );
      },
    );
  }
}

class _GroupsTab extends StatelessWidget {
  const _GroupsTab({required this.groups, required this.icon});

  final List<SongGroup> groups;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final group = groups[i];
        final count = group.songs.length;
        // Detail pages arrive in Phase 3; for now a tap plays the group.
        return ListTile(
          leading: group.songs.first.albumId.isEmpty
              ? Icon(icon)
              : Artwork(seed: group.songs.first.albumId, size: 48),
          title: Text(group.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('$count ${count == 1 ? 'song' : 'songs'}'),
          onTap: () => context.read<PlayerCubit>().playQueue(group.songs),
        );
      },
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('Demo songs: no audio yet'),
      subtitle: const Text(
        'Controls are simulated. Your own music arrives in Phase 3, sound in Phase 4.',
      ),
      textColor: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
