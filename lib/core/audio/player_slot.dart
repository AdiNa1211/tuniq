import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:tuniq/core/audio/engine_state.dart';

class SlotState {
  const SlotState({required this.playing, required this.processing});

  final bool playing;
  final EngineProcessing processing;
}

/// One audio player holding one track. Crossfade (Phase 5) adds a second
/// slot; tests use a fake.
abstract interface class PlayerSlot {
  Stream<SlotState> get states;
  Stream<Duration> get positions;
  Duration get position;

  /// Loads [uri] paused; returns its duration when the decoder knows it.
  Future<Duration?> load(Uri uri);

  /// Starts playback and returns without waiting for it to end.
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

class JustAudioSlot implements PlayerSlot {
  JustAudioSlot([AudioPlayer? player]) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<SlotState> get states => _player.playerStateStream.map(
        (s) => SlotState(playing: s.playing, processing: _processing(s.processingState)),
      );

  @override
  Stream<Duration> get positions => _player.positionStream;

  @override
  Duration get position => _player.position;

  @override
  Future<Duration?> load(Uri uri) => _player.setAudioSource(AudioSource.uri(uri));

  // just_audio's play() completes only when playback pauses or ends.
  @override
  Future<void> play() async => unawaited(_player.play());

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() => _player.dispose();

  static EngineProcessing _processing(ProcessingState state) => switch (state) {
        ProcessingState.idle => EngineProcessing.idle,
        ProcessingState.loading => EngineProcessing.loading,
        ProcessingState.buffering => EngineProcessing.buffering,
        ProcessingState.ready => EngineProcessing.ready,
        ProcessingState.completed => EngineProcessing.completed,
      };
}
