import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tuniq/features/library/domain/song.dart';
import 'package:tuniq/features/library/domain/song_group.dart';
import 'package:tuniq/features/library/presentation/bloc/library_bloc.dart';
import 'package:tuniq/features/library/presentation/widgets/permission_gate.dart';
import 'package:tuniq/features/library/presentation/widgets/song_artwork.dart';
import 'package:tuniq/features/library/presentation/widgets/song_tile.dart';
import 'package:tuniq/features/player/presentation/cubit/player_cubit.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Permission can change in Settings while the app is in the background.
    _lifecycle = AppLifecycleListener(
      onResume: () => context.read<LibraryBloc>().add(const LibraryResumed()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LibraryBloc, LibraryState>(
      // Songs are still on screen, so a failed rescan only needs a notice.
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == LibraryStatus.failure &&
          current.songs.isNotEmpty,
      listener: (context, state) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't refresh your music.")),
      ),
      builder: (context, state) {
        final bloc = context.read<LibraryBloc>();
        final permission = state.permission;

        if (permission == null) return const _Plain(child: _Loading());
        if (!state.hasPermission) {
          return _Plain(
            child: PermissionGate(
              permission: permission,
              onAllow: () => bloc.add(const LibraryPermissionRequested()),
              onOpenSettings: () => bloc.add(const LibrarySettingsOpened()),
            ),
          );
        }
        if (state.songs.isEmpty) {
          return _Plain(
            child: switch (state.status) {
              LibraryStatus.initial || LibraryStatus.loading => const _Loading(),
              LibraryStatus.failure => _Message(
                  icon: Icons.error_outline,
                  title: state.errorMessage ?? 'Something went wrong.',
                  action: 'Try again',
                  onAction: () => bloc.add(const LibraryRefreshed()),
                ),
              LibraryStatus.success => _Message(
                  icon: Icons.music_off,
                  title: 'No music found',
                  body: defaultTargetPlatform == TargetPlatform.iOS
                      ? 'Download DRM-free songs to the Music app, then scan again.'
                      : 'Copy music files to your phone, then scan again.',
                  action: 'Scan again',
                  onAction: () => bloc.add(const LibraryRefreshed()),
                ),
            },
          );
        }
        return _LibraryTabs(
          songs: state.songs,
          refreshing: state.status == LibraryStatus.loading,
        );
      },
    );
  }
}

class _LibraryTabs extends StatelessWidget {
  const _LibraryTabs({required this.songs, required this.refreshing});

  final List<Song> songs;
  final bool refreshing;

  // Completes when the scan finishes; the timeout guards an ignored refresh.
  Future<void> _refresh(BuildContext context) async {
    final bloc = context.read<LibraryBloc>()..add(const LibraryRefreshed());
    await bloc.stream
        .firstWhere((s) => s.status != LibraryStatus.loading)
        .timeout(const Duration(seconds: 30), onTimeout: () => bloc.state);
  }

  @override
  Widget build(BuildContext context) {
    // iOS has no user-visible music folders, so the tab is Android-only.
    final showFolders = defaultTargetPlatform == TargetPlatform.android;
    Future<void> onRefresh() => _refresh(context);

    return DefaultTabController(
      length: showFolders ? 4 : 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          bottom: _TabsWithProgress(
            refreshing: refreshing,
            tabBar: TabBar(
              tabs: [
                const Tab(text: 'Songs'),
                const Tab(text: 'Albums'),
                const Tab(text: 'Artists'),
                if (showFolders) const Tab(text: 'Folders'),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: onRefresh,
              child: _SongsTab(songs: songs),
            ),
            RefreshIndicator(
              onRefresh: onRefresh,
              child: _GroupsTab(
                groups: songs.groupedBy((s) => s.album.isEmpty ? 'Unknown album' : s.album),
              ),
            ),
            RefreshIndicator(
              onRefresh: onRefresh,
              child: _GroupsTab(
                groups: songs.groupedBy((s) => s.artist.isEmpty ? 'Unknown artist' : s.artist),
              ),
            ),
            if (showFolders)
              RefreshIndicator(
                onRefresh: onRefresh,
                child: _GroupsTab(
                  groups: songs.groupedBy((s) => s.folderPath ?? 'Unknown folder'),
                ),
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
      itemCount: songs.length,
      itemBuilder: (context, i) => SongTile(
        song: songs[i],
        onTap: () => context.read<PlayerCubit>().playQueue(songs, startIndex: i),
      ),
    );
  }
}

class _GroupsTab extends StatelessWidget {
  const _GroupsTab({required this.groups});

  final List<SongGroup> groups;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final group = groups[i];
        final count = group.songs.length;
        // Detail pages arrive later in Phase 3; for now a tap plays the group.
        return ListTile(
          leading: SongArtwork(song: group.songs.first, size: 48),
          title: Text(group.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('$count ${count == 1 ? 'song' : 'songs'}'),
          onTap: () => context.read<PlayerCubit>().playQueue(group.songs),
        );
      },
    );
  }
}

/// Tab bar with a thin progress line while a background rescan runs.
class _TabsWithProgress extends StatelessWidget implements PreferredSizeWidget {
  const _TabsWithProgress({required this.tabBar, required this.refreshing});

  final TabBar tabBar;
  final bool refreshing;

  static const _barHeight = 2.0;

  @override
  Size get preferredSize => Size.fromHeight(tabBar.preferredSize.height + _barHeight);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        tabBar,
        if (refreshing)
          const LinearProgressIndicator(minHeight: _barHeight)
        else
          const SizedBox(height: _barHeight),
      ],
    );
  }
}

/// Library scaffold without tabs, for the gate, loading and empty states.
class _Plain extends StatelessWidget {
  const _Plain({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Library')), body: child);
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Finding your music…'),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.action,
    required this.onAction,
    this.body,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(body!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    );
  }
}
