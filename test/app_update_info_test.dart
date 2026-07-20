import 'package:flutter_test/flutter_test.dart';
import 'package:sstp_shield/core/utils/version.dart';
import 'package:sstp_shield/domain/entities/app_update_info.dart';

/// Pure logic for the app-updater: version comparison + the running-vs-feed
/// classification. No mocks — kept separate from the bloc suite so a parser
/// regression here fails loudly and immediately.
void main() {
  group('compareVersions', () {
    test('orders dotted versions numerically, not lexically', () {
      expect(compareVersions('2.10.0', '2.9.0'), greaterThan(0));
      expect(compareVersions('2.9.0', '2.10.0'), lessThan(0));
      expect(compareVersions('2.4.0', '2.4.0'), 0);
      expect(compareVersions('2.4', '2.4.0'), 0);
    });

    test('ignores the build suffix and pre-release tail', () {
      expect(compareVersions('2.4.0+29', '2.4.0'), 0);
      expect(compareVersions('2.4.0-beta', '2.4.0'), 0);
      expect(compareVersions('2.4.0+29', '2.4.0-beta'), 0);
    });

    test('treats missing components as zero, not as nothing', () {
      expect(compareVersions('2', '2.0.0'), 0);
      expect(compareVersions('2.4', '2.4.1'), lessThan(0));
      expect(compareVersions('3', '2.9.9'), greaterThan(0));
    });

    test('never throws on malformed input — degrades to 0', () {
      expect(compareVersions('not-a-version', '2.4.0'), lessThan(0));
      // A malformed feed must not crash the app; garbage compares as 0/-1/1
      // against itself rather than throwing.
      expect(compareVersions('', ''), 0);
      expect(compareVersions('2.4.0', ''), greaterThan(0));
    });
  });

  group('AppUpdateInfo.statusOf', () {
    test('none when nothing is advertised', () {
      const info = AppUpdateInfo.none;
      expect(info.statusOf('2.3.0'), AppUpdateStatus.none);
    });

    test('none when already at/above latest', () {
      const info = AppUpdateInfo(latestVersion: '2.4.0');
      expect(info.statusOf('2.4.0'), AppUpdateStatus.none);
      expect(info.statusOf('2.5.0'), AppUpdateStatus.none);
    });

    test('optional when newer exists and min is unset', () {
      const info = AppUpdateInfo(latestVersion: '2.4.0');
      expect(info.statusOf('2.3.0'), AppUpdateStatus.optional);
      expect(info.statusOf('2.3.9'), AppUpdateStatus.optional);
    });

    test('optional when below latest but at/above min', () {
      const info =
          AppUpdateInfo(latestVersion: '2.4.0', minVersion: '2.3.0');
      expect(info.statusOf('2.3.0'), AppUpdateStatus.optional);
      expect(info.statusOf('2.3.5'), AppUpdateStatus.optional);
    });

    test('required only when running is below minVersion', () {
      const info =
          AppUpdateInfo(latestVersion: '2.4.0', minVersion: '2.3.0');
      expect(info.statusOf('2.2.9'), AppUpdateStatus.required);
      expect(info.statusOf('2.2.0'), AppUpdateStatus.required);
    });

    test('requires min even when latest equals the running build', () {
      // minVersion can force an update independently of latest — the lever for
      // retiring a build that talks to a dead backend deployment.
      const info =
          AppUpdateInfo(latestVersion: '2.4.0', minVersion: '2.5.0');
      expect(info.statusOf('2.4.0'), AppUpdateStatus.required);
    });

    test('a missing latest means none even if min is set', () {
      // Without a latest to show in the banner, nothing to display — min alone
      // has nothing to compare the running version against for the advisory.
      const info = AppUpdateInfo(minVersion: '2.5.0');
      expect(info.statusOf('2.4.0'), AppUpdateStatus.none);
    });
  });

  group('AppUpdateInfo.isEmpty', () {
    test('empty when every field is null', () {
      expect(const AppUpdateInfo().isEmpty, isTrue);
      expect(AppUpdateInfo.none.isEmpty, isTrue);
    });

    test('non-empty once any field is set', () {
      expect(const AppUpdateInfo(latestVersion: '2.4.0').isEmpty, isFalse);
      expect(const AppUpdateInfo(minVersion: '2.3.0').isEmpty, isFalse);
      expect(
        const AppUpdateInfo(updateUrl: 'https://x').isEmpty,
        isFalse,
      );
    });
  });
}
