import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:tuniq/core/audio/crossfade.dart';
import 'package:tuniq/core/audio/engine_state.dart';
import 'package:tuniq/core/audio/interruptions.dart';
import 'package:tuniq/core/audio/playback_engine.dart';
import 'package:tuniq/core/audio/player_slot.dart';
import 'package:tuniq/core/audio/queue_controller.dart';
import 'package:tuniq/features/library/domain/song.dart';

/// The single source of truth for playback. Registered with
/// AudioService.init, so the notification, lock screen and headset buttons
/// drive the same commands as the UI.
///
/// With a [fadeSlot], the next song is preloaded on the idle slot and faded
/// in as the current one ends. Only natural track ends crossfade; skips cut.
class AppAudioHandler extends BaseAudioHandler implements PlaybackEngine {
  AppAudioHandler({
    required PlayerSlot slot,
    PlayerSlot? fadeSlot,
    QueueController? queueController,
    InterruptionSource? interruptions,
  })  : _slots = [slot, if (fadeSlot != null) fadeSlot],
        _queue = queueController ?? QueueController() {
    for (final s in _slots) {
      _subscriptions
        ..add(s.states.listen((state) => _onSlotState(s, state)))
        ..add(s.positions.listen((position) => _onPosition(s, position)));
    }
    if (interruptions != null) {
      _subscriptions.add(interruptions.events.listen(_onInterruption));
    }
  }

  // Matches common players: "previous" restarts the song after 3 s.
  static const _restartThreshold = Duration(seconds: 3);
  static const _maxConsecutiveFailures = 3;
  static const _preloadLead = Duration(seconds: 5);

