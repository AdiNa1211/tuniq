import 'dart:async';

import 'package:tuniq/core/audio/interruptions.dart';

class FakeInterruptions implements InterruptionSource {
  final _events = StreamController<AudioInterruption>.broadcast();

  @override
  Stream<AudioInterruption> get events => _events.stream;

  void emit(AudioInterruption interruption) => _events.add(interruption);
}
