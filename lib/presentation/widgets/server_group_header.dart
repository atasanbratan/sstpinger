import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'rounded_list_tile.dart';

/// The tappable header row of a collapsible country group: chevron, leading
/// badge, title over a subtitle, trailing actions. The rows themselves are
/// separate sliver list items (see [ServerListView]) so large lists stay
/// lazily built; this only draws the header tile, rounding its own corners
/// per [roundBottom] (true while collapsed, since it is then the whole card).
class ServerGroupHeader extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final bool isExpanded;
  final bool roundBottom;
  final VoidCallback onToggle;

  /// How many servers in this group are reachable; rendered in green after the
  /// subtitle. Zero hides the reachable clause.
  final int reachable;

  const ServerGroupHeader({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.isExpanded,
    required this.roundBottom,
    required this.onToggle,
    this.reachable = 0,
  });

  @override
  Widget build(BuildContext context) {
    return RoundedListTile(
      roundTop: true,
      roundBottom: roundBottom,
      child: Material(
        color: AppColors.groupHeader,
        child: InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                leading,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textFaint,
                          ),
                          children: [
                            TextSpan(text: subtitle),
                            if (reachable > 0)
                              TextSpan(
                                text: ' · $reachable reachable',
                                style: const TextStyle(
                                  color: AppColors.pingGood,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
