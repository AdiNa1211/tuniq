import 'dart:async';

import 'package:audio_session/audio_session.dart';

enum AudioInterruption {
  /// Another app or a call took the audio: pause, maybe resume later.
  pause,

  /// The interruption ended and playback may resume.
  resume,

  /// The interruption ended, but the system says not to resume.
  ended,

  /// Headphones were unplugged or Bluetooth disconnected: pause for good.
  becameNoisy,
}

abstract interface class InterruptionSource {
  Stream<AudioInterruption> get events;
}

/// Interruptions from audio_session. Ducking is left to Android, which
/// lowers music automatically for navigation prompts.
class AudioSessionInterruptions implements InterruptionSource {
  AudioSessionInterruptions(this._session);

  final AudioSession _session;

  @override
  Stream<AudioInterruption> get events {
    late final StreamController<AudioInterruption> controller;
    final subscriptions = <StreamSubscription<Object?>>[];
    controller = StreamController<AudioInterruption>(
      onListen: () => subscriptions
        ..add(_session.interruptionEventStream.listen((event) {
          final interruption = interruptionFor(event);
          if (interruption != null) controller.add(interruption);
        }))
        ..add(_session.becomingNoisyEventStream
            .listen((_) => controller.add(AudioInterruption.becameNoisy))),
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  static AudioInterruption? interruptionFor(AudioInterruptionEvent event) =>
      switch ((event.begin, event.type)) {
        (_, AudioInterruptionType.duck) => null,
        (true, _) => AudioInterruption.pause,
        (false, AudioInterruptionType.pause) => AudioInterruption.resume,
        (false, AudioInterruptionType.unknown) => AudioInterruption.ended,
      };
}
