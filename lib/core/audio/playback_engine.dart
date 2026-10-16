import 'package:tuniq/core/audio/engine_state.dart';
import 'package:tuniq/features/library/domain/song.dart';

/// What the UI layer needs from the audio engine. Implemented by
/// AppAudioHandler; the cubits only depend on this.
abstract interface class PlaybackEngine {
  EngineState get state;
  Stream<EngineState> get states;
  Stream<Duration> get positions;

  /// With [shuffle], plays in random order and turns shuffle on.
  Future<void> playQueue(List<Song> songs, {int startIndex = 0, bool shuffle = false});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> skipToQueueItem(int index);
  Future<void> setShuffleEnabled(bool enabled);
  Future<void> setRepeat(PlayerRepeatMode mode);
  Future<void> moveQueueItem(int from, int to);
  Future<void> removeQueueItemAt(int index);
  Future<void> playNext(Song song);
  Future<void> enqueue(Song song);
  Future<void> dispose();
}
