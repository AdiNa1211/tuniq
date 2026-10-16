import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:tuniq/core/audio/engine_state.dart';
import 'package:tuniq/core/audio/playback_engine.dart';
import 'package:tuniq/core/audio/player_slot.dart';
import 'package:tuniq/core/audio/queue_controller.dart';
import 'package:tuniq/features/library/domain/song.dart';

/// The single source of truth for playback. Extends audio_service's
/// BaseAudioHandler so Phase 6 can hand it to AudioService.init for
/// notification and lock-screen controls.
class AppAudioHandler extends BaseAudioHandler implements PlaybackEngine {
  AppAudioHandler({required PlayerSlot slot, QueueController? queueController})
      : _slot = slot,
        _queue = queueController ?? QueueController() {
    _slotSubscription = _slot.states.listen(_onSlotState);
  }

  // Matches common players: "previous" restarts the song after 3 s.
  static const _restartThreshold = Duration(seconds: 3);
  static const _maxConsecutiveFailures = 3;

  final PlayerSlot _slot;
  final QueueController _queue;
  final _states = StreamController<EngineState>.broadcast();
  late final StreamSubscription<SlotState> _slotSubscription;

  EngineState _state = const EngineState();
  Future<void> _tail = Future.value();

  // Bumped on every load so a late "completed" from the old track is ignored.
  int _generation = 0;
  int _failures = 0;
  int _errorId = 0;
  String? _error;
  bool _playing = false;
  Duration? _duration;
  EngineProcessing _processing = EngineProcessing.idle;

  @override
  EngineState get state => _state;

  @override
  Stream<EngineState> get states => _states.stream;

  @override
  Stream<Duration> get positions => _slot.positions;

  /// Runs commands one at a time, so rapid taps can't interleave loads.
  Future<void> _serial(Future<void> Function() command) {
    final result = _tail.then((_) => command());
    _tail = result.catchError((Object _) {});
    return result;
  }

  @override
  Future<void> playQueue(List<Song> songs, {int startIndex = 0, bool shuffle = false}) =>
      _serial(() async {
        if (songs.isEmpty) return;
        _queue.replace(songs, startIndex: startIndex, shufflePlay: shuffle);
        _failures = 0;
        await _loadCurrent(autoplay: true);
      });

  @override
  Future<void> play() => _serial(() async {
        if (_queue.current == null) return;
        _playing = true;
        _emit();
        await _slot.play();
      });

  @override
  Future<void> pause() => _serial(() async {
        _playing = false;
        _emit();
        await _slot.pause();
      });

  @override
  Future<void> stop() => _serial(() async {
        _playing = false;
        await _slot.stop();
        _processing = EngineProcessing.idle;
        _emit();
      });

  @override
  Future<void> seek(Duration position) => _serial(() => _slot.seek(position));

  @override
  Future<void> skipToNext() => _serial(() => _advance(userInitiated: true));

  @override
  Future<void> skipToPrevious() => _serial(() async {
        if (_queue.current == null) return;
        final previous = _queue.previousIndex();
        if (_slot.position > _restartThreshold || previous == null) {
          await _slot.seek(Duration.zero);
          return;
        }
        _queue.moveTo(previous);
        await _loadCurrent(autoplay: _playing);
      });

  @override
  Future<void> skipToQueueItem(int index) => _serial(() async {
        if (index < 0 || index >= _queue.length) return;
        _queue.moveTo(index);
        _failures = 0;
        await _loadCurrent(autoplay: true);
      });

  @override
  Future<void> setShuffleEnabled(bool enabled) => _serial(() async {
        _queue.setShuffle(enabled);
        _emit();
      });

  @override
  Future<void> setRepeat(PlayerRepeatMode mode) => _serial(() async {
        _queue.repeat = mode;
        _emit();
      });

  @override
  Future<void> moveQueueItem(int from, int to) => _serial(() async {
        _queue.move(from, to);
        _emit();
      });

  @override
  Future<void> removeQueueItemAt(int index) => _serial(() async {
        if (_queue.removeAt(index)) _emit();
      });

  @override
  Future<void> playNext(Song song) => _serial(() async {
        final wasEmpty = _queue.isEmpty;
        _queue.insertNext(song);
        if (wasEmpty) {
          await _loadCurrent(autoplay: true);
        } else {
          _emit();
        }
      });

  @override
  Future<void> enqueue(Song song) => _serial(() async {
        final wasEmpty = _queue.isEmpty;
        _queue.enqueue(song);
        if (wasEmpty) {
          await _loadCurrent(autoplay: true);
        } else {
          _emit();
        }
      });

