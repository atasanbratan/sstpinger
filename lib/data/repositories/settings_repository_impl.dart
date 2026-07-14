import '../../domain/repositories/settings_repository.dart';
import '../datasources/preferences_data_source.dart';

/// Ping settings, backed by local preferences.
class SettingsRepositoryImpl implements SettingsRepository {
  final PreferencesDataSource _prefs;

  SettingsRepositoryImpl(this._prefs);

  @override
  Future<int> getPingTimeoutMs() => _prefs.getPingTimeoutMs();

  @override
  Future<int> getPingBatchSize() => _prefs.getPingBatchSize();

  @override
  Future<void> savePingSettings({
    required int timeoutMs,
    required int batchSize,
  }) => _prefs.savePingSettings(timeoutMs: timeoutMs, batchSize: batchSize);
}
