import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tuniq/app/routes.dart';
import 'package:tuniq/features/library/domain/library_search.dart';
import 'package:tuniq/features/library/domain/song_group.dart';
import 'package:tuniq/features/library/presentation/bloc/library_bloc.dart';
import 'package:tuniq/features/library/presentation/widgets/song_artwork.dart';
import 'package:tuniq/features/library/presentation/widgets/song_tile.dart';
import 'package:tuniq/features/player/presentation/cubit/player_cubit.dart';
import 'package:tuniq/features/search/presentation/cubit/search_cubit.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SearchCubit(songs: context.read<LibraryBloc>().state.songs),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    context.read<SearchCubit>().queryChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SearchCubit>();
    return BlocListener<LibraryBloc, LibraryState>(
      listenWhen: (previous, current) => previous.songs != current.songs,
      listener: (context, state) => cubit.songsChanged(state.songs),
      child: Scaffold(
        appBar: AppBar(title: const Text('Search')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) => TextField(
                  controller: _controller,
                  onChanged: cubit.queryChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Songs, artists, albums',
                    border: const OutlineInputBorder(),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: _clear,
                          ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: BlocBuilder<SearchCubit, SearchState>(
                builder: (context, state) {
                  if (state.query.isEmpty) {
                    return const _Hint(
                      icon: Icons.manage_search,
                      text: 'Search your songs, albums and artists.',
                    );
                  }
                  if (state.results.isEmpty) {
                    return _Hint(
                      icon: Icons.search_off,
                      text: 'No results for "${state.query}".',
                    );
                  }
                  return _Results(results: state.results);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.results});

  final SearchResults results;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    const base = AppRoutes.search;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (results.artists.isNotEmpty) ...[
          _Section('Artists', style: style),
          for (final artist in results.artists)
            ListTile(
              leading: ClipOval(
                child: SongArtwork(song: artist.songs.first, size: 48, borderRadius: 0),
              ),
              title: Text(artist.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(_count(artist.songs.length)),
              onTap: () => context.push(AppRoutes.artist(base, artist.key)),
            ),
        ],
        if (results.albums.isNotEmpty) ...[
          _Section('Albums', style: style),
          for (final album in results.albums)
            ListTile(
              leading: SongArtwork(song: album.songs.first, size: 48),
              title: Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(album.songs.first.artistName, maxLines: 1),
              onTap: () => context.push(AppRoutes.album(base, album.key)),
            ),
        ],
        if (results.songs.isNotEmpty) ...[
          _Section('Songs', style: style),
          for (var i = 0; i < results.songs.length; i++)
            SongTile(
              song: results.songs[i],
              onTap: () =>
                  context.read<PlayerCubit>().playQueue(results.songs, startIndex: i),
            ),
        ],
      ],
    );
  }

  static String _count(int n) => '$n ${n == 1 ? 'song' : 'songs'}';
}

class _Section extends StatelessWidget {
  const _Section(this.title, {this.style});

  final String title;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(header: true, child: Text(title, style: style)),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}
