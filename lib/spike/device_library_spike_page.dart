import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tuniq/spike/spike_tracks.dart';

/// Spike 2: find music already on the device (MediaStore on Android, the
/// Music app library on iOS) and check that just_audio can play it.
class DeviceLibrarySpikePage extends StatefulWidget {
  const DeviceLibrarySpikePage({super.key});

  @override
  State<DeviceLibrarySpikePage> createState() => _DeviceLibrarySpikePageState();
}

class _DeviceLibrarySpikePageState extends State<DeviceLibrarySpikePage> {
  // Both native channels expose the same method names and song map keys.
  static final _channel = MethodChannel(
    Platform.isIOS ? 'tuniq/ios_media_library' : 'tuniq/media_store',
  );

  final _player = AudioPlayer();
  final _log = <String>[];
  String _status = 'unknown';
  List<_DeviceSong> _songs = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    final status = await _channel.invokeMethod<String>('authorizationStatus');
    setState(() => _status = status ?? 'unknown');
    if (_status == 'authorized') unawaited(_loadSongs());
  }

  Future<void> _requestAccess() async {
    try {
      final status = await _channel.invokeMethod<String>('requestAuthorization');
      setState(() => _status = status ?? 'unknown');
      _addLog('Permission: $_status');
      if (_status == 'authorized') unawaited(_loadSongs());
    } on PlatformException catch (e) {
      _addLog('Permission request FAILED: ${e.message}');
    }
  }

  Future<void> _loadSongs() async {
    setState(() => _loading = true);
    final watch = Stopwatch()..start();
    try {
      final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
            'querySongs',
          ) ??
          const [];
      setState(() => _songs = raw.map(_DeviceSong.fromMap).toList());
      final playable = _songs.where((s) => s.playable).length;
      _addLog(
        'Found ${_songs.length} songs in ${watch.elapsedMilliseconds} ms; '
        '$playable playable',
      );
    } on PlatformException catch (e) {
      _addLog('Scan FAILED: ${e.message}');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _playDirect(_DeviceSong song) async {
    final watch = Stopwatch()..start();
    try {
      final duration = await _player.setAudioSource(
        AudioSource.uri(Uri.parse(song.assetUrl!)),
      );
      unawaited(_player.play());
      _addLog(
        'Play OK: "${song.title}" loaded in ${watch.elapsedMilliseconds} ms, '
        'duration ${duration?.inSeconds ?? '?'} s',
      );
    } catch (e) {
      _addLog('Play FAILED: "${song.title}": $e');
    }
  }

  // iOS fallback: copy the song to an .m4a file first.
  Future<void> _exportAndPlay(_DeviceSong song) async {
    final watch = Stopwatch()..start();
    try {
      final path = await _channel.invokeMethod<String>(
        'exportSong',
        {'id': song.id},
      );
      final exportMs = watch.elapsedMilliseconds;
      await _player.setFilePath(path!);
      unawaited(_player.play());
      _addLog('Export OK: "${song.title}" exported in $exportMs ms');
    } catch (e) {
      _addLog('Export FAILED: "${song.title}": $e');
    }
  }

  void _addToCrossfade(Iterable<_DeviceSong> songs) {
    for (final song in songs) {
      addSpikeTrack(SpikeTrack(title: song.title, uri: Uri.parse(song.assetUrl!)));
    }
    _addLog('Added ${songs.length} song(s) to the crossfade list');
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() => _log.insert(0, message));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final playable = _songs.where((s) => s.playable).toList();
    final blocked = _status == 'permanentlyDenied' ||
        (Platform.isIOS && _status == 'denied');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Music access: $_status', style: text.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (blocked)
              FilledButton(
                onPressed: () => _channel.invokeMethod<void>('openSettings'),
                child: const Text('Open Settings'),
              )
            else
              FilledButton(
                onPressed: _status == 'authorized' ? null : _requestAccess,
                child: const Text('Allow access'),
              ),
            OutlinedButton(
              onPressed: _status == 'authorized' && !_loading ? _loadSongs : null,
              child: Text(_loading ? 'Scanning…' : 'Rescan'),
            ),
            OutlinedButton(
              onPressed: playable.length < 2
                  ? null
                  : () => _addToCrossfade(playable.take(5)),
              child: const Text('Add 5 to crossfade'),
            ),
            OutlinedButton(
              onPressed: () => _player.stop(),
              child: const Text('Stop'),
            ),
          ],
        ),
        if (blocked)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Access was denied. Turn it on in Settings, then come back.'),
          ),
        if (_songs.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_summary(playable.length)),
        ],
        const Divider(height: 32),
        Text('Log', style: text.titleMedium),
        for (final line in _log.take(30))
          Text(line, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        const Divider(height: 32),
        Text('Playable songs', style: text.titleMedium),
        if (_status == 'authorized' && !_loading && playable.isEmpty)
          const Text('No music found on this device.'),
        for (final song in playable.take(100))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(song.title),
            subtitle: Text(
              [song.artist, song.folder].where((s) => s.isNotEmpty).join(' · '),
            ),
            onTap: () => _playDirect(song),
            trailing: PopupMenuButton<String>(
              onSelected: (action) {
                switch (action) {
                  case 'play':
                    _playDirect(song);
                  case 'export':
                    _exportAndPlay(song);
                  default:
                    _addToCrossfade([song]);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'play', child: Text('Play')),
                if (Platform.isIOS)
                  const PopupMenuItem(
                    value: 'export',
                    child: Text('Export to file, then play'),
                  ),
                const PopupMenuItem(value: 'add', child: Text('Add to crossfade list')),
              ],
            ),
          ),
      ],
    );
  }

  String _summary(int playable) {
    if (!Platform.isIOS) return 'Total ${_songs.length} · playable $playable';
    final cloud = _songs.where((s) => s.isCloudItem).length;
    final protected = _songs.where((s) => s.hasProtectedAsset).length;
    return 'Total ${_songs.length} · playable $playable · '
        'cloud-only $cloud · protected $protected';
  }
}

class _DeviceSong {
  const _DeviceSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.folder,
    required this.assetUrl,
    required this.isCloudItem,
    required this.hasProtectedAsset,
  });

  factory _DeviceSong.fromMap(Map<Object?, Object?> map) => _DeviceSong(
        id: map['id']! as String,
        title: map['title'] as String? ?? '',
        artist: map['artist'] as String? ?? '',
        folder: map['folder'] as String? ?? '',
        assetUrl: map['assetUrl'] as String?,
        isCloudItem: map['isCloudItem'] as bool? ?? false,
        hasProtectedAsset: map['hasProtectedAsset'] as bool? ?? false,
      );

  final String id;
  final String title;
  final String artist;
  final String folder;
  final String? assetUrl;
  final bool isCloudItem;
  final bool hasProtectedAsset;

  // iOS: Apple Music downloads are DRM-protected; cloud items have no local file.
  bool get playable => assetUrl != null && !isCloudItem && !hasProtectedAsset;
}
