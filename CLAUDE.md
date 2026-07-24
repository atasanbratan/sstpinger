# CLAUDE.md

Guidance for working in this repository. Read this before writing code.

## What this app is

**SSTP Shield** is a Flutter VPN client. It fetches a server list from a backend
(`sstp_shield_server`, a Go service on Vercel), lets the user ping/sort them, and
brings up a system VPN tunnel. Auth is Google Sign-In with multi-session support
(up to a configurable device cap), with the original activation-code / username
model still supported in parallel for users who don't sign in — either identity
resolves to a subscription expiry. Google Sign-In is offered but never required:
the free trial and USDT-subscription paths stay fully anonymous-capable, since
that's the point of the crypto payment option.

**Tunnel backends.** Mobile uses the `sstp_flutter` plugin (SSTP only). Desktop
(Linux/Windows) uses `sstp_vpn_plugin` for SSTP and `softether_client` for
SoftEther, chosen by a protocol picker in the settings sheet; the choice lives on
`TunnelConfig.protocol` and is honoured in `DesktopTunnelDataSource`. SoftEther is
desktop-only — bundled on Linux (pkexec helper), and on Windows it drives the
user's officially-installed SoftEther VPN Client (`findWindowsInstall`). SoftEther
transport (NAT-T on/off + retry wait) is user-configurable and rides on
`TunnelConfig` too.

**Proxy sharing.** Once connected, `ConnectionBloc` starts a local SOCKS5
server ([lib/data/datasources/socks5_proxy_data_source.dart](lib/data/datasources/socks5_proxy_data_source.dart),
Linux/Windows/Android — no iOS implementation) so other LAN devices can route
through this device's tunnel. The listener picks its own port automatically
(tries 1080, falls back to whatever the OS hands out) — it's never
user-configurable, and the actual bound port only exists in
`VpnConnectionState.proxySharingPort` (nullable, live while running), not in
settings. On Android this depends on a routing fix in the `sstp_flutter` fork
(see the workspace root `CLAUDE.md`) — if proxy sharing looks broken there
(can't reach other devices, or the *VPN itself* loses internet after
connecting), check that repo's `IPTerminal.kt` before this one. Handshake/
relay failures are logged via `FileLogger`/`logLine()` (surfaced in Settings →
Diagnostic Logs) since they're otherwise invisible — extend that logging
rather than adding raw `print`s if you touch this file.

### One build, every onboarding path

There used to be separate `local` (activation code) and `foreign` (USDT
subscription) variants/entry points; they were merged into a single build —
`lib/main.dart` is now the only VPN-facing entry point, and
`OnboardingScreen` ([lib/presentation/screens/onboarding_screen.dart](lib/presentation/screens/onboarding_screen.dart))
offers every path (free trial, activation code, USDT subscription/BEP20+TRC20)
on one screen, backed by the `onboarding/` subfolder's `TrialCta`,
`ActivationSection`, `SubscriptionSection`. Which regional server pool to
fetch (the curated `ASTU` pool vs. the full list) is now a runtime settings
toggle (`VpnState.useCuratedRegion`), not a build-time distinction.

The admin/operator console is not part of this repository at all — it's its
own project (`sstp_shield_admin`), talking to the same backend, authenticated
as an allowlisted operator via Google Sign-In (desktop loopback OAuth, since
`google_sign_in` doesn't support Linux/Windows). This repo builds only the VPN
client: `--target lib/main.dart` — no `--flavor` flag; the last remaining
Android flavor was removed as pointless ceremony once the operator console
moved to its own repo.

### Backend

`sstp_shield_server` (sibling repo) — a Go service on Vercel backed by Neon
Postgres. Replaced the old Apps Script + Google Sheets backend (`../backend/`,
left in place but retired). See that repo's own README for the full API
surface and deploy setup; the pieces most relevant from this repo's side:

- [lib/core/config/backend_config.dart](lib/core/config/backend_config.dart) —
  `API_BASE_URL` and `GOOGLE_SERVER_CLIENT_ID` (the **Web** OAuth client, not
  the Android/iOS/Desktop one — its audience must match the backend's
  `GOOGLE_CLIENT_IDS`), both `--dart-define` compile-time constants. Google
  Sign-In compiles disabled (`isGoogleConfigured == false`) unless
  `GOOGLE_SERVER_CLIENT_ID` is passed — wired into `.github/workflows/release.yml`
  from the `GOOGLE_SERVER_CLIENT_ID` repo variable; pass it manually for local
  builds/`make run`.
- [lib/data/datasources/vpn_remote_data_source.dart](lib/data/datasources/vpn_remote_data_source.dart) —
  every client-facing endpoint accepts **either** a session `Authorization:
  Bearer` token (Google-signed-in) **or** legacy `username`+`deviceId` in the
  body, so both identity paths hit the same calls.
- [lib/data/datasources/google_auth_service.dart](lib/data/datasources/google_auth_service.dart) —
  wraps `google_sign_in` 7.x's singleton/`authenticate()` API.
  `isSupported` is false on desktop (`supportsAuthenticate()`) or when
  unconfigured, and `GoogleSignInSection`/`SessionsScreen` no-op accordingly.
- Client-side display values that must mirror the backend's config (price
  tiers, etc.) live in
  [lib/core/config/subscription_config.dart](lib/core/config/subscription_config.dart).

