import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tuniq/features/library/data/library_repository.dart';
import 'package:tuniq/features/library/domain/library_permission.dart';
import 'package:tuniq/features/library/domain/song.dart';

part 'library_event.dart';
part 'library_state.dart';

class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  LibraryBloc(this._repository) : super(const LibraryState()) {
    on<LibraryStarted>(_onStarted);
    on<LibraryPermissionRequested>(_onPermissionRequested);
    on<LibrarySettingsOpened>((_, _) => _repository.openSettings());
    on<LibraryRefreshed>(_onRefreshed);
    on<LibraryResumed>(_onResumed);
  }

  final LibraryRepository _repository;

  Future<void> _onStarted(LibraryStarted event, Emitter<LibraryState> emit) async {
    await _applyPermission(await _repository.permissionStatus(), emit);
  }

  Future<void> _onPermissionRequested(
    LibraryPermissionRequested event,
    Emitter<LibraryState> emit,
  ) async {
    await _applyPermission(await _repository.requestPermission(), emit);
  }

  // Back from Settings (or the user revoked access): react only to a change.
  Future<void> _onResumed(LibraryResumed event, Emitter<LibraryState> emit) async {
    final permission = await _repository.permissionStatus();
    if (permission == state.permission) return;
    await _applyPermission(permission, emit);
  }

  Future<void> _onRefreshed(LibraryRefreshed event, Emitter<LibraryState> emit) async {
    if (!state.hasPermission || state.status == LibraryStatus.loading) return;
    await _load(emit);
  }

  Future<void> _applyPermission(
    LibraryPermission permission,
    Emitter<LibraryState> emit,
  ) async {
    if (permission != LibraryPermission.granted) {
      // Dropping songs (and the cache) also covers access revoked while running.
      emit(LibraryState(permission: permission));
      await _repository.clearCache();
      return;
    }
    emit(state.copyWith(permission: permission));
    if (state.songs.isEmpty) {
      final cached = await _repository.cachedSongs();
      if (cached != null && cached.isNotEmpty) emit(state.copyWith(songs: cached));
    }
    await _load(emit);
  }

  Future<void> _load(Emitter<LibraryState> emit) async {
    emit(state.copyWith(status: LibraryStatus.loading));
    try {
      final songs = await _repository.loadSongs();
      emit(state.copyWith(status: LibraryStatus.success, songs: songs));
    } catch (_) {
      emit(
        state.copyWith(
          status: LibraryStatus.failure,
          errorMessage: "Couldn't read your music. Try again.",
        ),
      );
    }
  }
}
