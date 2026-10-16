import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tuniq/core/widgets/artwork.dart';
import 'package:tuniq/features/library/data/artwork_repository.dart';
import 'package:tuniq/features/library/domain/song.dart';

/// Real album art when available, otherwise the tinted placeholder.
/// The loaded bytes are widget-local state; ArtworkRepository caches them.
class SongArtwork extends StatefulWidget {
  const SongArtwork({
    required this.song,
    this.size,
    this.borderRadius = 8,
    super.key,
  });

  final Song song;

  /// Square size; null fills the largest square that fits.
  final double? size;
  final double borderRadius;

  @override
  State<SongArtwork> createState() => _SongArtworkState();
}

class _SongArtworkState extends State<SongArtwork> {
  Uint8List? _bytes;
  String? _requestKey;

  void _resolve(double logicalSize) {
    final repository = context.read<ArtworkRepository>();
    final sizePx = ArtworkRepository.bucketFor(
      logicalSize,
      MediaQuery.devicePixelRatioOf(context),
    );
    final key = '${widget.song.id}@$sizePx';
    if (key == _requestKey) return;
    _requestKey = key;

    if (repository.isCached(widget.song, sizePx)) {
      _bytes = repository.cached(widget.song, sizePx);
      return;
    }
    _bytes = null;
    repository.load(widget.song, sizePx).then((bytes) {
      // Ignore results for a song this widget no longer shows.
      if (mounted && _requestKey == key) setState(() => _bytes = bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logical = widget.size ?? constraints.biggest.shortestSide;
        if (logical.isFinite && logical > 0) _resolve(logical);
        final bytes = _bytes;
        if (bytes == null) {
          return Artwork(
            seed: widget.song.albumId,
            size: widget.size,
            borderRadius: widget.borderRadius,
          );
        }
        final image = ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
        );
        return ExcludeSemantics(
          child: widget.size == null
              ? AspectRatio(aspectRatio: 1, child: image)
              : SizedBox.square(dimension: widget.size, child: image),
        );
      },
    );
  }
}
