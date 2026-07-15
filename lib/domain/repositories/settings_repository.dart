/// Contract for user-tunable settings (currently the ping probe parameters).
abstract class SettingsRepository {
  Future<int> getPingTimeoutMs();

  Future<int> getPingBatchSize();

  Future<void> savePingSettings({required int timeoutMs, required int batchSize});
}