  final List<PlayerSlot> _slots;
  final QueueController _queue;
  final _states = StreamController<EngineState>.broadcast();
  final _positions = StreamController<Duration>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];

  EngineState _state = const EngineState();
  Future<void> _tail = Future.value();

  // Bumped on every track change so late events from the old track are ignored.
  int _generation = 0;
  int _failures = 0;
  int _errorId = 0;
  String? _error;
  bool _playing = false;
  Duration? _duration;
  EngineProcessing _processing = EngineProcessing.idle;

  int _activeIndex = 0;
  CrossfadeSettings _crossfade = const CrossfadeSettings();
  _Preloaded? _preloaded;
  _Fade? _fade;
  // Generation for which a preload / fade was already scheduled or ruled out.
  int? _preloadGeneration;
  int? _fadeGeneration;
  bool _resumeAfterInterruption = false;

  PlayerSlot get _active => _slots[_activeIndex];
  PlayerSlot? get _spare => _slots.length > 1 ? _slots[1 - _activeIndex] : null;

  @override
  EngineState get state => _state;

  @override
  Stream<EngineState> get states => _states.stream;

  /// Position of the song shown as current, whichever slot plays it.
  @override
  Stream<Duration> get positions => _positions.stream;

  /// Runs commands one at a time, so rapid taps can't interleave loads.
  Future<void> _serial(Future<void> Function() command) {
    final result = _tail.then((_) => command());
    _tail = result.catchError((Object _) {});
    return result;
  }

  @override
  void setCrossfade(CrossfadeSettings settings) => _crossfade = settings;

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
        _resumeAfterInterruption = false;
        await _resume();
      });

  @override
  Future<void> pause() => _serial(() async {
        _resumeAfterInterruption = false;
        await _pause();
      });

  Future<void> _resume() async {
    if (_queue.current == null) return;
    _playing = true;
    _emit();
    await _active.play();
    await _fade?.outgoing.play();
  }

  Future<void> _pause() async {
    _playing = false;
    _emit();
    await _active.pause();
    await _fade?.outgoing.pause();
  }

  void _onInterruption(AudioInterruption interruption) => _serial(() async {
        switch (interruption) {
          case AudioInterruption.pause:
            if (!_playing) return;
            await _pause();
            _resumeAfterInterruption = true;
          case AudioInterruption.resume:
            if (!_resumeAfterInterruption) return;
            _resumeAfterInterruption = false;
            await _resume();
          case AudioInterruption.ended:
            _resumeAfterInterruption = false;
          case AudioInterruption.becameNoisy:
            _resumeAfterInterruption = false;
            if (_playing) await _pause();
        }
      });

  @override
  Future<void> stop() => _serial(() async {
        _playing = false;
        _resumeAfterInterruption = false;
        await _endFade();
        await _active.stop();
        _processing = EngineProcessing.idle;
        _emit();
      });

  @override
  Future<void> seek(Duration position) => _serial(() async {
        await _endFade();
        await _active.seek(position);
        _emit(); // lets the notification's seek bar catch up
      });

  @override
  Future<void> skipToNext() => _serial(() => _advance(userInitiated: true));

  @override
  Future<void> skipToPrevious() => _serial(() async {
        if (_queue.current == null) return;
        final previous = _queue.previousIndex();
        if (_active.position > _restartThreshold || previous == null) {
          await _endFade();
          await _active.seek(Duration.zero);
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

  // Swiping the app away from recents while paused ends the session.
  @override
  Future<void> onTaskRemoved() async {
    if (!_playing) await stop();
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _states.close();
    await _positions.close();
    for (final slot in _slots) {
      await slot.dispose();
    }
  }

  void _onSlotState(PlayerSlot slot, SlotState state) {
    final fade = _fade;
    if (slot != _active) {
      if (fade != null && fade.outgoing == slot && state.processing == EngineProcessing.completed) {
        _serial(() => _endFade(only: fade));
      }
      return;
    }
    _processing = state.processing;
    if (state.processing == EngineProcessing.completed) {
      final generation = _generation;
      _serial(() async {
        if (generation == _generation) {
          await _advance(userInitiated: false);
        } else if (_fade?.outgoing == slot) {
          // Ended before its last position tick; a fade queued just before
          // this already took over, so let the new song play at full volume.
          await _endFade();
        }
      });
    }
    _emit();
  }

  void _onPosition(PlayerSlot slot, Duration position) {
    if (slot == _active) {
      if (!_positions.isClosed) _positions.add(position);
      _scheduleCrossfade(position);
      return;
    }
    final fade = _fade;
    if (fade == null || fade.outgoing != slot) return;
    final remaining = fade.endsAt - position;
    final progress = 1 - remaining.inMilliseconds / fade.length.inMilliseconds;
    final (outgoing, incoming) = crossfadeVolumes(progress);
    unawaited(fade.outgoing.setVolume(outgoing));
    unawaited(fade.incoming.setVolume(incoming));
    if (progress >= 1) _serial(() => _endFade(only: fade));
  }

  /// Preloads the next song shortly before the fade, then starts the fade.
  void _scheduleCrossfade(Duration position) {
    final duration = _duration ?? _queue.current?.song.duration;
    if (_spare == null || !_crossfade.enabled || !_playing || _fade != null) return;
    if (duration == null || duration <= Duration.zero) return;
    final length = _fadeLength(duration);
    if (length < const Duration(seconds: 1)) return;
    final remaining = duration - position;
    final generation = _generation;
    if (remaining <= length + _preloadLead && _preloadGeneration != generation) {
      _preloadGeneration = generation;
      _serial(() => _preload(generation));
    }
    if (remaining <= length && _fadeGeneration != generation) {
      _fadeGeneration = generation;
      _serial(() => _startFade(generation, length: length, endsAt: duration));
    }
  }

  // Very short songs fade over half their length at most.
  Duration _fadeLength(Duration duration) {
    final half = duration ~/ 2;
    return _crossfade.duration < half ? _crossfade.duration : half;
  }

  /// The entry a natural track end would move to, if it can fade in.
  (int, QueueEntry)? _fadeTarget() {
    final next = _queue.nextIndex(userInitiated: false);
    if (next == null || next == _queue.currentIndex) return null;
    return (next, _queue.entries[next]);
  }

  Future<void> _preload(int generation) async {
    final target = _fadeTarget();
    if (generation != _generation || target == null) return;
    await _loadSpare(target.$2);
  }

  Future<bool> _loadSpare(QueueEntry entry) async {
    final spare = _spare!;
    if (_preloaded?.entryId == entry.id) return true;
    _preloaded = null;
    try {
      await spare.setVolume(0);
      final duration = await spare.load(entry.song.uri);
      _preloaded = _Preloaded(entry.id, duration);
      return true;
    } catch (_) {
      // Left to the normal track change, which reports and skips it.
      return false;
    }
  }

  Future<void> _startFade(
    int generation, {
    required Duration length,
    required Duration endsAt,
  }) async {
    if (generation != _generation || !_playing || !_crossfade.enabled) return;
    final target = _fadeTarget();
    if (target == null || !await _loadSpare(target.$2)) return;
    final (index, entry) = target;
    final preloaded = _preloaded!;
    _preloaded = null;

    final outgoing = _active;
    final incoming = _spare!;
    _fade = _Fade(outgoing: outgoing, incoming: incoming, length: length, endsAt: endsAt);
    _activeIndex = 1 - _activeIndex;
    _queue.moveTo(index);
    _generation++;
    _failures = 0;
    _duration = preloaded.duration ?? entry.song.duration;
    _processing = EngineProcessing.ready;
    await incoming.play();
    _emit();
  }

  /// Stops the outgoing song and brings the current one to full volume.
  /// With [only], does nothing unless that fade is still the running one.
  Future<void> _endFade({_Fade? only}) async {
    final fade = _fade;
    if (fade == null || (only != null && only != fade)) return;
    _fade = null;
    await fade.outgoing.stop();
    await fade.incoming.setVolume(1);
  }

  Future<void> _advance({required bool userInitiated}) async {
    if (_queue.current == null) return;
    final next = _queue.nextIndex(userInitiated: userInitiated);
    if (next == null) {
      // End of the queue: stop on the last song, ready to play again.
      _playing = false;
      await _endFade();
      await _active.pause();
      await _active.seek(Duration.zero);
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
    await _endFade();
    final generation = ++_generation;
    _duration = null;
    _processing = EngineProcessing.loading;
    _playing = autoplay;
    _emit();

    try {
      await _active.setVolume(1);
      final duration = await _active.load(entry.song.uri);
      if (generation != _generation) return;
      _duration = duration;
    } catch (_) {
      if (generation != _generation) return;
      await _onLoadFailed(entry, autoplay: autoplay);
      return;
    }
    _failures = 0;
    if (autoplay) await _active.play();
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

    // audio_service streams: notification, lock screen, headset buttons.
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
        updatePosition: _active.position,
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

  static MediaItem _mediaItem(Song song, {Duration? duration}) {
    // MediaStore songs: Android 10+ reads the embedded art via loadThumbnail.
    final androidArt = song.uri.scheme == 'content';
    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist.isEmpty ? null : song.artist,
      album: song.album.isEmpty ? null : song.album,
      duration: duration ?? song.duration,
      artUri: androidArt ? song.uri : null,
      extras: androidArt ? {'loadThumbnailUri': song.uri.toString()} : null,
    );
  }

  static AudioProcessingState _audioServiceProcessing(EngineProcessing processing) =>
      switch (processing) {
        EngineProcessing.idle => AudioProcessingState.idle,
        EngineProcessing.loading => AudioProcessingState.loading,
        EngineProcessing.buffering => AudioProcessingState.buffering,
        EngineProcessing.ready => AudioProcessingState.ready,
        EngineProcessing.completed => AudioProcessingState.completed,
      };
}

class _Preloaded {
  const _Preloaded(this.entryId, this.duration);

  final int entryId;
  final Duration? duration;
}

/// A running crossfade: [outgoing] fades out until [endsAt] while
/// [incoming], already the current song, fades in.
class _Fade {
  const _Fade({
    required this.outgoing,
    required this.incoming,
    required this.length,
    required this.endsAt,
  });

  final PlayerSlot outgoing;
  final PlayerSlot incoming;
  final Duration length;
  final Duration endsAt;
}
