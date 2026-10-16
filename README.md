# Tuniq

An offline-first music player for Android and iOS, built with Flutter, with smooth Apple Music-style crossfade between tracks.

## Status

| Phase | What it delivers | Status |
| --- | --- | --- |
| 1. Planning and spikes | MVP plan; proof that two players can crossfade; device music detection | Crossfade verified on Android with test tones; iOS library check pending |
| 2. Setup and UI shell | App structure, theme, navigation, mini and full player shells | Done |
| 3. Local library | Real device music in the library, artwork, search, cached library | Done on Android; iOS device check pending |
| 4. Playback engine | Real audio: play, pause, seek, skip, shuffle, repeat, queue editing | Done on Android |
| 5. Crossfade engine | Configurable 1–12 s crossfade (default 6 s, off by default) | Built; awaiting Android device check |
| 6. Background and system | Lock screen, notification, headset and Bluetooth controls | Not started |
| 7. YouTube Music | "Find on YouTube Music" link-out (no in-app playback) | Not started |
| 8. Hardening and release | Bug fixes, performance, release builds | Not started |

## Features

### Available now

- **Three tabs** (Library, Search, Settings), each keeping its own scroll and navigation state.
- **Library of your own music**: Songs, Albums, Artists and Folders tabs (Folders on Android only), read from MediaStore on Android and the Music app on iOS. Pull down to rescan.
- **Album artwork** from MediaStore thumbnails (Android) and the Music library (iOS), cached in memory; songs without art keep a tinted placeholder.
- **Search** across songs, albums and artists: every word must match, results update as you type.
- **Album and artist pages** with artwork, track list, total length, Play and Shuffle. Open them from Library or Search; the tab bar and mini-player stay visible.
- **iOS Files import**: the + button in Library copies songs from the Files app into Tuniq (tags and embedded artwork are read on device).
- **Instant start**: the last scan is cached as JSON, shown immediately, and refreshed in the background with a thin progress line.
- **Permission gate** explaining why music access is needed, with Allow access or Open Settings, and a recheck when you return from Settings.
- **Mini-player** above the tab bar on every tab, with progress, play/pause and next. It appears once something plays.
- **Full-screen player** that slides up from the mini-player with the artwork growing into place (YouTube Music style); swipe down to close, or swipe the mini-player up to open. It has artwork, title, seek bar with elapsed and total time, shuffle, previous, play/pause, next and repeat (off, all, one). Artwork moves beside the controls in landscape.
- **Queue screen** showing what plays next; tap a song to jump to it.
- **Light, dark and system themes**, saved between launches.
- **Real playback** through just_audio: play, pause, seek, next, previous (restarts after 3 s), shuffle, and repeat off / all / one. Unplayable songs are skipped with a message.
- **Editable queue**: drag to reorder, swipe to remove, tap to jump. Long-press any song for Play next or Add to queue.
- **Crossfade** (Settings → Playback): the end of each song blends into the next over 1–12 s (default 6 s, off by default), with an equal-power curve so loudness stays even. Only songs that end by themselves crossfade; Next, Previous and seeking cut straight away.

### Phase 1 spike app (still available)

- Crossfade test with two `just_audio` players and bundled test tones.
- Device library test: Kotlin MediaStore channel (Android) and Swift MPMediaQuery channel (iOS).
- Run it with `flutter run -t lib/spike/main_spike.dart`. It stays until the iOS library check passes, then it's deleted.

### Not yet built

Notification and lock-screen controls (and reliable playback with the app in the background), playlists, deleting imported files.

## Getting started

Requirements: Flutter 3.44+ (Dart 3.13+), Xcode for iOS, a physical iPhone to test the Music library (the Simulator has none).

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Project structure

