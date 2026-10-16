import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tuniq/core/audio/engine_state.dart';
import 'package:tuniq/core/audio/playback_engine.dart';
import 'package:tuniq/features/library/domain/song.dart';
import 'package:tuniq/features/player/presentation/cubit/player_state.dart';

/// UI view of the playback engine: mirrors its state and forwards commands.
/// All playback logic lives in the engine.
class PlayerCubit extends Cubit<PlayerState> {
  PlayerCubit(this._engine) : super(PlayerState.fromEngine(_engine.state)) {
    _stateSubscription = _engine.states.listen(
      (engine) => emit(PlayerState.fromEngine(engine, position: _positionFor(engine))),
    );
    _positionSubscription = _engine.positions.listen(
      (position) => emit(state.copyWith(position: position)),
    );
  }

  final PlaybackEngine _engine;
  late final StreamSubscription<EngineState> _stateSubscription;
  late final StreamSubscription<Duration> _positionSubscription;

  // A new track starts at zero; otherwise keep the last known position.
  Duration _positionFor(EngineState engine) =>
      engine.current?.song == state.currentSong ? state.position : Duration.zero;

  void playQueue(List<Song> songs, {int startIndex = 0, bool shuffle = false}) =>
      _engine.playQueue(songs, startIndex: startIndex, shuffle: shuffle);

  void togglePlay() {
    if (state.currentSong == null) return;
    state.playing ? _engine.pause() : _engine.play();
  }

  void next() => _engine.skipToNext();

  void previous() => _engine.skipToPrevious();

  void skipToIndex(int index) => _engine.skipToQueueItem(index);

  void seek(Duration position) {
    emit(state.copyWith(position: position));
    _engine.seek(position);
  }

  void toggleShuffle() => _engine.setShuffleEnabled(!state.shuffle);

  void cycleRepeat() {
    const modes = PlayerRepeatMode.values;
    _engine.setRepeat(modes[(state.repeatMode.index + 1) % modes.length]);
  }

  @override
  Future<void> close() async {
    await _stateSubscription.cancel();
    await _positionSubscription.cancel();
    return super.close();
  }
}
