import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Drill-down from Settings → App → FAQ. Answers about the app's real
/// settings, lifted from the doc comments on the widgets they describe.
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const _entries = [
    (
      question: 'What does the Protocol setting do?',
      answer:
          'Chooses which VPN protocol is used to connect: SSTP or SoftEther '
          '(desktop only — there is no SoftEther client for mobile). If you '
          'pick SoftEther, the SoftEther Transport setting controls how it '
          'negotiates the connection.',
    ),
    (
      question: 'What is the curated region server list?',
      answer:
          'Switches the server list from the full public pool to a smaller '
          'set an operator has verified reachable from a specific ISP. Leave '
          'it off to see every available server.',
    ),
    (
      question: 'What is proxy sharing?',
      answer:
          'Starts a local SOCKS5 proxy so other devices on your network can '
          'route through this device\'s active VPN tunnel. Works on Linux, '
          'Windows, and Android; the setting is saved on other platforms even '
          'though it has no effect yet there.',
    ),
    (
      question: 'Fast vs. Accurate ping mode — what\'s the difference?',
      answer:
          'Fast does a plain TCP connect to check if a server is reachable. '
          'Accurate performs a real TLS handshake through the relay, so a '
          'server it marks reachable can actually complete an SSTP '
          'connection — slower, but more trustworthy.',
    ),
    (
      question: 'What is custom node?',
      answer:
          'Lets you bypass the fetched server list entirely and connect to a '
          'VPN server you specify yourself (host, port, username, password).',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('FAQ'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 20),
        itemBuilder: (context, i) {
          final entry = _entries[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.question,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                entry.answer,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
