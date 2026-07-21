import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// A centered message sliver for empty search results / empty bookmarks /
/// empty recents.
class EmptyStateSliver extends StatelessWidget {
  final String message;

  const EmptyStateSliver(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textFaint),
          ),
        ),
      ),
    );
  }
}
