import 'package:file_selector/file_selector.dart';
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
      _showError(messenger, 'Clipboard is empty. Copy your activation code first.');
      return;
    }

    bloc.add(ActivationCodeSubmitted(text));
  }

  /// Loads the activation code from a `.txt` file — the file the operator saves
  /// with the admin console's Download button.
  Future<void> _importFromFile(BuildContext context) async {
    final bloc = context.read<VpnBloc>();
    final messenger = ScaffoldMessenger.of(context);
    if (bloc.state.isImportingActivation) return;

    const group = XTypeGroup(label: 'Activation code', extensions: ['txt']);
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return; // cancelled

    final text = (await file.readAsString()).trim();
    if (text.isEmpty) {
      _showError(messenger, 'That file is empty. Pick your activation code file.');
      return;
    }

    bloc.add(ActivationCodeSubmitted(text));
  }

  void _showError(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Outfit')),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// A tappable pill (icon over/left of a label), the onboarding action shape.
  Widget _pill({
    required IconData icon,
    required String label,
    required bool busy,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.accentBorderFaint),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: busy
                    ? const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.accent,
                      )
                    : Icon(icon, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

                // Two pill actions side by side — the shape Happ uses for its
                // Clipboard / QR-Code controls. Paste from the clipboard, or load
                // the activation-code file saved by the admin console.
                Row(
                  children: [
                    Expanded(
                      child: _pill(
                        icon: Icons.content_paste_rounded,
                        label: isImporting ? 'Activating…' : 'Clipboard',
                        busy: isImporting,
                        onTap: () => _pasteFromClipboard(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _pill(
                        icon: Icons.folder_open_rounded,
                        label: 'From file',
                        busy: false,
                        onTap: () => _importFromFile(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
