import 'dart:async';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tuniq/spike/spike_tracks.dart';

/// Spike 1: can two just_audio players overlap while their volumes ramp,
/// without the OS pausing either one?
class CrossfadeSpikePage extends StatefulWidget {
  const CrossfadeSpikePage({super.key});

  @override
  State<CrossfadeSpikePage> createState() => _CrossfadeSpikePageState();
}

class _CrossfadeSpikePageState extends State<CrossfadeSpikePage> {
  static const _step = Duration(milliseconds: 50);
  static const _preloadLead = Duration(seconds: 5);

  final _names = <AudioPlayer, String>{};
  final _wasPlaying = <AudioPlayer, bool>{};
  final _expectedStops = <AudioPlayer>{};
  final _subs = <StreamSubscription<PlayerState>>[];
  final _log = <String>[];
  final _failures = <String>[];
  final _clock = Stopwatch()..start();

  late AudioPlayer _current;
  late AudioPlayer _next;
  Timer? _monitor;
  Timer? _fadeTimer;
  Future<void>? _preloadFuture;

  bool _handleInterruptions = true;
  double _fadeSeconds = 6;
  int _index = 0;
  int? _preloadedIndex;
  bool _fading = false;
  int _fadesDone = 0;
  int _maxStepMs = 0;

  List<SpikeTrack> get _tracks => spikeTracks.value;
  Duration get _fadeLength => Duration(seconds: _fadeSeconds.round());

