# CLAUDE.md

Guidance for working in this repository. Read this before writing code.

## What this app is

**SSTP Shield** is a Flutter VPN client. It fetches a server list from a backend
(a Google Apps Script endpoint), lets the user ping/sort them, and brings up a
system VPN tunnel. Auth is an activation-code / username model with a
subscription expiry.

**Tunnel backends.** Mobile uses the `sstp_flutter` plugin (SSTP only). Desktop
(Linux/Windows) uses `sstp_vpn_plugin` for SSTP and `softether_client` for
SoftEther, chosen by a protocol picker in the settings sheet; the choice lives on
`TunnelConfig.protocol` and is honoured in `DesktopTunnelDataSource`. SoftEther is
desktop-only — bundled on Linux (pkexec helper), and on Windows it drives the
user's officially-installed SoftEther VPN Client (`findWindowsInstall`). SoftEther
transport (NAT-T on/off + retry wait) is user-configurable and rides on
`TunnelConfig` too.

### Product variants (one codebase, three entry points)

Selected by the entry point via `AppVariant` ([lib/app/app_variant.dart](lib/app/app_variant.dart)):

| Variant | Entry point | Onboarding | Identity | Build |
|---------|-------------|-----------|----------|-------|
| local   | `lib/main.dart`         | activation code                 | shared (`standard` flavor) | `--flavor standard --target lib/main.dart` |
| foreign | `lib/main_foreign.dart` | USDT subscription (BEP20/TRC20) | shared (`standard` flavor) | `--flavor standard --target lib/main_foreign.dart` |
| admin   | `lib/main_admin.dart`   | admin token                     | separate app id (`admin` flavor) | `--flavor admin --target lib/main_admin.dart` |

- local + foreign share `SstpVpnApp`; only the onboarding gate differs
  (`MainVpnScreen` picks `ActivationScreen` vs `SubscriptionScreen` by variant).
- admin is a separate root (`AdminApp`) — no VPN tunnel, just user/server
  management. Lives under `lib/ui/features/admin/`.

### Backend (Google Apps Script)

Source is a `clasp` project at `/home/ata/apps/clasp/SSTPinger/`:
`Code.js` (router + auth + activation), `Payments.js` (foreign on-chain
verification), `Admin.js` (admin actions), `Config.js` (**secrets to fill in**:
wallet addresses, Etherscan/TronScan keys, price tiers, `ADMIN_TOKEN`).
Client-side display values that must mirror `Config.js` live in
[lib/core/config/subscription_config.dart](lib/core/config/subscription_config.dart).

## Golden rules

1. **Keep files small.** A widget file over ~200 lines is a smell — extract
   sub-widgets. A `build` method over ~40 lines is a smell — split it.
2. **One widget = one responsibility.** If a widget both lays out chrome and
   computes/formats data, split those concerns.
3. **No magic literals.** Colors come from `AppColors`, never `Color(0xFF...)`
   inline. Formatting comes from `lib/core/utils/`, never re-implemented inline.
4. **Never pass helper functions through constructors** (e.g. a `getFlagEmoji`
   or `buildX` callback). Import the shared util instead. Callbacks are for
   *events* (`onTap`, `onChanged`), not for shared logic.
5. **Blocs own state and business logic; widgets are dumb.** Widgets read from
   bloc state (`BlocBuilder`/`context.watch`) and dispatch events
   (`context.read<Bloc>().add(...)`). They must not talk to repositories,
   data sources, sockets, or `shared_preferences` directly.
6. **Delete dead code** rather than commenting it out. Git is the history.

## Architecture (Clean Architecture + Bloc)

Dependencies point inward: `presentation` → `domain` ← `data`. The domain owns
the contracts (entities + repository interfaces + use cases); `data` implements
them; `presentation` depends only on the domain.

```
lib/
  domain/           Pure Dart. No Flutter, dio, or shared_preferences.
    entities/         Value types (Equatable): VpnServer, Subscription,
                      TunnelStatus, TunnelTraffic, TunnelConfig, TunnelUpdate...
    repositories/     INTERFACES: VpnServerRepository, SubscriptionRepository,
                      SettingsRepository, TunnelController, PingService
    usecases/         Single-responsibility operations (FetchServers, PingServers,
                      ConnectTunnel, ImportActivation, ...)
    failures/         ApiException, SubscriptionExpiredException (pure)
  data/               Implements the domain interfaces. No UI imports.
    dto/              JSON <-> entity mapping (VpnServerDto)
    datasources/      I/O: VpnRemoteDataSource (dio), PreferencesDataSource,
                      TcpPingService, {Mobile,Desktop}TunnelDataSource
    repositories/     *Impl classes; TunnelControllerImpl adapts callbacks->stream
  presentation/
    bloc/
      connection/     ConnectionBloc (+ event/state) — tunnel lifecycle only
      vpn/            VpnBloc (+ event/state) — servers, ping, search, bookmarks,
                      onboarding, subscription, username
    screens/          main_vpn_screen, activation_screen, subscription_screen
    widgets/          Reusable presentational widgets
    theme/            AppColors, theme
  core/
    di/               injection.dart — the composition root (AppDependencies)
    config/, utils/   Cross-cutting helpers
  app/                app.dart (providers + MaterialApp), app_variant.dart
```

