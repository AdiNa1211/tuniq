import 'package:equatable/equatable.dart';
import 'package:tuniq/core/audio/queue_controller.dart';

enum PlayerRepeatMode { off, all, one }

enum EngineProcessing { idle, loading, buffering, ready, completed }

/// Everything about playback except the position, which changes too often
/// to share this stream (see PlaybackEngine.positions).
class EngineState extends Equatable {
  const EngineState({
    this.queue = const [],
    this.currentIndex = 0,
    this.playing = false,
    this.processing = EngineProcessing.idle,
    this.duration,
    this.shuffle = false,
    this.repeatMode = PlayerRepeatMode.off,
    this.errorMessage,
    this.errorId = 0,
  });

  /// Play order: shuffled when [shuffle] is on.
  final List<QueueEntry> queue;
  final int currentIndex;
  final bool playing;
  final EngineProcessing processing;

  /// Reported by the decoder; null until the track has loaded.
  final Duration? duration;
  final bool shuffle;
  final PlayerRepeatMode repeatMode;

  /// Last playback error. [errorId] increases with each error so the same
  /// message twice is still noticed.
  final String? errorMessage;
  final int errorId;

  QueueEntry? get current =>
      currentIndex >= 0 && currentIndex < queue.length ? queue[currentIndex] : null;

  @override
  List<Object?> get props => [
        queue,
        currentIndex,
        playing,
        processing,
        duration,
        shuffle,
        repeatMode,
        errorMessage,
        errorId,
      ];
}
