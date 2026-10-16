import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tuniq/app/routes.dart';
import 'package:tuniq/app/shell/app_shell.dart';
import 'package:tuniq/features/library/presentation/album_page.dart';
import 'package:tuniq/features/library/presentation/artist_page.dart';
import 'package:tuniq/features/library/presentation/library_page.dart';
import 'package:tuniq/features/player/presentation/full_player_page.dart';
import 'package:tuniq/features/queue/presentation/queue_page.dart';
import 'package:tuniq/features/search/presentation/search_page.dart';
import 'package:tuniq/features/settings/presentation/settings_page.dart';

/// Tabs live in a stateful shell (each keeps its own stack and scroll);
/// the player and queue open over it on the root navigator.
GoRouter createRouter() {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: AppRoutes.library,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.library,
                builder: (_, _) => const LibraryPage(),
                routes: _detailRoutes(AppRoutes.library),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (_, _) => const SearchPage(),
                routes: _detailRoutes(AppRoutes.search),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (_, _) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.player,
        parentNavigatorKey: rootKey,
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const FullPlayerPage(),
          // Not opaque, so the tabs stay visible while swiping the player down.
          opaque: false,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (_, animation, _, child) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            ),
            child: child,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.queue,
        parentNavigatorKey: rootKey,
        pageBuilder: (_, state) => MaterialPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: const QueuePage(),
        ),
      ),
    ],
  );
}

/// Album and artist pages, registered under a tab so the tab bar and
/// mini-player stay visible and back returns within that tab.
List<RouteBase> _detailRoutes(String base) => [
      GoRoute(
        path: 'album/:key',
        builder: (_, state) =>
            AlbumPage(albumKey: state.pathParameters['key']!, basePath: base),
      ),
      GoRoute(
        path: 'artist/:key',
        builder: (_, state) =>
            ArtistPage(artistKey: state.pathParameters['key']!, basePath: base),
      ),
    ];
