import 'dart:math' as math;

import 'package:equatable/equatable.dart';

class CrossfadeSettings extends Equatable {
  const CrossfadeSettings({this.enabled = false, int seconds = defaultSeconds})
      : seconds = seconds < minSeconds
            ? minSeconds
            : seconds > maxSeconds
                ? maxSeconds
                : seconds;

  static const minSeconds = 1;
  static const maxSeconds = 12;
  static const defaultSeconds = 6;

  final bool enabled;
  final int seconds;

  Duration get duration => Duration(seconds: seconds);

  CrossfadeSettings copyWith({bool? enabled, int? seconds}) => CrossfadeSettings(
        enabled: enabled ?? this.enabled,
        seconds: seconds ?? this.seconds,
      );

  @override
  List<Object?> get props => [enabled, seconds];
}

/// Equal-power curve: overall loudness stays steady while both tracks play.
/// Returns (outgoing, incoming) volumes for [progress] from 0 to 1.
(double, double) crossfadeVolumes(double progress) {
  final angle = progress.clamp(0.0, 1.0) * math.pi / 2;
  return (math.cos(angle), math.sin(angle));
}
