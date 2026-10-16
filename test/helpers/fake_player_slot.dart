import 'dart:async';

import 'package:tuniq/core/audio/engine_state.dart';
import 'package:tuniq/core/audio/player_slot.dart';

/// In-memory player: records what was loaded and lets tests end a track.
class FakePlayerSlot implements PlayerSlot {
  final _states = StreamController<SlotState>.broadcast();
  final _positions = StreamController<Duration>.broadcast();

  final loaded = <Uri>[];

  /// Loading any of these throws, like an unsupported or deleted file.
  final failing = <Uri>{};
  bool playing = false;
  double volume = 1;
  int stops = 0;
  Duration? reportedDuration;

  @override
  Duration position = Duration.zero;

  @override
  Stream<SlotState> get states => _states.stream;

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Future<Duration?> load(Uri uri) async {
    loaded.add(uri);
    if (failing.contains(uri)) throw Exception('cannot decode $uri');
    playing = false;
    position = Duration.zero;
    _report(EngineProcessing.ready);
    return reportedDuration;
  }

  @override
  Future<void> play() async {
    playing = true;
    _report(EngineProcessing.ready);
  }

  @override
  Future<void> pause() async {
    playing = false;
    _report(EngineProcessing.ready);
  }

  @override
  Future<void> stop() async {
    stops++;
    playing = false;
    _report(EngineProcessing.idle);
  }

  @override
  Future<void> seek(Duration position) async => this.position = position;

  @override
  Future<void> setVolume(double volume) async => this.volume = volume;

  @override
  Future<void> dispose() async {
    await _states.close();
    await _positions.close();
  }

  /// The current track plays to its end.
  void finishTrack() => _report(EngineProcessing.completed);

  void emitPosition(Duration value) {
    position = value;
    _positions.add(value);
  }

  void _report(EngineProcessing processing) {
    if (!_states.isClosed) {
      _states.add(SlotState(playing: playing, processing: processing));
    }
  }
}
