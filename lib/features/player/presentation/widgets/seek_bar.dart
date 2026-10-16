import 'package:flutter/material.dart';
import 'package:tuniq/core/utils/duration_format.dart';

/// Slider with elapsed and total time. Drag position is local widget state
/// so the thumb doesn't jump back while the user is still dragging.
class SeekBar extends StatefulWidget {
  const SeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
    super.key,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _dragMs;

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.duration.inMilliseconds.toDouble();
    final enabled = totalMs > 0;
    final max = enabled ? totalMs : 1.0;
    final valueMs = (_dragMs ?? widget.position.inMilliseconds.toDouble()).clamp(0.0, max);
    final style = Theme.of(context).textTheme.labelMedium;

    return Column(
      children: [
        Slider(
          value: valueMs,
          max: max,
          onChanged: enabled ? (v) => setState(() => _dragMs = v) : null,
          onChangeEnd: (v) {
            widget.onSeek(Duration(milliseconds: v.round()));
            setState(() => _dragMs = null);
          },
          semanticFormatterCallback: (v) =>
              formatDuration(Duration(milliseconds: v.round())),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatDuration(Duration(milliseconds: valueMs.round())), style: style),
              Text(formatDuration(widget.duration), style: style),
            ],
          ),
        ),
      ],
    );
  }
}
