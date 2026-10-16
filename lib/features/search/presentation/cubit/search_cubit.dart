import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tuniq/features/library/domain/library_search.dart';
import 'package:tuniq/features/library/domain/song.dart';

class SearchState extends Equatable {
  const SearchState({this.query = '', this.results = SearchResults.empty});

  final String query;
  final SearchResults results;

  @override
  List<Object?> get props => [query, results];
}

/// Searches the songs LibraryBloc already holds; waits for a pause in
/// typing so large libraries aren't searched on every keystroke.
class SearchCubit extends Cubit<SearchState> {
  SearchCubit({
    List<Song> songs = const [],
    this.debounce = const Duration(milliseconds: 250),
  })  : _songs = songs,
        super(const SearchState());

  final Duration debounce;
  List<Song> _songs;
  Timer? _timer;

  /// The library changed (rescan, import): refresh the current results.
  void songsChanged(List<Song> songs) {
    _songs = songs;
    if (state.query.isNotEmpty) _search(state.query);
  }

  void queryChanged(String query) {
    _timer?.cancel();
    if (query.trim().isEmpty) {
      emit(const SearchState());
      return;
    }
    _timer = Timer(debounce, () => _search(query));
  }

  void _search(String query) {
    if (isClosed) return;
    emit(SearchState(query: query, results: searchLibrary(_songs, query)));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
