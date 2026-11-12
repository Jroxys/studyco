import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.size = 22,
    this.onSelected,
    this.enabled = true,
  });
  final ValueChanged<int>? onSelected;
  final bool enabled;
  final double rating;
  final double size;
  @override
  Widget build(BuildContext context) {
    if (onSelected != null) {
      return Wrap(
        children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              tooltip: '$i yıldız',
              onPressed: enabled ? () => onSelected!(i) : null,
              icon: Icon(
                rating >= i ? Icons.star_rounded : Icons.star_outline_rounded,
                color: Theme.of(context).colorScheme.secondary,
                size: size,
              ),
            ),
        ],
      );
    }
    final rounded = (rating.clamp(0, 5) * 2).round() / 2;
    return Semantics(
      label: '5 üzerinden ${rating.toStringAsFixed(1)} yıldız',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  rounded >= i + 1
                      ? Icons.star_rounded
                      : rounded >= i + .5
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded,
                  size: size,
                  applyTextScaling: false,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