## Golden rules

1. **Keep files small.** A widget file over ~200 lines is a smell — extract
   sub-widgets. A `build` method over ~40 lines is a smell — split it. When a
   screen or sheet grows enough sub-widgets to matter, give it its own
   subfolder next to the original file (e.g. `profile_settings_sheet.dart` +
   `profile_settings/*.dart`, `server_list_view.dart` + `server_list/*.dart`,
   `main_vpn_screen.dart` + `main_vpn_screen/*.dart`) rather than flattening
   everything into `widgets/`. The original file stays as a thin orchestrator
   that assembles the extracted pieces and wires bloc state/events to them.
2. **One widget = one responsibility.** If a widget both lays out chrome and
   computes/formats data, split those concerns — pull the data
   transform (sorting, grouping, filtering, formatting) into a plain,
   testable function beside the widgets rather than leaving it in `build()`
   (e.g. `server_list/server_grouping.dart`).
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
                      SettingsRepository, TunnelController, PingService,
                      ProxySharingController
    usecases/         Single-responsibility operations (FetchServers, PingServers,
                      ConnectTunnel, ImportActivation, SignInWithGoogle, ...)
    failures/         ApiException, SubscriptionExpiredException (pure)
  data/               Implements the domain interfaces. No UI imports.
    dto/              JSON <-> entity mapping (VpnServerDto, UserSessionDto)
    datasources/      I/O: VpnRemoteDataSource (dio; dual Bearer/legacy auth),
                      GoogleAuthService, PreferencesDataSource, TcpPingService,
                      {Mobile,Desktop}TunnelDataSource, Socks5ProxyDataSource
    repositories/     *Impl classes; TunnelControllerImpl adapts callbacks->stream
  presentation/
    bloc/
      connection/     ConnectionBloc (+ event/state) — tunnel lifecycle +
                      proxy-sharing start/stop only
      vpn/            VpnBloc (+ event/state) — servers, ping, search, bookmarks,
                      onboarding, subscription, username, Google sign-in/sessions
    screens/          main_vpn_screen, activation_screen, subscription_screen,
                      settings/sessions_screen
    widgets/          Reusable presentational widgets
    theme/            AppColors, theme
  core/
    di/               injection.dart — the composition root (AppDependencies)
    config/, utils/   Cross-cutting helpers (incl. lan_ip.dart, file_logger.dart)
  app/                app.dart (providers + MaterialApp)
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
- Extracted leaf widgets take primitive values/entities + `VoidCallback`s or
  `ValueChanged<T>` constructor params (see `server_ping_action.dart`,
  `profile_settings/protocol_card.dart`) rather than reading a bloc
  themselves, so they stay independently testable. A widget that already owns
  the surrounding scroll/tab state (e.g. `ServerListView`,
  `ServersHeaderBlock`) may read/dispatch to a bloc directly instead of
  threading every event through its parent — match whichever pattern the
  file you're editing already uses.
- Repeated small chrome (a section caption, a card's rounded-corner
  background) belongs in its own tiny widget (`SettingsSectionHeader`,
  `SettingsCard`) the first time it's duplicated a third time, not
  re-inlined at each call site.

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
   (`profile_settings/*.dart`, `activation_screen.dart`) — surfaced again
   when `profile_settings_sheet.dart` and `server_list_view.dart` were split
   per the subfolder pattern above; the extracted files kept their original
   inline `Colors.white38`-style literals rather than migrating them.
2. Broaden the test suite — add widget tests and cover the tunnel data sources.
</content>