```
lib/
├── main.dart                          # DI setup, runApp
├── app/
│   ├── app.dart                       # MaterialApp.router, providers, theme mode
│   ├── di.dart                        # get_it registrations
│   ├── router.dart                    # go_router: tab shell + player/queue routes
│   ├── routes.dart                    # route paths
│   ├── theme.dart                     # Material 3 light and dark themes
│   └── shell/app_shell.dart           # bottom navigation + mini-player
├── core/
│   ├── audio/                         # PlaybackEngine, AppAudioHandler, QueueController, PlayerSlot, crossfade
│   ├── utils/duration_format.dart     # m:ss / h:mm:ss
│   └── widgets/artwork.dart           # placeholder album art
├── features/
│   ├── library/
│   │   ├── data/                      # channel source, imports, cache, artwork, repository
│   │   ├── domain/                    # Song, SongGroup, keys, search, permission
│   │   └── presentation/              # LibraryBloc, Library/Album/Artist pages, widgets
│   ├── player/presentation/
│   │   ├── cubit/                     # PlayerCubit, PlayerState
│   │   ├── full_player_page.dart
│   │   └── widgets/                   # MiniPlayer, SeekBar, PlayerControls
│   ├── queue/presentation/            # QueueCubit, QueuePage
│   ├── search/presentation/           # SearchCubit, SearchPage
│   └── settings/
│       ├── data/settings_repository.dart   # shared_preferences
│       └── presentation/                   # SettingsCubit, SettingsPage
└── spike/                             # Phase 1 spike app (temporary)
android/app/src/main/kotlin/com/nodz/tuniq/tuniq/
├── MainActivity.kt                    # registers the MediaStore channel
└── MediaStoreChannel.kt               # Android music discovery + permission
ios/Runner/AppDelegate.swift           # MediaLibraryChannel (Music library)
test/
├── app/app_shell_test.dart            # navigation, mini/full player, theme
├── core/audio/                        # engine, queue and crossfade tests
├── features/                          # cubit, page and domain tests
└── helpers/                           # mocks, fixtures, fake player slot
```

## Tech stack

| Concern | Choice |
| --- | --- |
| State management | flutter_bloc 9.1.1 (Cubits), equatable 3.0.0 |
| Navigation | go_router 18.1.0 (`StatefulShellRoute.indexedStack`) |
| Dependency injection | get_it 9.3.0 |
| Settings storage | shared_preferences 2.5.6 (`SharedPreferencesAsync`) |
| Playback | just_audio 0.10.6 (two players, alternating for crossfade) |
| Audio handler | audio_service 0.18.19 (`BaseAudioHandler`; system controls wired in Phase 6) |
| Audio focus and interruptions | audio_session 0.2.4 |
| File import | file_picker 13.1.0 |
| Device library | Own platform channels: Kotlin MediaStore, Swift MPMediaQuery |
| Testing | flutter_test, bloc_test 10.0.0, mocktail 1.0.5 |
| Library cache | JSON file via path_provider 2.1.6 |
| Imported file tags and artwork | audio_metadata_reader 1.8.1 |
| Planned | drift (playlists) |

## Key decisions

- **Crossfade is time-based in the MVP.** It starts when the current song has the fade length left. Beat-aware mixing (BPM detection, tempo matching) needs a native audio engine and is a future feature.
- **YouTube Music is link-out only.** There is no official API for in-app playback, and its terms forbid background play, audio extraction and modifying playback. The app never uses unofficial APIs.
- **Own native library channels** instead of on_audio_query, which has had no release since May 2023.
- **The audio engine is the single source of truth.** `AppAudioHandler` owns the queue and the player; `PlayerCubit` and `QueueCubit` only mirror it and forward commands, so the mini player, full player, queue and (later) the notification never disagree.
- **Commands run one at a time.** The engine serialises every command, so ten fast taps on Next end on the right song instead of racing each other.
- **Crossfade lives in the audio engine, not a Bloc.** `AppAudioHandler` alternates two player slots: it preloads the next song silently 5 s before the fade, then ramps both volumes from the outgoing song's own position, so the fade keeps working in the background and from lock-screen controls (Phase 6).
- **Only natural track ends crossfade.** Skips, seeks and jumps cut immediately, as in Apple Music. No crossfade with repeat one, after the last song, or while paused; songs shorter than twice the fade length fade over half their length.
- **Single state classes with `copyWith`.** equatable 3 no longer compares runtime types, so sealed subclasses with the same props would compare equal.
- **Personal use first.** A store release is decided later.

