import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The three panes of the server picker. Servers is the country-grouped
/// accordion; Bookmarks and Recents are flat lists.
enum ServerTab { servers, bookmarks, recents }

/// The pill row (Servers · Bookmarks · Recents, each with a count) plus the
/// grouped/flat view toggle, which only applies to the Servers tab.
class ServerTabBar extends StatelessWidget {
  final ServerTab activeTab;
  final ValueChanged<ServerTab> onTabSelected;
  final int serversCount;
  final int bookmarksCount;
  final int recentsCount;
  final bool serversFlatView;
  final VoidCallback onToggleFlatView;

  const ServerTabBar({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
    required this.serversCount,
    required this.bookmarksCount,
    required this.recentsCount,
    required this.serversFlatView,
    required this.onToggleFlatView,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _tabPill('Servers', serversCount, ServerTab.servers),
                const SizedBox(width: 8),
                _tabPill('Bookmarks', bookmarksCount, ServerTab.bookmarks),
                const SizedBox(width: 8),
                _tabPill('Recents', recentsCount, ServerTab.recents),
              ],
            ),
          ),
        ),
        if (activeTab == ServerTab.servers) _buildViewToggle(),
      ],
    );
  }

  Widget _buildViewToggle() {
    return IconButton(
      visualDensity: VisualDensity.compact,
      iconSize: 20,
      tooltip: serversFlatView ? 'Group by country' : 'Show as a flat list',
      onPressed: onToggleFlatView,
      icon: Icon(
        serversFlatView
            ? Icons.travel_explore_rounded
            : Icons.format_list_bulleted_rounded,
        color: AppColors.textMuted,
      ),
    );
  }

  Widget _tabPill(String label, int count, ServerTab tab) {
    final active = activeTab == tab;
    return Material(
      color: active ? AppColors.accent : AppColors.inputBackground,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onTabSelected(tab),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? AppColors.accent : AppColors.divider,
            ),
          ),
          child: Text(
            count > 0 ? '$label · $count' : label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.surfaceDeep : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
