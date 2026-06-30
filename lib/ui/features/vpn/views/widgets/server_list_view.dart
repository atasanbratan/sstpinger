import 'package:flutter/material.dart';

import '../../view_models/vpn_view_model.dart';

class ServerListView extends StatelessWidget {
  final VpnViewModel viewModel;
  final String Function(String) getFlagEmoji;
  final VoidCallback onEditUsername;

  const ServerListView({
    super.key,
    required this.viewModel,
    required this.getFlagEmoji,
    required this.onEditUsername,
  });

  @override
  Widget build(BuildContext context) {
    if (viewModel.isFetchingServers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF00D2FF)),
        ),
      );
    }

    if (viewModel.serverFetchError != null) {
      return Card(
        color: const Color(0xFF2D161F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 36,
              ),
              const SizedBox(height: 8),
              const Text(
                'Fetch Error',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                viewModel.serverFetchError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: viewModel.fetchServers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('RETRY'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: onEditUsername,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('CHANGE USERNAME'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final filtered = viewModel.getFilteredServers();

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: Text(
            'No servers match your search filter.',
            style: TextStyle(color: Colors.white38),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final server = filtered[index];
        final bool isSelected =
            !viewModel.useCustomConfig &&
            viewModel.selectedServer?.id == server.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: InkWell(
            onTap: () => viewModel.selectServer(server),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1E2D4A)
                    : const Color(0xFF151D30),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF00D2FF).withOpacity(0.5)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      getFlagEmoji(server.countryShort),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          server.country.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          server.hostname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${server.ip}:${server.port}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.cyan[200],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white38,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Sessions: ${server.sessions}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (server.ping != null)
                    Text(
                      '${server.ping} ms',
                      style: TextStyle(
                        color: server.ping! < 80
                            ? Colors.green
                            : server.ping! < 150
                            ? Colors.orange
                            : Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    const Text(
                      '--',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  const SizedBox(width: 8),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF00D2FF),
                      size: 22,
                    )
                  else
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white38,
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
