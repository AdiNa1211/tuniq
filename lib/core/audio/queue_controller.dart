import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:tuniq/core/audio/engine_state.dart';
import 'package:tuniq/features/library/domain/song.dart';

/// One slot in the queue. The id keeps duplicates of a song apart.
class QueueEntry extends Equatable {
  const QueueEntry({required this.id, required this.song});

  final int id;
  final Song song;

  @override
  List<Object?> get props => [id, song];
}

/// Play order, shuffle, repeat and queue edits. Pure Dart, no audio.
class QueueController {
  QueueController({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Order the user chose; restored when shuffle is turned off.
  List<QueueEntry> _original = [];

  /// What actually plays next; equals [_original] when not shuffled.
  List<QueueEntry> _order = [];
  int _index = 0;
  int _nextId = 0;
  bool _shuffle = false;

  PlayerRepeatMode repeat = PlayerRepeatMode.off;

  List<QueueEntry> get entries => List.unmodifiable(_order);
  int get length => _order.length;
  bool get isEmpty => _order.isEmpty;
  int get currentIndex => _index;
  bool get shuffle => _shuffle;
  QueueEntry? get current => _order.isEmpty ? null : _order[_index];

  /// New queue. [shufflePlay] (Shuffle button) starts somewhere random and
  /// turns shuffle on. Otherwise playback starts at [startIndex], and if
  /// shuffle is already on, the rest is shuffled after it.
  void replace(List<Song> songs, {int startIndex = 0, bool shufflePlay = false}) {
    _original = [for (final song in songs) QueueEntry(id: _nextId++, song: song)];
    _index = 0;
    if (_original.isEmpty) {
      _order = [];
      return;
    }
    if (shufflePlay) {
      _shuffle = true;
      _order = [..._original]..shuffle(_random);
      return;
    }
    final start = startIndex.clamp(0, _original.length - 1);
    if (_shuffle) {
      final rest = [..._original]..removeAt(start);
      _order = [_original[start], ...rest..shuffle(_random)];
    } else {
      _order = [..._original];
      _index = start;
    }
  }

  /// Index to play after the current track, or null at the end of the queue.
  /// Repeat-one only applies when a track ends by itself, not to a skip.
  int? nextIndex({required bool userInitiated}) {
    if (_order.isEmpty) return null;
    if (!userInitiated && repeat == PlayerRepeatMode.one) return _index;
    if (_index < _order.length - 1) return _index + 1;
    return repeat == PlayerRepeatMode.off ? null : 0;
  }

  int? previousIndex() {
    if (_order.isEmpty) return null;
    if (_index > 0) return _index - 1;
    return repeat == PlayerRepeatMode.off ? null : _order.length - 1;
  }

  void moveTo(int index) {
    RangeError.checkValidIndex(index, _order);
    _index = index;
  }

  /// Keeps the current song playing: it moves to the front when shuffling
  /// and back to its own place when not.
  void setShuffle(bool enabled) {
    if (enabled == _shuffle) return;
    _shuffle = enabled;
    final current = this.current;
    if (current == null) return;
    if (enabled) {
      final rest = _order.where((e) => e != current).toList()..shuffle(_random);
      _order = [current, ...rest];
      _index = 0;
    } else {
      _order = [..._original];
      _index = _order.indexOf(current);
    }
  }

  /// [to] is the final index after the move, as with List.insert after removeAt.
  void move(int from, int to) {
    if (from == to || !_isValid(from) || !_isValid(to)) return;
    final current = this.current!;
    _order.insert(to, _order.removeAt(from));
    if (!_shuffle) _original = [..._order];
    _index = _order.indexOf(current);
  }

  /// The current song can't be removed; returns false then.
  bool removeAt(int index) {
    if (index == _index || !_isValid(index)) return false;
    _original.remove(_order.removeAt(index));
    if (index < _index) _index--;
    return true;
  }

  void insertNext(Song song) {
    final entry = QueueEntry(id: _nextId++, song: song);
    final current = this.current;
    if (current == null) {
      _original = [entry];
      _order = [entry];
      _index = 0;
      return;
    }
    _order.insert(_index + 1, entry);
    _original.insert(_original.indexOf(current) + 1, entry);
  }

  void enqueue(Song song) {
    final entry = QueueEntry(id: _nextId++, song: song);
    _order.add(entry);
    _original.add(entry);
  }

  bool _isValid(int index) => index >= 0 && index < _order.length;
}
