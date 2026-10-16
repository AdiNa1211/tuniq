part of 'library_bloc.dart';

enum LibraryStatus { initial, loading, success, failure }

final class LibraryState extends Equatable {
  const LibraryState({
    this.status = LibraryStatus.initial,
    this.permission,
    this.songs = const [],
    this.errorMessage,
  });

  final LibraryStatus status;

  /// Null until the first permission check finishes.
  final LibraryPermission? permission;
  final List<Song> songs;
  final String? errorMessage;

  bool get hasPermission => permission == LibraryPermission.granted;

  /// [errorMessage] is not carried over: it only belongs to a failure.
  LibraryState copyWith({
    LibraryStatus? status,
    LibraryPermission? permission,
    List<Song>? songs,
    String? errorMessage,
  }) {
    return LibraryState(
      status: status ?? this.status,
      permission: permission ?? this.permission,
      songs: songs ?? this.songs,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, permission, songs, errorMessage];
}
