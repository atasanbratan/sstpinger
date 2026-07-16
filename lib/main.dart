import 'package:sstp_shield/app/app.dart';
import 'package:sstp_shield/app/app_variant.dart';
import 'package:sstp_shield/core/logging/bootstrap.dart';

/// Local variant: activation-code onboarding.
/// Build: `flutter build apk --target lib/main.dart`
void main() => bootstrapAndRun(const SstpVpnApp(variant: AppVariant.local));
