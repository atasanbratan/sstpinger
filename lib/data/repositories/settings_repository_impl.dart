import '../../domain/entities/tunnel_protocol.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/preferences_data_source.dart';

/// Ping and reconnection settings, backed by local preferences.
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

  @override
  Future<int> getReconnectRetryCount() => _prefs.getReconnectRetryCount();

  @override
  Future<int> getReconnectRetryIntervalSeconds() =>
      _prefs.getReconnectRetryIntervalSec();

  @override
  Future<void> saveReconnectSettings({
    required int retryCount,
    required int retryIntervalSeconds,
  }) => _prefs.saveReconnectSettings(
    retryCount: retryCount,
    retryIntervalSec: retryIntervalSeconds,
  );

  @override
  Future<int> getFetchServerCount() => _prefs.getFetchServerCount();

  @override
  Future<void> saveFetchServerCount(int count) =>
      _prefs.setFetchServerCount(count);

  @override
  Future<bool> getSoftEtherDisableNatT() => _prefs.getSoftEtherDisableNatT();

  @override
  Future<int> getSoftEtherNatTRetryWaitSeconds() =>
      _prefs.getSoftEtherNatTRetryWaitSec();

  @override
  Future<void> saveSoftEtherNatTSettings({
    required bool disableNatT,
    required int retryWaitSeconds,
  }) => _prefs.saveSoftEtherNatTSettings(
    disableNatT: disableNatT,
    retryWaitSec: retryWaitSeconds,
  );

  @override
  Future<bool> getServersFlatView() => _prefs.getServersFlatView();

  @override
  Future<void> saveServersFlatView(bool flat) =>
      _prefs.saveServersFlatView(flat);

  @override
  Future<TunnelProtocol> getProtocol() => _prefs.getProtocol();

  @override
  Future<void> saveProtocol(TunnelProtocol protocol) =>
      _prefs.saveProtocol(protocol);
}
