import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuniq/features/library/domain/library_search.dart';
import 'package:tuniq/features/search/presentation/cubit/search_cubit.dart';

import '../../helpers/fixtures.dart';

void main() {
  const debounce = Duration(milliseconds: 10);
  const wait = Duration(milliseconds: 50);

  group('SearchCubit', () {
    blocTest<SearchCubit, SearchState>(
      'searches after the debounce',
      build: () => SearchCubit(songs: testSongs, debounce: debounce),
      act: (cubit) => cubit.queryChanged('neon'),
      wait: wait,
      expect: () => [
        SearchState(query: 'neon', results: searchLibrary(testSongs, 'neon')),
      ],
    );

    blocTest<SearchCubit, SearchState>(
      'only searches the last query when typing fast',
      build: () => SearchCubit(songs: testSongs, debounce: debounce),
      act: (cubit) => cubit
        ..queryChanged('n')
        ..queryChanged('ne')
        ..queryChanged('neo'),
      wait: wait,
      expect: () => [
        SearchState(query: 'neo', results: searchLibrary(testSongs, 'neo')),
      ],
    );

    blocTest<SearchCubit, SearchState>(
      'clears results for a blank query',
      build: () => SearchCubit(songs: testSongs, debounce: debounce),
      seed: () => SearchState(query: 'neon', results: searchLibrary(testSongs, 'neon')),
      act: (cubit) => cubit.queryChanged(' '),
      expect: () => [const SearchState()],
    );

    blocTest<SearchCubit, SearchState>(
      're-runs the query when the library changes',
      build: () => SearchCubit(debounce: debounce),
      seed: () => const SearchState(query: 'neon'),
      act: (cubit) => cubit.songsChanged(testSongs),
      expect: () => [
        SearchState(query: 'neon', results: searchLibrary(testSongs, 'neon')),
      ],
    );
  });
}
