import 'package:sstp_shield/app/app.dart';
import 'package:sstp_shield/app/app_variant.dart';
import 'package:sstp_shield/core/logging/bootstrap.dart';

/// Foreign variant: crypto (BEP20/TRC20) subscription onboarding.
/// Build: `flutter build apk --target lib/main_foreign.dart`
void main() => bootstrapAndRun(const SstpVpnApp(variant: AppVariant.foreign));
