import 'package:equatable/equatable.dart';
import 'package:tuniq/core/audio/engine_state.dart';
import 'package:tuniq/features/library/domain/song.dart';

export 'package:tuniq/core/audio/engine_state.dart' show PlayerRepeatMode;

class PlayerState extends Equatable {
  const PlayerState({
    this.queue = const [],
    this.currentIndex = 0,
    this.playing = false,
    this.position = Duration.zero,
    this.shuffle = false,
    this.repeatMode = PlayerRepeatMode.off,
    this.loading = false,
    this.trackDuration,
    this.errorMessage,
    this.errorId = 0,
  });

  factory PlayerState.fromEngine(EngineState engine, {Duration position = Duration.zero}) =>
      PlayerState(
        queue: [for (final entry in engine.queue) entry.song],
        currentIndex: engine.currentIndex,
        playing: engine.playing,
        position: position,
        shuffle: engine.shuffle,
        repeatMode: engine.repeatMode,
        loading: engine.processing == EngineProcessing.loading ||
            engine.processing == EngineProcessing.buffering,
        trackDuration: engine.duration,
        errorMessage: engine.errorMessage,
        errorId: engine.errorId,
      );

  final List<Song> queue;
  final int currentIndex;
  final bool playing;
  final Duration position;
  final bool shuffle;
  final PlayerRepeatMode repeatMode;
  final bool loading;

  /// From the decoder; more accurate than the library's tag duration.
  final Duration? trackDuration;
  final String? errorMessage;
  final int errorId;

  Song? get currentSong =>
      currentIndex >= 0 && currentIndex < queue.length ? queue[currentIndex] : null;

  Duration get duration => trackDuration ?? currentSong?.duration ?? Duration.zero;

  double get progress {
    final total = duration.inMilliseconds;
    return total == 0 ? 0.0 : (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  PlayerState copyWith({Duration? position}) => PlayerState(
        queue: queue,
        currentIndex: currentIndex,
        playing: playing,
        position: position ?? this.position,
        shuffle: shuffle,
        repeatMode: repeatMode,
        loading: loading,
        trackDuration: trackDuration,
        errorMessage: errorMessage,
        errorId: errorId,
      );

  @override
  List<Object?> get props => [
        queue,
        currentIndex,
        playing,
        position,
        shuffle,
        repeatMode,
        loading,
        trackDuration,
        errorMessage,
        errorId,
      ];
}
