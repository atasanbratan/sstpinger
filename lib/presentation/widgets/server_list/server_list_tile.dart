import 'package:flutter/material.dart';

import '../../../core/utils/country_flag.dart';
import '../../../domain/entities/vpn_server.dart';
import '../../bloc/vpn/vpn_bloc.dart';
import '../../theme/app_colors.dart';
import '../rounded_list_tile.dart';
import '../server_group_header.dart';
import '../server_list_item.dart';
import '../server_row.dart';
import 'server_grouping.dart';

/// Renders one [ServerListItem] — either a country group header or a server
/// row — with its bottom gap applied. Pulled out of [ServerListView] because
/// it was the largest single chunk of that file's build logic.
class ServerListTile extends StatelessWidget {
  final ServerListItem item;
  final VpnState vpn;
  final ValueChanged<String> onToggleGroup;
  final ValueChanged<VpnServer> onSelectServer;
  final ValueChanged<VpnServer> onToggleBookmark;

  const ServerListTile({
    super.key,
    required this.item,
    required this.vpn,
    required this.onToggleGroup,
    required this.onSelectServer,
    required this.onToggleBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    final tile = switch (item) {
      ServerHeaderItem h => ServerGroupHeader(
        leading: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceDeep,
          ),
          child: Text(
            countryFlagEmoji(h.servers.first.countryShort),
            style: const TextStyle(fontSize: 15),
          ),
        ),
        title: h.country.toUpperCase(),
        reachable: reachableCount(h.servers),
        isExpanded: h.isExpanded,
        roundBottom: !h.isExpanded,
        onToggle: () => onToggleGroup(h.country),
      ),
      ServerRowItem r => RoundedListTile(
        roundTop: r.roundTop,
        roundBottom: r.roundBottom,
        child: ServerRow(
          server: r.server,
          isSelected: !vpn.useCustomConfig &&
              vpn.selectedServer?.endpoint == r.server.endpoint,
          isBookmarked: vpn.isBookmarked(r.server),
          onTap: () => onSelectServer(r.server),
          onBookmarkToggle: () => onToggleBookmark(r.server),
          showBottomDivider: !r.roundBottom,
        ),
      ),
    };
    return item.bottomGap > 0
        ? Padding(padding: EdgeInsets.only(bottom: item.bottomGap), child: tile)
        : tile;
  }
}