### Dependency direction (must not be violated)

`presentation` → `domain` ← `data`. Blocs depend on **use cases** for real
operations and on repository **interfaces** for trivial reads; never on `data`
implementations, dio, or `shared_preferences`. `domain/**` imports nothing from
`data/**`, `presentation/**`, or `package:flutter/material.dart`. `data/**` never
imports `presentation/**`.

## State management (Bloc)

- Two blocs, provided above `MaterialApp` in [lib/app/app.dart](lib/app/app.dart)
  via `MultiBlocProvider` (so pushed routes and modal sheets can read them):
  - **ConnectionBloc** — tunnel lifecycle (`VpnConnectionState`). Its own state
    class is named `VpnConnectionState` to avoid clashing with Flutter's
    `ConnectionState`.
  - **VpnBloc** — the cohesive feature: servers, ping, search, bookmarks,
    onboarding, subscription, username.
- The two are coordinated at the screen: a `BlocListener` refreshes servers when
  ConnectionBloc reports `connected`; the ping guard reads ConnectionBloc status.
- Events are `sealed` classes; state is an immutable Equatable with `copyWith`.
  One-shot signals (`VpnMessage`, `VpnActionResult`, `ConnectionError`) carry an
  incrementing `id` so identical values still register as a change; screens react
  via `BlocListener` with a `listenWhen` id comparison.
- The composition root wires the object graph once in
  [lib/core/di/injection.dart](lib/core/di/injection.dart); `AppDependencies`
  builds the blocs and disposes the `TunnelController`.
- Transient UI input that isn't app state (the custom-config text fields) stays
  in the screen's `State`, not in a bloc.

## Design system

- **Colors:** [lib/ui/core/app_colors.dart](lib/ui/core/app_colors.dart). Add a
  named constant there and reference it; never inline a hex color in a widget.
- **Theme:** [lib/presentation/theme/theme.dart](lib/presentation/theme/theme.dart)
  wires `AppColors` into `ThemeData`. Prefer `Theme.of(context)` text styles.
- **Font:** `Outfit` (see `pubspec.yaml` assets / theme `textTheme`).

## Utilities

Pure, testable functions live in [lib/core/utils/](lib/core/utils/):

- `formatters.dart` — `Formatters.duration`, `.date`, `.bytes`, `.speed`.
- `country_flag.dart` — `countryFlagEmoji(countryShort)`.

Add new shared logic here instead of duplicating it in a widget.

## Entities, DTOs, and models

- Domain **entities** are immutable, extend `Equatable`, and know nothing about
  JSON (see [lib/domain/entities/vpn_server.dart](lib/domain/entities/vpn_server.dart)).
- JSON mapping lives in **DTOs** in the data layer
  ([lib/data/dto/vpn_server_dto.dart](lib/data/dto/vpn_server_dto.dart)), not on
  the entity.
- Provide `copyWith` for controlled mutation and list all fields in `props`.

## Conventions

- Prefer `const` constructors wherever possible.
- Name event callbacks `onX`; name booleans `isX`/`hasX`.
- Keep `import` groups ordered: dart, package, then relative.
- User-facing messages ride on one-shot state fields (`VpnMessage`,
  `ConnectionError`) and are turned into SnackBars by a `BlocListener` in
  `main_vpn_screen.dart` — widgets deep in the tree do not build SnackBars.

## Verifying changes

- `flutter analyze` must be clean before considering a change done.
- `flutter test` — the bloc suite (`test/vpn_bloc_test.dart`,
  `test/connection_bloc_test.dart`) exercises the domain + bloc logic with
  `bloc_test` + `mocktail`, mocking the repository interfaces. Add to it when you
  add behavior; prefer testing blocs/use cases over widgets.
- For a real end-to-end check on Linux desktop, build, run
  `~/Projects/sstp_vpn_plugin/tool/setup_privilege.sh <bundle>/sstp_shield`, then
  launch the generated `sstp-vpn` script and confirm the egress IP changes.

## Cleanup backlog (in priority order)

1. Finish migrating remaining inline colors to `AppColors`
   (`profile_settings_sheet.dart`, `activation_screen.dart`).
2. Split the large widgets into smaller files:
   `profile_settings_sheet.dart` and `server_list_view.dart`
   (dialogs/sheets belong in their own files).
3. Broaden the test suite — add widget tests and cover the tunnel data sources.
</content>
