import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tuniq/app/router.dart';
import 'package:tuniq/app/theme.dart';
import 'package:tuniq/core/audio/playback_engine.dart';
import 'package:tuniq/features/library/data/artwork_repository.dart';
import 'package:tuniq/features/library/data/library_repository.dart';
import 'package:tuniq/features/library/presentation/bloc/library_bloc.dart';
import 'package:tuniq/features/player/presentation/cubit/player_cubit.dart';
import 'package:tuniq/features/queue/presentation/cubit/queue_cubit.dart';
import 'package:tuniq/features/settings/data/settings_repository.dart';
import 'package:tuniq/features/settings/presentation/cubit/settings_cubit.dart';

class TuniqApp extends StatefulWidget {
  const TuniqApp({
    required this.settingsRepository,
    required this.libraryRepository,
    required this.artworkRepository,
    required this.engine,
    super.key,
  });

  final SettingsRepository settingsRepository;
  final LibraryRepository libraryRepository;
  final ArtworkRepository artworkRepository;

  /// Owned by the caller: it outlives the widget tree (background audio).
  final PlaybackEngine engine;

  @override
  State<TuniqApp> createState() => _TuniqAppState();
}

class _TuniqAppState extends State<TuniqApp> {
  // Created once so hot reload and rebuilds keep navigation state.
  late final GoRouter _router = createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Providers sit above the router so every route, including the
    // full-screen player, shares the same blocs and artwork cache.
    return RepositoryProvider.value(
      value: widget.artworkRepository,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => SettingsCubit(widget.settingsRepository)..load(),
          ),
          BlocProvider(
            create: (_) =>
                LibraryBloc(widget.libraryRepository)..add(const LibraryStarted()),
          ),
          BlocProvider(create: (_) => PlayerCubit(widget.engine)),
          BlocProvider(create: (_) => QueueCubit(widget.engine)),
        ],
        child: BlocSelector<SettingsCubit, SettingsState, ThemeMode>(
          selector: (state) => state.themeMode,
          builder: (context, themeMode) => MaterialApp.router(
            title: 'Tuniq',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            routerConfig: _router,
          ),
        ),
      ),
    );
  }
}
