import 'package:equatable/equatable.dart';

import '../../core/utils/version.dart';

/// What the backend advertises about the newest build, published from its
/// `config` sheet and piggybacked on the server fetch.
///
/// Every field is nullable on purpose: a missing value means "nothing to say",
/// never an error. An updater must never be able to break the app, so an absent
/// or malformed feed simply shows nothing.
class AppUpdateInfo extends Equatable {
  /// Newest published version, e.g. `2.4.0`.
  final String? latestVersion;

  /// Oldest version still supported. A client below this is forced to update —
  /// the lever for retiring builds that talk to a dead backend deployment.
  final String? minVersion;

  /// Where to get it (releases page, or a mirror if GitHub is blocked).
  final String? updateUrl;

  const AppUpdateInfo({this.latestVersion, this.minVersion, this.updateUrl});

  static const AppUpdateInfo none = AppUpdateInfo();

  bool get isEmpty =>
      latestVersion == null && minVersion == null && updateUrl == null;

  /// Classifies [runningVersion] against this advertisement.
  ///
  /// Returns [AppUpdateStatus.none] (show nothing) when there is no `latest` to
  /// compare against or the client is already at/above it — `minVersion` alone
  /// cannot drive the UI without a `latest` to display. Returns
  /// [AppUpdateStatus.required] when `latest` and `min` are both set and the
  /// running version is below `min` — the blocking, must-update lever that can
  /// retire builds independently of `latest`. Otherwise, when a newer build
  /// exists and the client is not below `min`, returns [AppUpdateStatus.optional]
  /// — advisory, dismissible.
  AppUpdateStatus statusOf(String runningVersion) {
    final latest = latestVersion;
    final min = minVersion;
    if (latest == null) return AppUpdateStatus.none;
    if (min != null && compareVersions(runningVersion, min) < 0) {
      return AppUpdateStatus.required;
    }
    if (compareVersions(runningVersion, latest) < 0) {
      return AppUpdateStatus.optional;
    }
    return AppUpdateStatus.none;
  }

  @override
  List<Object?> get props => [latestVersion, minVersion, updateUrl];
}

/// What the UI should do about an advertised update, derived from the running
/// version vs the backend's `latest`/`min`.
enum AppUpdateStatus {
  /// Nothing advertised, or already up to date.
  none,

  /// A newer build exists; show a dismissible advisory banner.
  optional,

  /// The running version is below `minVersion`; show a blocking dialog.
  required,
}