  @override
  void initState() {
    super.initState();
    _createPlayers();
    _monitor = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  @override
  void dispose() {
    _monitor?.cancel();
    _fadeTimer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  void _createPlayers() {
    _current = _newPlayer('A');
    _next = _newPlayer('B');
  }

  AudioPlayer _newPlayer(String name) {
    final player = AudioPlayer(handleInterruptions: _handleInterruptions);
    _names[player] = name;
    _subs.add(player.playerStateStream.listen((s) => _onState(player, s)));
    return player;
  }

  Future<void> _recreatePlayers(bool handleInterruptions) async {
    _cancelFade();
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    final old = [_current, _next];
    _names.clear();
    _wasPlaying.clear();
    _expectedStops.clear();
    for (final player in old) {
      await player.dispose();
    }
    _handleInterruptions = handleInterruptions;
    _preloadedIndex = null;
    _createPlayers();
    _addLog('Players recreated, handleInterruptions=$handleInterruptions');
  }

  // A playing → not-playing transition we did not ask for means the OS
  // (usually audio focus) paused that player: the exact failure we test for.
  void _onState(AudioPlayer player, PlayerState state) {
    final was = _wasPlaying[player] ?? false;
    _wasPlaying[player] = state.playing;
    final name = _names[player];
    if (was && !state.playing) {
      if (_expectedStops.remove(player)) {
        _addLog('$name stopped by us');
      } else {
        _fail('$name was paused by the system (${state.processingState.name})');
      }
    } else if (!was && state.playing) {
      _addLog('$name playing');
    }
    if (state.processingState == ProcessingState.completed) {
      _addLog('$name completed');
    }
  }

  Future<void> _stopByUs(AudioPlayer player) async {
    if (player.playing) _expectedStops.add(player);
    await player.stop();
  }

  void _tick() {
    final duration = _current.duration;
    if (_fading || !_current.playing || duration == null || _tracks.length < 2) {
      return;
    }
    final remaining = duration - _current.position;
    final nextIndex = (_index + 1) % _tracks.length;
    if (remaining <= _fadeLength + _preloadLead && _preloadedIndex != nextIndex) {
      _preload(nextIndex);
    }
    if (remaining <= _fadeLength) _startFade(remaining: remaining);
  }

  Future<void> _preload(int index) {
    _preloadedIndex = index;
    return _preloadFuture = () async {
      try {
        await _next.setVolume(0);
        await _next.setAudioSource(AudioSource.uri(_tracks[index].uri));
        _addLog('Preloaded "${_tracks[index].title}" on ${_names[_next]}');
      } catch (e) {
        _preloadedIndex = null;
        _fail('Preload failed for "${_tracks[index].title}": $e');
      }
    }();
  }

  Future<void> _playFrom(int index) async {
    _cancelFade();
    await _stopByUs(_next);
    _preloadedIndex = null;
    _index = index;
    try {
      await _current.setVolume(1);
      await _current.setAudioSource(AudioSource.uri(_tracks[index].uri));
    } catch (e) {
      _fail('Load failed for "${_tracks[index].title}": $e');
      return;
    }
    unawaited(_current.play());
    _addLog('Start "${_tracks[index].title}" on ${_names[_current]}');
  }

  Future<void> _jumpToFadePoint() async {
    final duration = _current.duration;
    if (duration == null) return;
    final target = duration - _fadeLength - const Duration(seconds: 3);
    await _current.seek(target.isNegative ? Duration.zero : target);
    _addLog('Jumped to ${_fmt(target)}; auto-fade starts in about 3 s');
  }

  Future<void> _startFade({Duration? remaining}) async {
    if (_fading || _tracks.length < 2) return;
    _fading = true;
    final nextIndex = (_index + 1) % _tracks.length;
    if (_preloadedIndex != nextIndex) {
      await _preload(nextIndex);
    } else {
      await _preloadFuture;
    }
    if (_preloadedIndex != nextIndex) {
      _fading = false;
      return;
    }

    var fadeMs = _fadeLength.inMilliseconds;
    if (remaining != null && remaining.inMilliseconds < fadeMs) {
      fadeMs = max(remaining.inMilliseconds, 1);
    }
    final outgoing = _current;
    final incoming = _next;
    unawaited(incoming.play());
    _addLog('Fade $fadeMs ms: ${_names[outgoing]} → ${_names[incoming]}');

    final watch = Stopwatch()..start();
    var lastMs = 0;
    var midChecked = false;
    _fadeTimer = Timer.periodic(_step, (timer) {
      final ms = watch.elapsedMilliseconds;
      _maxStepMs = max(_maxStepMs, ms - lastMs);
      lastMs = ms;
      final t = (ms / fadeMs).clamp(0.0, 1.0);
      // Equal-power curve keeps perceived loudness steady through the overlap.
      outgoing.setVolume(cos(t * pi / 2));
      incoming.setVolume(sin(t * pi / 2));
      if (!midChecked && t >= 0.5) {
        midChecked = true;
        final ok = outgoing.playing &&
            incoming.playing &&
            incoming.processingState == ProcessingState.ready;
        if (ok) {
          _addLog('Mid-fade: both players audible ✓');
        } else {
          _fail('Mid-fade: outgoing=${outgoing.playing}, '
              'incoming=${incoming.playing}/${incoming.processingState.name}');
        }
      }
      if (t >= 1) {
        timer.cancel();
        _finishFade(outgoing, incoming, nextIndex);
      }
    });
  }

  Future<void> _finishFade(
    AudioPlayer outgoing,
    AudioPlayer incoming,
    int nextIndex,
  ) async {
    _fadeTimer = null;
    await _stopByUs(outgoing);
    await outgoing.setVolume(1);
    _current = incoming;
    _next = outgoing;
    _index = nextIndex;
    _preloadedIndex = null;
    _fading = false;
    _fadesDone++;
    _addLog('Fade done → "${_tracks[_index].title}" on ${_names[_current]}');
  }

  void _cancelFade() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _fading = false;
  }

  Future<void> _stopAll() async {
    _cancelFade();
    await _stopByUs(_current);
    await _stopByUs(_next);
    await _current.setVolume(1);
    _preloadedIndex = null;
    _addLog('Stopped');
  }

  Future<void> _pickFiles() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    for (final file in files) {
      addSpikeTrack(SpikeTrack(title: file.name, uri: file.uri));
    }
    _addLog('Added ${files.length} file(s)');
  }

