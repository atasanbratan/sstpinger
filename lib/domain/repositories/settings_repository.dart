import '../entities/tunnel_protocol.dart';

/// Contract for user-tunable settings (ping probe parameters and the
/// auto-reconnection policy).
abstract class SettingsRepository {
  Future<int> getPingTimeoutMs();

  Future<int> getPingBatchSize();

  Future<void> savePingSettings({required int timeoutMs, required int batchSize});

  /// How many times to retry after an unexpected drop (0 disables reconnection).
  Future<int> getReconnectRetryCount();

  /// How long to wait between reconnection attempts, in seconds.
  Future<int> getReconnectRetryIntervalSeconds();

  Future<void> saveReconnectSettings({
    required int retryCount,
    required int retryIntervalSeconds,
  });

  /// How many servers each fetch requests (clamped to [50, 5000]).
  Future<int> getFetchServerCount();

  Future<void> saveFetchServerCount(int count);

  /// SoftEther transport: whether to try NAT-T disabled (direct TCP) first.
  Future<bool> getSoftEtherDisableNatT();

  /// How long to wait for a SoftEther session before switching transport.
  Future<int> getSoftEtherNatTRetryWaitSeconds();

  Future<void> saveSoftEtherNatTSettings({
    required bool disableNatT,
    required int retryWaitSeconds,
  });

  /// Servers-tab layout: true = flat list, false = grouped by country.
  Future<bool> getServersFlatView();

  Future<void> saveServersFlatView(bool flat);

  /// The selected tunnel protocol.
  Future<TunnelProtocol> getProtocol();

  Future<void> saveProtocol(TunnelProtocol protocol);
}
