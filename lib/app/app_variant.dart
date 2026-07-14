/// Which product variant this build is.
///
/// The variant is chosen by the entry point that runs the app
/// (`main.dart`, `main_foreign.dart`) and threaded down so shared code can
/// branch on audience without duplicating whole screens.
///
/// Build a specific variant with:
///   flutter build apk --target lib/main.dart          # local
///   flutter build apk --target lib/main_foreign.dart  # foreign
///
/// The operator console used to be a third variant here. It now lives in its own
/// project (`~/Projects/sstp_shield_vpn_admin`), so the management UI is neither
/// shipped to end users nor published in this repository.
enum AppVariant {
  /// Local users. Onboarding is an activation code. (`main.dart`)
  local,

  /// Foreign users. Onboarding is a crypto (BEP20/TRC20) subscription.
  /// (`main_foreign.dart`)
  foreign;

  bool get isLocal => this == AppVariant.local;
  bool get isForeign => this == AppVariant.foreign;
}
