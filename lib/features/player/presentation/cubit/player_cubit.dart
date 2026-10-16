import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tuniq/features/library/domain/song.dart';
import 'package:tuniq/features/player/presentation/cubit/player_state.dart';

/// Simulated playback for the Phase 2 UI shell. Phase 4 keeps this public
/// API but drives it from the AudioHandler instead of a timer.
class PlayerCubit extends Cubit<PlayerState> {
  PlayerCubit() : super(const PlayerState());

  static const _tick = Duration(seconds: 1);
  // Matches common players: "previous" restarts the song after 3 s.
  static const _restartThreshold = Duration(seconds: 3);

  Timer? _timer;

  void playQueue(List<Song> songs, {int startIndex = 0}) {
    if (songs.isEmpty) return;
    emit(
      state.copyWith(
        queue: List.unmodifiable(songs),
        currentIndex: startIndex.clamp(0, songs.length - 1),
        position: Duration.zero,
        playing: true,
      ),
    );
    _syncTimer();
  }

  void togglePlay() {
    if (state.currentSong == null) return;
    emit(state.copyWith(playing: !state.playing));
    _syncTimer();
  }

  void next() {
    if (state.queue.isEmpty) return;
    final isLast = state.currentIndex == state.queue.length - 1;
    if (isLast && state.repeatMode == PlayerRepeatMode.off) {
      emit(state.copyWith(playing: false, position: Duration.zero));
      _syncTimer();
      return;
    }
    _jumpTo(isLast ? 0 : state.currentIndex + 1);
  }

  void previous() {
    if (state.queue.isEmpty) return;
    final atFirst = state.currentIndex == 0;
    if (state.position > _restartThreshold ||
        (atFirst && state.repeatMode != PlayerRepeatMode.all)) {
      seek(Duration.zero);
      return;
    }
    _jumpTo(atFirst ? state.queue.length - 1 : state.currentIndex - 1);
  }

  void skipToIndex(int index) {
    if (index < 0 || index >= state.queue.length) return;
    _jumpTo(index);
  }

  void seek(Duration position) {
    if (state.currentSong == null) return;
    final clamped = position.isNegative
        ? Duration.zero
        : (position > state.duration ? state.duration : position);
    emit(state.copyWith(position: clamped));
  }

  void toggleShuffle() => emit(state.copyWith(shuffle: !state.shuffle));

  void cycleRepeat() {
    const modes = PlayerRepeatMode.values;
    emit(state.copyWith(repeatMode: modes[(state.repeatMode.index + 1) % modes.length]));
  }

  @visibleForTesting
  void advanceBy(Duration elapsed) {
    final song = state.currentSong;
    if (song == null || !state.playing) return;
    final position = state.position + elapsed;
    if (position < song.duration) {
      emit(state.copyWith(position: position));
    } else if (state.repeatMode == PlayerRepeatMode.one) {
      emit(state.copyWith(position: Duration.zero));
    } else {
      next();
    }
  }

  void _jumpTo(int index) {
    emit(state.copyWith(currentIndex: index, position: Duration.zero));
  }

  void _syncTimer() {
    if (state.playing && state.currentSong != null) {
      _timer ??= Timer.periodic(_tick, (_) => advanceBy(_tick));
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
