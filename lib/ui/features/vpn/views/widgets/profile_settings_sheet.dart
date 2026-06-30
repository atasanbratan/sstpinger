import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../view_models/vpn_view_model.dart';

class ProfileSettingsSheet extends StatelessWidget {
  final VpnViewModel viewModel;
  final VoidCallback onEditUsername;
  final ValueChanged<bool> onUseCustomConfigChanged;

  const ProfileSettingsSheet({
    super.key,
    required this.viewModel,
    required this.onEditUsername,
    required this.onUseCustomConfigChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'SETTINGS & PROFILE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'USER PROFILE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, color: Color(0xFF00D2FF)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Username',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white38,
                                    ),
                                  ),
                                  Text(
                                    viewModel.username,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.white70,
                                size: 18,
                              ),
                              onPressed: onEditUsername,
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 24),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_android,
                              color: Color(0xFF9D4EDD),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Device Advertising ID',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white38,
                                    ),
                                  ),
                                  Text(
                                    viewModel.deviceId,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.copy,
                                color: Colors.white70,
                                size: 18,
                              ),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: viewModel.deviceId),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Device ID copied to clipboard',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'USE CUSTOM NODE SETTINGS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white38,
                      ),
                    ),
                    Switch(
                      value: viewModel.useCustomConfig,
                      activeColor: const Color(0xFF00D2FF),
                      onChanged: (val) {
                        setModalState(() {
                          onUseCustomConfigChanged(val);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (viewModel.useCustomConfig) ...[
                  TextField(
                    controller: viewModel.customHostController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Host IP / Hostname',
                      labelStyle: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF00D2FF)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: viewModel.customPortController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            labelStyle: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF00D2FF)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: viewModel.customUsernameController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'VPN User',
                            labelStyle: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF00D2FF)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: viewModel.customPasswordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'VPN Password',
                      labelStyle: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF00D2FF)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }
}
