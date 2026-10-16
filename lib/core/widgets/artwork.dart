import 'package:flutter/material.dart';

/// Tinted placeholder for songs without album art.
class Artwork extends StatelessWidget {
  const Artwork({
    required this.seed,
    this.size,
    this.borderRadius = 8,
    super.key,
  });

  /// Picks the tint, so songs from one album share a colour.
  final String seed;

  /// Square size; null fills the largest square that fits.
  final double? size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tints = [
      (scheme.primaryContainer, scheme.onPrimaryContainer),
      (scheme.secondaryContainer, scheme.onSecondaryContainer),
      (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    ];
    final (background, foreground) = tints[seed.hashCode.abs() % tints.length];

    final art = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: Icon(
            Icons.music_note,
            color: foreground,
            size: constraints.biggest.shortestSide * 0.45,
          ),
        ),
      ),
    );

    return ExcludeSemantics(
      child: size == null
          ? AspectRatio(aspectRatio: 1, child: art)
          : SizedBox.square(dimension: size, child: art),
    );
  }
}
