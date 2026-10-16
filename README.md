# Tuniq

An offline-first music player for Android and iOS, built with Flutter, with smooth Apple Music-style crossfade between tracks.

## Status

| Phase | What it delivers | Status |
| --- | --- | --- |
| 1. Planning and spikes | MVP plan; proof that two players can crossfade; device music detection | Crossfade verified on Android with test tones; iOS library check pending |
| 2. Setup and UI shell | App structure, theme, navigation, mini and full player shells | Done |
| 3. Local library | Real device music in the library, artwork, search, cached library | In progress: device library, permissions, artwork and cache done |
| 4. Playback engine | Real audio: play, pause, seek, skip, shuffle, repeat, queue editing | Not started |
| 5. Crossfade engine | Configurable 1–12 s crossfade (default 6 s, off by default) | Not started |
| 6. Background and system | Lock screen, notification, headset and Bluetooth controls | Not started |
| 7. YouTube Music | "Find on YouTube Music" link-out (no in-app playback) | Not started |
| 8. Hardening and release | Bug fixes, performance, release builds | Not started |

## Features

### Available now

- **Three tabs** (Library, Search, Settings), each keeping its own scroll and navigation state.
- **Library of your own music**: Songs, Albums, Artists and Folders tabs (Folders on Android only), read from MediaStore on Android and the Music app on iOS. Pull down to rescan.
- **Album artwork** from MediaStore thumbnails (Android) and the Music library (iOS), cached in memory; songs without art keep a tinted placeholder.
- **Instant start**: the last scan is cached as JSON, shown immediately, and refreshed in the background with a thin progress line.
- **Permission gate** explaining why music access is needed, with Allow access or Open Settings, and a recheck when you return from Settings.
- **Mini-player** above the tab bar on every tab, with progress, play/pause and next. It appears once something plays.
- **Full-screen player** that slides up from the mini-player with the artwork growing into place (YouTube Music style); swipe down to close, or swipe the mini-player up to open. It has artwork, title, seek bar with elapsed and total time, shuffle, previous, play/pause, next and repeat (off, all, one). Artwork moves beside the controls in landscape.
- **Queue screen** showing what plays next; tap a song to jump to it.
- **Light, dark and system themes**, saved between launches.
- Playback is **simulated** in this phase: the position advances on a timer, so all controls can be tried without audio. Real audio arrives in Phase 4.

### Phase 1 spike app (still available)

- Crossfade test with two `just_audio` players and bundled test tones.
- Device library test: Kotlin MediaStore channel (Android) and Swift MPMediaQuery channel (iOS).
- Run it with `flutter run -t lib/spike/main_spike.dart`. It stays until the iOS library check passes, then it's deleted.

### Not yet built

Device music in the library, artwork, search, playlists, real audio playback, queue editing, crossfade setting, background controls.

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
│   ├── utils/duration_format.dart     # m:ss / h:mm:ss
│   └── widgets/artwork.dart           # placeholder album art
├── features/
│   ├── library/
│   │   ├── data/demo_songs.dart       # Phase 2 placeholder data
│   │   ├── domain/                    # Song, SongGroup
│   │   └── presentation/              # LibraryPage, SongTile
│   ├── player/presentation/
│   │   ├── cubit/                     # PlayerCubit, PlayerState
│   │   ├── full_player_page.dart
│   │   └── widgets/                   # MiniPlayer, SeekBar, PlayerControls
│   ├── queue/presentation/queue_page.dart
│   ├── search/presentation/search_page.dart
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
├── features/                          # cubit and domain tests
└── helpers/mocks.dart
```

## Tech stack

| Concern | Choice |
| --- | --- |
| State management | flutter_bloc 9.1.1 (Cubits), equatable 3.0.0 |
| Navigation | go_router 18.1.0 (`StatefulShellRoute.indexedStack`) |
| Dependency injection | get_it 9.3.0 |
| Settings storage | shared_preferences 2.5.6 (`SharedPreferencesAsync`) |
| Playback | just_audio 0.10.6 (two players for crossfade, from Phase 4) |
| Audio focus and interruptions | audio_session 0.2.4 |
| File import | file_picker 13.1.0 |
| Device library | Own platform channels: Kotlin MediaStore, Swift MPMediaQuery |
| Testing | flutter_test, bloc_test 10.0.0, mocktail 1.0.5 |
| Library cache | JSON file via path_provider 2.1.6 |
| Planned | audio_service, drift (playlists) |

## Key decisions

- **Crossfade is time-based in the MVP.** It starts when the current song has the fade length left. Beat-aware mixing (BPM detection, tempo matching) needs a native audio engine and is a future feature.
- **YouTube Music is link-out only.** There is no official API for in-app playback, and its terms forbid background play, audio extraction and modifying playback. The app never uses unofficial APIs.
- **Own native library channels** instead of on_audio_query, which has had no release since May 2023.
- **One PlayerCubit for both players.** The mini and full player read the same state, so they never disagree. Its public API stays the same when Phase 4 swaps the timer for the real audio engine.
- **Crossfade logic will not live in a Bloc.** It goes in a plain Dart `CrossfadeCoordinator` inside the audio engine, so it keeps working in the background and from lock-screen controls.
- **Single state classes with `copyWith`.** equatable 3 no longer compares runtime types, so sealed subclasses with the same props would compare equal.
- **Personal use first.** A store release is decided later.

## Changelog

### Phase 3 — in progress

- Library now shows the music on the device through `LibraryBloc`, `LibraryRepository` and `MethodChannelLibrarySource`; the demo songs are gone.
- Added the permission gate, empty and error states, pull to refresh, and a permission recheck on app resume.
- Native channels now return album ID (iOS), track number and date added.
- Added bloc, channel-mapping and library page tests.
- Added album artwork: native `artwork` channel method, `ArtworkRepository` (LRU, size buckets, remembers missing art) and `SongArtwork`.
- Added the JSON library cache (`LibraryCache`): shown on start while a fresh scan runs, cleared when access is revoked.
- Added artwork, cache and repository tests.

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