## Changelog

### Phase 5 — 2026-10-16

- Added crossfade to `AppAudioHandler`: a second player slot, silent preload of the next song, an equal-power volume ramp, and the songs swapping slots each fade.
- Crossfade settings (on/off and 1–12 s length) in Settings → Playback, saved between launches and applied to the engine straight away.
- Pause, play, skip, seek and queue edits handle a fade in progress; a next song that can't be loaded falls back to a normal track change.
- Added crossfade engine, curve, settings cubit and settings page tests.

### Phase 4 — 2026-10-16

- Added the playback engine in `core/audio`: `PlaybackEngine` interface, `AppAudioHandler` (extends audio_service's `BaseAudioHandler`), `QueueController` (play order, shuffle, repeat, edits) and `PlayerSlot` over just_audio.
- `PlayerCubit` now mirrors the engine instead of simulating playback; the decoder's duration replaces tag durations.
- Added `QueueCubit` and an editable queue: reorder, swipe to remove, tap to jump; Play next and Add to queue from a song's long-press menu.
- Unplayable songs are skipped (up to three in a row) with a message.
- The audio session is configured for music (pause for calls, duck for navigation).
- Added engine, queue controller, player cubit and queue tests using a fake player slot.

### Phase 3 — 2026-10-16

- Library now shows the music on the device through `LibraryBloc`, `LibraryRepository` and `MethodChannelLibrarySource`; the demo songs are gone.
- Added the permission gate, empty and error states, pull to refresh, and a permission recheck on app resume.
- Native channels now return album ID (iOS), track number and date added.
- Added bloc, channel-mapping and library page tests.
- Added album artwork: native `artwork` channel method, `ArtworkRepository` (LRU, size buckets, remembers missing art) and `SongArtwork`.
- Added the JSON library cache (`LibraryCache`): shown on start while a fresh scan runs, cleared when access is revoked.
- Added artwork, cache and repository tests.
- Added search (`SearchCubit` + `searchLibrary`, debounced) and the Search page.
- Added album and artist pages with Play and Shuffle, routed inside the Library and Search tabs.
- Albums are now grouped by album ID, so different albums with the same name stay apart.
- Added iOS Files import (`ImportedSongsSource`): copies into Documents/Imported, reads tags off the UI isolate, merged into the library scan.
- Added search, detail page, import, grouping and shuffle tests.
- Pending: iOS device check of the Music library and Files import; the Phase 1 spike stays until then.

### Phase 2 — 2026-10-16

- Replaced the template app with the real app shell: go_router tabs, Material 3 light and dark themes, get_it setup.
- Added the Library page (Songs, Albums, Artists, Folders on Android) over demo data.
- Added the mini-player, full-screen player, seek bar, transport controls and queue screen, driven by a simulated `PlayerCubit`.
- Added the Settings page with a saved theme choice (`SettingsCubit` + `SettingsRepository`).
- Added a YouTube Music-style open and close: slide-up transition, shared artwork Hero, swipe down to dismiss, swipe up on the mini-player to open.
- Labelled demo songs as silent in the library and full player, so simulated playback isn't mistaken for a bug.
- Added widget tests for navigation, mini/full player and theme saving, plus cubit and domain tests; removed the template counter test.
- Added lint rules: package imports, directive ordering, final locals, single quotes.

### Phase 1 — 2026-10-16

- Added the Flutter project with the Phase 1 spike app.
- Added the dual-player crossfade spike with bundled test tones.
- Added device music detection: Kotlin MediaStore channel (Android) and Swift MPMediaQuery channel (iOS).
- Added Android audio permissions, iOS Music usage text and background audio mode.
- Verified: crossfade with the test tones on Android. Pending: iOS Music library check.