  void _resetResults() {
    setState(() {
      _failures.clear();
      _log.clear();
      _fadesDone = 0;
      _maxStepMs = 0;
    });
  }

  void _addLog(String message) {
    if (!mounted) return;
    final s = (_clock.elapsedMilliseconds / 1000).toStringAsFixed(1);
    setState(() => _log.insert(0, '${s}s  $message'));
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _failures.add(message));
    _addLog('FAIL: $message');
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ResultCard(
          failures: _failures,
          fadesDone: _fadesDone,
          maxStepMs: _maxStepMs,
          onReset: _resetResults,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('handleInterruptions'),
          subtitle: const Text('Turn off only if the default run fails'),
          value: _handleInterruptions,
          onChanged: _fading ? null : _recreatePlayers,
        ),
        Text('Fade length: ${_fadeSeconds.round()} s'),
        Slider(
          value: _fadeSeconds,
          min: 1,
          max: 12,
          divisions: 11,
          label: '${_fadeSeconds.round()} s',
          onChanged: (v) => setState(() => _fadeSeconds = v),
        ),
        StreamBuilder<Duration>(
          stream: _current.positionStream,
          builder: (context, snap) {
            final pos = snap.data ?? Duration.zero;
            final dur = _current.duration ?? Duration.zero;
            return Text(
              '${_names[_current]} at ${_fmt(pos)} / ${_fmt(dur)}'
              '${_fading ? '  · fading' : ''}',
              style: Theme.of(context).textTheme.titleMedium,
            );
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: _tracks.isEmpty ? null : () => _playFrom(0),
              child: const Text('Play first'),
            ),
            OutlinedButton(
              onPressed: _fading ? null : _jumpToFadePoint,
              child: const Text('Jump to fade point'),
            ),
            OutlinedButton(
              onPressed: _fading || _tracks.length < 2 ? null : _startFade,
              child: const Text('Crossfade now'),
            ),
            OutlinedButton(onPressed: _stopAll, child: const Text('Stop')),
          ],
        ),
        const Divider(height: 32),
        Row(
          children: [
            Text('Tracks', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton(onPressed: _pickFiles, child: const Text('Add files')),
            TextButton(
              onPressed: () => spikeTracks.value = defaultSpikeTracks(),
              child: const Text('Reset'),
            ),
          ],
        ),
        ValueListenableBuilder<List<SpikeTrack>>(
          valueListenable: spikeTracks,
          builder: (context, tracks, _) => Column(
            children: [
              for (var i = 0; i < tracks.length; i++)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    i == _index ? Icons.play_arrow : Icons.music_note,
                    color: i == _index ? scheme.primary : null,
                  ),
                  title: Text(tracks[i].title),
                  onTap: () => _playFrom(i),
                ),
            ],
          ),
        ),
        const Divider(height: 32),
        Text('Log', style: Theme.of(context).textTheme.titleMedium),
        for (final line in _log.take(80))
          Text(
            line,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: line.contains('FAIL') ? scheme.error : null,
            ),
          ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.failures,
    required this.fadesDone,
    required this.maxStepMs,
    required this.onReset,
  });

  final List<String> failures;
  final int fadesDone;
  final int maxStepMs;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = failures.isNotEmpty;
    final verdict = failed
        ? 'FAIL'
        : fadesDone == 0
            ? 'No fades yet'
            : 'PASS so far';
    return Card(
      color: failed ? scheme.errorContainer : scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(verdict, style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton(onPressed: onReset, child: const Text('Reset')),
              ],
            ),
            Text('Fades completed: $fadesDone'),
            Text('Worst timer step: $maxStepMs ms (target ≈ 50)'),
            for (final f in failures) Text('• $f'),
          ],
        ),
      ),
    );
  }
}
