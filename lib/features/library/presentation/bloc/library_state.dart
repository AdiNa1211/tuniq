part of 'library_bloc.dart';

enum LibraryStatus { initial, loading, success, failure }

final class LibraryState extends Equatable {
  const LibraryState({
    this.status = LibraryStatus.initial,
    this.permission,
    this.songs = const [],
    this.errorMessage,
    this.canImport = false,
  });

  final LibraryStatus status;

  /// Null until the first permission check finishes.
  final LibraryPermission? permission;
  final List<Song> songs;
  final String? errorMessage;

  /// Whether Files import is offered (iOS only).
  final bool canImport;

  bool get hasPermission => permission == LibraryPermission.granted;

  /// [errorMessage] is not carried over: it only belongs to a failure.
  LibraryState copyWith({
    LibraryStatus? status,
    LibraryPermission? permission,
    List<Song>? songs,
    String? errorMessage,
    bool? canImport,
  }) {
    return LibraryState(
      status: status ?? this.status,
      permission: permission ?? this.permission,
      songs: songs ?? this.songs,
      errorMessage: errorMessage,
      canImport: canImport ?? this.canImport,
    );
  }

  @override
  List<Object?> get props => [status, permission, songs, errorMessage, canImport];
}
