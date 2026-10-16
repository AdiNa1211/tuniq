# Tuniq

An offline-first music player for Android and iOS, built with Flutter, with smooth Apple Music-style crossfade between tracks.

## Status

| Phase | What it delivers | Status |
| --- | --- | --- |
| 1. Planning and spikes | MVP plan; proof that two players can crossfade; device music detection | In progress: awaiting device test results |
| 2. Setup and UI shell | Real app structure, theme, navigation, mini and full player shells | Not started |
| 3. Local library | Library screens, artwork, search, cached library | Not started |
| 4. Playback engine | Play, pause, seek, skip, shuffle, repeat, queue | Not started |
| 5. Crossfade engine | Configurable 1–12 s crossfade (default 6 s, off by default) | Not started |
| 6. Background and system | Lock screen, notification, headset and Bluetooth controls | Not started |
| 7. YouTube Music | "Find on YouTube Music" link-out (no in-app playback) | Not started |
| 8. Hardening and release | Bug fixes, performance, release builds | Not started |

## Features

### Available now (Phase 1 spike app)

- **Crossfade test:** two `just_audio` players overlap with an equal-power volume curve. The screen flags a FAIL if the OS pauses either player and records the worst timer step.
- **Device library:** finds music already stored on the device.
  - Android: own Kotlin MediaStore channel (`READ_MEDIA_AUDIO` on Android 13+, storage permission below). Skips ringtones, alarms and recordings.
  - iOS: own Swift MPMediaQuery channel for the Music app library. Only DRM-free songs downloaded to the device can play; Apple Music subscription downloads are DRM-protected.
- **Permission handling:** request access, and an Open Settings path when access was denied for good.
- **Test tones:** two bundled 25 s tones (440 Hz and 659 Hz) for testing fades without any music files.

### Not yet built

Library screens with artwork, search, playlists, the real playback engine, background playback controls, and the settings screen.

## Getting started

Requirements: Flutter (Dart 3.13+), Xcode for iOS, a physical iPhone to test the Music library (the Simulator has none).

```bash
flutter pub get
flutter analyze
flutter run
```

`lib/main.dart` currently launches the Phase 1 spike app (`lib/spike/main_spike.dart`). Phase 2 replaces it with the real app.

## Project structure

```
lib/
├── main.dart                         # entry point (launches spikes for now)
└── spike/                            # Phase 1 throwaway code, deleted in Phase 2
    ├── main_spike.dart               # spike app with two tabs
    ├── crossfade_spike_page.dart     # two-player crossfade test
    ├── device_library_spike_page.dart# device music detection test
    └── spike_tracks.dart             # shared track list
android/app/src/main/kotlin/com/nodz/tuniq/tuniq/
├── MainActivity.kt                   # registers the MediaStore channel
└── MediaStoreChannel.kt              # Android music discovery + permission
ios/Runner/AppDelegate.swift          # registers MediaLibraryChannel (Music library)
assets/spike/                         # test tones, deleted in Phase 2
```

## Tech stack

| Concern | Choice |
| --- | --- |
| Playback | just_audio 0.10.6 (two players for crossfade) |
| Audio focus and interruptions | audio_session 0.2.4 |
| File import | file_picker 13.1.0 |
| Device library | Own platform channels: Kotlin MediaStore, Swift MPMediaQuery |
| Planned | audio_service, flutter_bloc, get_it, drift, go_router |

## Key decisions

- **Crossfade is time-based in the MVP.** It starts when the current song has the fade length left. Beat-aware mixing (BPM detection, tempo matching) needs a native audio engine and is a future feature.
- **YouTube Music is link-out only.** There is no official API for in-app playback, and its terms forbid background play, audio extraction and modifying playback. The app never uses unofficial APIs.
- **Own native library channels** instead of on_audio_query, which has had no release since May 2023.
- **Personal use first.** A store release is decided later.

## Changelog

### Phase 1 — 2026-10-16

- Added the Flutter project with the Phase 1 spike app.
- Added the dual-player crossfade spike with bundled test tones.
- Added device music detection: Kotlin MediaStore channel (Android) and Swift MPMediaQuery channel (iOS).
- Added Android audio permissions, iOS Music usage text and background audio mode.
- Pending: spike results on a physical Android phone and iPhone.
