part of 'library_bloc.dart';

sealed class LibraryEvent {
  const LibraryEvent();
}

/// App start: check permission and load if granted.
final class LibraryStarted extends LibraryEvent {
  const LibraryStarted();
}

final class LibraryPermissionRequested extends LibraryEvent {
  const LibraryPermissionRequested();
}

final class LibrarySettingsOpened extends LibraryEvent {
  const LibrarySettingsOpened();
}

/// Pull to refresh or "Scan again".
final class LibraryRefreshed extends LibraryEvent {
  const LibraryRefreshed();
}

/// App returned to the foreground; permission may have changed in Settings.
final class LibraryResumed extends LibraryEvent {
  const LibraryResumed();
}
