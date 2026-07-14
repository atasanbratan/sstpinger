import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/vpn/vpn_bloc.dart';
import '../theme/app_colors.dart';

class ActivationScreen extends StatelessWidget {
  const ActivationScreen({super.key});

  Future<void> _pasteFromClipboard(BuildContext context) async {
    final bloc = context.read<VpnBloc>();
    // Capture before the async gap so we don't use `context` across it.
    final messenger = ScaffoldMessenger.of(context);
    if (bloc.state.isImportingActivation) return;

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();

    if (text == null || text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Clipboard is empty. Copy your activation code first.',
            style: TextStyle(fontFamily: 'Outfit'),
          ),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    bloc.add(ActivationCodeSubmitted(text));
  }

  @override
  Widget build(BuildContext context) {
    final isImporting = context.select<VpnBloc, bool>(
      (b) => b.state.isImportingActivation,
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.gradientTop, AppColors.gradientBottom],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/logo/logo.png', width: 96, height: 96),
                const SizedBox(height: 20),
                const Text(
                  'SSTP SHIELD',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your Secure Gateway to SSTP VPN Nodes',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white54),
                ),
                const SizedBox(height: 48),

                const Text(
                  'Paste your activation code to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 28),

                // A single, prominent pill action — the shape Happ uses for its
                // Clipboard / QR-Code controls.
                Material(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () => _pasteFromClipboard(context),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.accentBorderFaint),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: isImporting
                                ? const CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.accent,
                                  )
                                : const Icon(
                                    Icons.content_paste_rounded,
                                    color: AppColors.accent,
                                    size: 22,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isImporting ? 'Activating…' : 'Clipboard',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
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
