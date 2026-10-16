import 'package:equatable/equatable.dart';
import 'package:tuniq/features/library/domain/song.dart';

enum PlayerRepeatMode { off, all, one }

class PlayerState extends Equatable {
  const PlayerState({
    this.queue = const [],
    this.currentIndex = 0,
    this.playing = false,
    this.position = Duration.zero,
    this.shuffle = false,
    this.repeatMode = PlayerRepeatMode.off,
  });

  final List<Song> queue;
  final int currentIndex;
  final bool playing;
  final Duration position;
  final bool shuffle;
  final PlayerRepeatMode repeatMode;

  Song? get currentSong =>
      currentIndex >= 0 && currentIndex < queue.length ? queue[currentIndex] : null;

  Duration get duration => currentSong?.duration ?? Duration.zero;

  double get progress {
    final total = duration.inMilliseconds;
    return total == 0 ? 0.0 : (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  PlayerState copyWith({
    List<Song>? queue,
    int? currentIndex,
    bool? playing,
    Duration? position,
    bool? shuffle,
    PlayerRepeatMode? repeatMode,
  }) {
    return PlayerState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      playing: playing ?? this.playing,
      position: position ?? this.position,
      shuffle: shuffle ?? this.shuffle,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }

  @override
  List<Object?> get props =>
      [queue, currentIndex, playing, position, shuffle, repeatMode];
}
