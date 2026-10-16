import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tuniq/features/library/domain/library_permission.dart';
import 'package:tuniq/features/library/presentation/bloc/library_bloc.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockLibraryRepository repository;

  const granted = LibraryState(permission: LibraryPermission.granted);
  final loaded = LibraryState(
    status: LibraryStatus.success,
    permission: LibraryPermission.granted,
    songs: testSongs,
  );

  setUp(() {
    repository = MockLibraryRepository();
    when(() => repository.loadSongs()).thenAnswer((_) async => testSongs);
    when(() => repository.openSettings()).thenAnswer((_) async {});
  });

  group('LibraryBloc', () {
    blocTest<LibraryBloc, LibraryState>(
      'loads songs on start when access is granted',
      setUp: () => when(() => repository.permissionStatus())
          .thenAnswer((_) async => LibraryPermission.granted),
      build: () => LibraryBloc(repository),
      act: (bloc) => bloc.add(const LibraryStarted()),
      expect: () => [
        granted,
        granted.copyWith(status: LibraryStatus.loading),
        loaded,
      ],
    );

    blocTest<LibraryBloc, LibraryState>(
      'asks for access on start when not granted',
      setUp: () => when(() => repository.permissionStatus())
          .thenAnswer((_) async => LibraryPermission.denied),
      build: () => LibraryBloc(repository),
      act: (bloc) => bloc.add(const LibraryStarted()),
      expect: () => [const LibraryState(permission: LibraryPermission.denied)],
      verify: (_) => verifyNever(() => repository.loadSongs()),
    );

    blocTest<LibraryBloc, LibraryState>(
      'loads songs after access is granted',
      setUp: () => when(() => repository.requestPermission())
          .thenAnswer((_) async => LibraryPermission.granted),
      build: () => LibraryBloc(repository),
      seed: () => const LibraryState(permission: LibraryPermission.denied),
      act: (bloc) => bloc.add(const LibraryPermissionRequested()),
      expect: () => [
        granted,
        granted.copyWith(status: LibraryStatus.loading),
        loaded,
      ],
    );

    blocTest<LibraryBloc, LibraryState>(
      'reports a permanent denial',
      setUp: () => when(() => repository.requestPermission())
          .thenAnswer((_) async => LibraryPermission.permanentlyDenied),
      build: () => LibraryBloc(repository),
      seed: () => const LibraryState(permission: LibraryPermission.denied),
      act: (bloc) => bloc.add(const LibraryPermissionRequested()),
      expect: () => [
        const LibraryState(permission: LibraryPermission.permanentlyDenied),
      ],
    );

    blocTest<LibraryBloc, LibraryState>(
      'opens Settings',
      build: () => LibraryBloc(repository),
      act: (bloc) => bloc.add(const LibrarySettingsOpened()),
      expect: () => <LibraryState>[],
      verify: (_) => verify(() => repository.openSettings()).called(1),
    );

    blocTest<LibraryBloc, LibraryState>(
      'keeps songs and reports a failed rescan',
      setUp: () => when(() => repository.loadSongs()).thenThrow(Exception('boom')),
      build: () => LibraryBloc(repository),
      seed: () => loaded,
      act: (bloc) => bloc.add(const LibraryRefreshed()),
      expect: () => [
        loaded.copyWith(status: LibraryStatus.loading),
        loaded.copyWith(
          status: LibraryStatus.failure,
          errorMessage: "Couldn't read your music. Try again.",
        ),
      ],
    );

    blocTest<LibraryBloc, LibraryState>(
      'ignores a refresh without access',
      build: () => LibraryBloc(repository),
      seed: () => const LibraryState(permission: LibraryPermission.denied),
      act: (bloc) => bloc.add(const LibraryRefreshed()),
      expect: () => <LibraryState>[],
    );

    blocTest<LibraryBloc, LibraryState>(
      'clears songs when access is revoked while away',
      setUp: () => when(() => repository.permissionStatus())
          .thenAnswer((_) async => LibraryPermission.denied),
      build: () => LibraryBloc(repository),
      seed: () => loaded,
      act: (bloc) => bloc.add(const LibraryResumed()),
      expect: () => [const LibraryState(permission: LibraryPermission.denied)],
    );

    blocTest<LibraryBloc, LibraryState>(
      'does nothing on resume when access is unchanged',
      setUp: () => when(() => repository.permissionStatus())
          .thenAnswer((_) async => LibraryPermission.granted),
      build: () => LibraryBloc(repository),
      seed: () => loaded,
      act: (bloc) => bloc.add(const LibraryResumed()),
      expect: () => <LibraryState>[],
    );
  });
}
