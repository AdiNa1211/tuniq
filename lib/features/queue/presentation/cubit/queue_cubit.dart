import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tuniq/core/audio/engine_state.dart';
import 'package:tuniq/core/audio/playback_engine.dart';
import 'package:tuniq/core/audio/queue_controller.dart';
import 'package:tuniq/features/library/domain/song.dart';

class QueueState extends Equatable {
  const QueueState({this.entries = const [], this.currentIndex = 0});

  factory QueueState.fromEngine(EngineState engine) =>
      QueueState(entries: engine.queue, currentIndex: engine.currentIndex);

  /// In play order; entry ids give list rows stable keys while reordering.
  final List<QueueEntry> entries;
  final int currentIndex;

  @override
  List<Object?> get props => [entries, currentIndex];
}

/// Queue view and edits (reorder, remove, play next, add to queue).
class QueueCubit extends Cubit<QueueState> {
  QueueCubit(this._engine) : super(QueueState.fromEngine(_engine.state)) {
    _subscription = _engine.states.listen((engine) => emit(QueueState.fromEngine(engine)));
  }

  final PlaybackEngine _engine;
  late final StreamSubscription<EngineState> _subscription;

  /// ReorderableListView passes [newIndex] as if the item were still in place.
  /// The list updates right away (the engine catches up a moment later), so
  /// the dragged row doesn't snap back.
  void reorder(int oldIndex, int newIndex) {
    final to = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (to == oldIndex) return;
    final entries = [...state.entries];
    final current = entries[state.currentIndex];
    entries.insert(to, entries.removeAt(oldIndex));
    emit(QueueState(entries: entries, currentIndex: entries.indexOf(current)));
    _engine.moveQueueItem(oldIndex, to);
  }

  /// Removed from the list immediately: Dismissible requires the row to be
  /// gone on the next frame.
  void remove(int index) {
    if (index == state.currentIndex || index < 0 || index >= state.entries.length) return;
    final entries = [...state.entries]..removeAt(index);
    final current = index < state.currentIndex ? state.currentIndex - 1 : state.currentIndex;
    emit(QueueState(entries: entries, currentIndex: current));
    _engine.removeQueueItemAt(index);
  }

  void skipTo(int index) => _engine.skipToQueueItem(index);

  void playNext(Song song) => _engine.playNext(song);

  void addToQueue(Song song) => _engine.enqueue(song);

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
