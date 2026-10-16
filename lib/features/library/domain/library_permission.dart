enum LibraryPermission {
  granted,

  /// Not granted yet, but the app may still ask.
  denied,

  /// The OS won't show the prompt again; only Settings can grant access.
  permanentlyDenied,
}