  // audio_service entry points (notification, lock screen, headset) map
  // onto the same commands.
  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) =>
      setShuffleEnabled(shuffleMode != AudioServiceShuffleMode.none);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) => setRepeat(
        switch (repeatMode) {
          AudioServiceRepeatMode.none => PlayerRepeatMode.off,
          AudioServiceRepeatMode.one => PlayerRepeatMode.one,
          AudioServiceRepeatMode.all || AudioServiceRepeatMode.group => PlayerRepeatMode.all,
        },
      );

  @override
  Future<void> dispose() async {
    await _slotSubscription.cancel();
    await _states.close();
    await _slot.dispose();
  }

  void _onSlotState(SlotState slot) {
    _processing = slot.processing;
    if (slot.processing == EngineProcessing.completed) {
      final generation = _generation;
      _serial(() async {
        if (generation == _generation) await _advance(userInitiated: false);
      });
    }
    _emit();
  }

  Future<void> _advance({required bool userInitiated}) async {
    if (_queue.current == null) return;
    final next = _queue.nextIndex(userInitiated: userInitiated);
    if (next == null) {
      // End of the queue: stop on the last song, ready to play again.
      _playing = false;
      await _slot.pause();
      await _slot.seek(Duration.zero);
      _emit();
      return;
    }
    _queue.moveTo(next);
    // A natural track end keeps playing; a skip keeps the play/pause state.
    await _loadCurrent(autoplay: userInitiated ? _playing : true);
  }

  Future<void> _loadCurrent({required bool autoplay}) async {
    final entry = _queue.current;
    if (entry == null) return;
    final generation = ++_generation;
    _duration = null;
    _processing = EngineProcessing.loading;
    _playing = autoplay;
    _emit();

    try {
      final duration = await _slot.load(entry.song.uri);
      if (generation != _generation) return;
      _duration = duration;
    } catch (_) {
      if (generation != _generation) return;
      await _onLoadFailed(entry, autoplay: autoplay);
      return;
    }
    _failures = 0;
    if (autoplay) await _slot.play();
    _emit();
  }

  /// Skips past unplayable songs, giving up after a few in a row.
  Future<void> _onLoadFailed(QueueEntry entry, {required bool autoplay}) async {
    _failures++;
    _error = 'Can\'t play "${entry.song.title}"';
    _errorId++;
    final next = _queue.nextIndex(userInitiated: true);
    if (_failures < _maxConsecutiveFailures && next != null && next != _queue.currentIndex) {
      _queue.moveTo(next);
      await _loadCurrent(autoplay: autoplay);
      return;
    }
    _playing = false;
    _processing = EngineProcessing.idle;
    _emit();
  }

  void _emit() {
    final current = _queue.current;
    _state = EngineState(
      queue: _queue.entries,
      currentIndex: _queue.currentIndex,
      playing: _playing,
      processing: _processing,
      duration: _duration,
      shuffle: _queue.shuffle,
      repeatMode: _queue.repeat,
      errorMessage: _error,
      errorId: _errorId,
    );
    if (!_states.isClosed) _states.add(_state);

    // audio_service streams for system media controls (wired up in Phase 6).
    queue.add([for (final entry in _queue.entries) _mediaItem(entry.song)]);
    mediaItem.add(current == null ? null : _mediaItem(current.song, duration: _duration));
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (_playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {MediaAction.seek},
        processingState: _audioServiceProcessing(_processing),
        playing: _playing,
        updatePosition: _slot.position,
        queueIndex: current == null ? null : _queue.currentIndex,
        shuffleMode:
            _queue.shuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
        repeatMode: switch (_queue.repeat) {
          PlayerRepeatMode.off => AudioServiceRepeatMode.none,
          PlayerRepeatMode.all => AudioServiceRepeatMode.all,
          PlayerRepeatMode.one => AudioServiceRepeatMode.one,
        },
      ),
    );
  }

  static MediaItem _mediaItem(Song song, {Duration? duration}) => MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist.isEmpty ? null : song.artist,
        album: song.album.isEmpty ? null : song.album,
        duration: duration ?? song.duration,
      );

  static AudioProcessingState _audioServiceProcessing(EngineProcessing processing) =>
      switch (processing) {
        EngineProcessing.idle => AudioProcessingState.idle,
        EngineProcessing.loading => AudioProcessingState.loading,
        EngineProcessing.buffering => AudioProcessingState.buffering,
        EngineProcessing.ready => AudioProcessingState.ready,
        EngineProcessing.completed => AudioProcessingState.completed,
      };
}
