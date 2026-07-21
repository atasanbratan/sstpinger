import 'package:flutter/material.dart';

/// Wraps one row of a lazily-built list so only the first/last tile in a run
/// gets rounded corners — reproducing a single rounded card's look from
/// independent sliver items, so long lists can be virtualized without losing
/// the rounded-card appearance.
class RoundedListTile extends StatelessWidget {
  static const _radius = Radius.circular(14);

  final bool roundTop;
  final bool roundBottom;
  final Widget child;

  const RoundedListTile({
    super.key,
    required this.roundTop,
    required this.roundBottom,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!roundTop && !roundBottom) return child;
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: roundTop ? _radius : Radius.zero,
        bottom: roundBottom ? _radius : Radius.zero,
      ),
      child: child,
    );
  }
}
