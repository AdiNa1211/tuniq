abstract final class AppRoutes {
  static const library = '/library';
  static const search = '/search';
  static const settings = '/settings';
  static const player = '/player';
  static const queue = '/queue';

  /// Album and artist pages live inside a tab ([base] is its root path).
  static String album(String base, String key) => '$base/album/${Uri.encodeComponent(key)}';

  static String artist(String base, String key) => '$base/artist/${Uri.encodeComponent(key)}';
}
