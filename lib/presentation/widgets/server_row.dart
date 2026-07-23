import 'package:flutter/material.dart';

import '../../core/utils/country_flag.dart';
import '../../domain/entities/vpn_server.dart';
import '../theme/app_colors.dart';

/// One server in the list: circular flag, country name, latency, and a
/// chevron. The selected row is marked by a left accent bar and a tinted
/// background.
class ServerRow extends StatelessWidget {
  final VpnServer server;
  final bool isSelected;
  final bool isBookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmarkToggle;

  /// A 1px separator below the row, so adjacent servers in a list read as
  /// distinct rows rather than one solid block. The last row in a run omits
  /// it — the card's rounded bottom edge already closes it off.
  final bool showBottomDivider;

  const ServerRow({
    super.key,
    required this.server,
    required this.isSelected,
    required this.isBookmarked,
    required this.onTap,
    required this.onBookmarkToggle,
    this.showBottomDivider = false,
  });

  /// Ping is always shown green: every listed server is reachable, and users
  /// read amber/red latency as "won't work" when it works fine. The number
  /// still conveys speed; the colour no longer alarms.
  static Color _pingColor(int ping) => AppColors.pingGood;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.rowSelected : AppColors.row,
            border: Border(
              left: BorderSide(
                color: isSelected ? AppColors.accent : Colors.transparent,
                width: 3,
              ),
              bottom: showBottomDivider
                  ? const BorderSide(color: AppColors.divider, width: 1)
                  : BorderSide.none,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
          child: Row(
            children: [
              // Circular flag badge.
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceDeep,
                ),
                child: Text(
                  countryFlagEmoji(server.countryShort),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  server.country.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                server.ping != null ? '${server.ping}ms' : 'n/a',
                style: TextStyle(
                  color: server.ping != null
                      ? _pingColor(server.ping!)
                      : AppColors.textFaint,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                tooltip: isBookmarked ? 'Remove bookmark' : 'Bookmark',
                onPressed: onBookmarkToggle,
                icon: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: isBookmarked ? AppColors.accent : AppColors.textFaint,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textFaint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
