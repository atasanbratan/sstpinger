/// Display-side configuration for the foreign variant's crypto subscription.
///
/// These values are shown to the user (which address to pay, which plans
/// exist). They MUST mirror the backend `Config.js`, which is the source of
/// truth that actually verifies payments on-chain and grants time. Changing a
/// price here without changing it there only changes the label, not what the
/// user gets.
class SubscriptionNetwork {
  /// Backend network id sent with the payment (`bep20` | `trc20`).
  final String id;
  final String label;
  final String chain;
  final String walletAddress;

  const SubscriptionNetwork({
    required this.id,
    required this.label,
    required this.chain,
    required this.walletAddress,
  });
}

class SubscriptionPlan {
  final int priceUsdt;
  final int months;

  const SubscriptionPlan({required this.priceUsdt, required this.months});
}

class SubscriptionConfig {
  SubscriptionConfig._();

  /// Free trial length, must match CONFIG.TRIAL_DAYS in Config.js.
  static const int trialDays = 3;

  // FILL IN: must match CONFIG.BEP20_WALLET / CONFIG.TRC20_WALLET in Config.js.
  static const List<SubscriptionNetwork> networks = [
    SubscriptionNetwork(
      id: 'bep20',
      label: 'USDT · BEP20',
      chain: 'BNB Smart Chain',
      walletAddress: '0x801e0e72e550e1d493096e3e9da65d77fa3cac07',
    ),
    SubscriptionNetwork(
      id: 'trc20',
      label: 'USDT · TRC20',
      chain: 'Tron',
      walletAddress: 'TFcZs5uyyhcfDf4Jd2oGtJFm4CNQT7gota',
    ),
  ];

  // Must match CONFIG.PRICE_TIERS in Config.js. Single plan: 1 month.
  static const List<SubscriptionPlan> plans = [
    SubscriptionPlan(priceUsdt: 3, months: 1),
  ];
}
