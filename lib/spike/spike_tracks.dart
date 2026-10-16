import 'package:flutter/foundation.dart';

class SpikeTrack {
  const SpikeTrack({required this.title, required this.uri});

  final String title;
  final Uri uri;
}

// Shared by both tabs so iOS library songs can be fed into the crossfade test.
final spikeTracks = ValueNotifier<List<SpikeTrack>>(defaultSpikeTracks());

List<SpikeTrack> defaultSpikeTracks() => [
      SpikeTrack(
        title: 'Test tone A (440 Hz)',
        uri: Uri.parse('asset:///assets/spike/tone_a.wav'),
      ),
      SpikeTrack(
        title: 'Test tone B (659 Hz)',
        uri: Uri.parse('asset:///assets/spike/tone_b.wav'),
      ),
    ];

void addSpikeTrack(SpikeTrack track) {
  spikeTracks.value = [...spikeTracks.value, track];
}
