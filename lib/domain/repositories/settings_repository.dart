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
}
