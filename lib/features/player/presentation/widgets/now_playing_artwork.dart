import 'package:flutter/material.dart';
import 'package:tuniq/core/widgets/artwork.dart';
import 'package:tuniq/features/library/domain/song.dart';

/// Artwork shared by the mini and full player; the Hero makes it grow from
/// the mini-player into the full player, as in YouTube Music.
class NowPlayingArtwork extends StatelessWidget {
  const NowPlayingArtwork({
    required this.song,
    this.size,
    this.borderRadius = 8,
    super.key,
  });

  static const heroTag = 'now-playing-artwork';

  final Song song;
  final double? size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: Artwork(seed: song.albumId, size: size, borderRadius: borderRadius),
    );
  }
}
