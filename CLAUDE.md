# CLAUDE.md

Guidance for working in this repository. Read this before writing code.

## What this app is

**SSTP Shield** is a Flutter VPN client. It fetches a list of SSTP servers from a
backend (a Google Apps Script endpoint), lets the user ping/sort them, and
connects through the `sstp_flutter` plugin. Auth is an activation-code /
username model with a subscription expiry.

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
5. **The View Model owns state and business logic; widgets are dumb.** Widgets
   read from the VM and call VM methods. They must not talk to repositories,
   services, sockets, or `shared_preferences` directly.
6. **Delete dead code** rather than commenting it out. Git is the history.

## Architecture (clean-ish, layered)

```
lib/
  app/            App root widget + wiring (MaterialApp, VM construction)
  core/           Cross-cutting, framework-agnostic helpers
    utils/          Pure functions: formatters, country flags, ...
  data/           The data layer — no Flutter/UI imports
    models/         Immutable value types (Equatable). e.g. VpnServer
    services/       I/O: API client (Dio), preferences, device id
    repositories/   Orchestrate services; the ONLY thing the VM talks to
  ui/
    core/           Design system: theme, AppColors
    features/
      vpn/
        view_models/  ChangeNotifier VMs — state + business logic
        views/        Screens
          widgets/    Reusable presentational widgets for the feature
```

### Dependency direction (must not be violated)

`ui` → `data/repositories` → `data/services` → `data/models`
UI never imports `services` directly; it goes through the repository via the VM.
`data/**` must never import from `ui/**` or `package:flutter/material.dart`
(models/services are UI-agnostic).

## State management

- Single `VpnViewModel extends ChangeNotifier`, constructed in
  [lib/app/app.dart](lib/app/app.dart) and passed to the screen.
- Widgets rebuild via `ListenableBuilder`.
- The VM exposes **read-only getters** for state and **methods** for actions.
  Never expose mutable fields.
- After mutating state, call `notifyListeners()` exactly once per logical change.

> If the widget tree grows, migrate to `provider`/`Provider.of` rather than
> threading the VM through every constructor. Do not hand-roll InheritedWidgets.

## Design system

- **Colors:** [lib/ui/core/app_colors.dart](lib/ui/core/app_colors.dart). Add a
  named constant there and reference it; never inline a hex color in a widget.
- **Theme:** [lib/ui/core/theme.dart](lib/ui/core/theme.dart) wires `AppColors`
  into `ThemeData`. Prefer `Theme.of(context)` text styles where practical.
- **Font:** `Outfit` (see `pubspec.yaml` assets / theme `textTheme`).

## Utilities

Pure, testable functions live in [lib/core/utils/](lib/core/utils/):

- `formatters.dart` — `Formatters.duration`, `.date`, `.bytes`, `.speed`.
- `country_flag.dart` — `countryFlagEmoji(countryShort)`.

Add new shared logic here instead of duplicating it in a widget.

## Models

- Value types are **immutable** and extend `Equatable` (see
  [lib/data/models/vpn_server.dart](lib/data/models/vpn_server.dart)).
- Provide `fromJson`/`toJson` and a `copyWith` for controlled mutation.
- List these fields in `props` so equality/`==` works.

## Conventions

- Prefer `const` constructors wherever possible.
- Name event callbacks `onX`; name booleans `isX`/`hasX`.
- Keep `import` groups ordered: dart, package, then relative.
- User-facing error strings go through `onErrorMessage` on the VM, surfaced by
  the screen as a SnackBar — widgets deep in the tree should not build SnackBars.

## Verifying changes

- `flutter analyze` must be clean before considering a change done.
- `flutter test` for logic (utils, VM, repository) — prefer testing pure
  functions and VM behavior over widgets.
- There is currently **no test suite**; adding one for `core/utils` and the VM
  is the highest-value next step.

## Cleanup backlog (in priority order)

1. Finish migrating remaining inline colors to `AppColors`
   (`profile_settings_sheet.dart`, `activation_screen.dart`).
2. Split the large widgets into smaller files:
   `profile_settings_sheet.dart` (~500 lines) and `main_vpn_screen.dart`
   (dialogs/sheets belong in their own files).
3. Extract the connect/config-building logic out of
   `VpnViewModel.toggleVpnConnection` into a small `SstpConnectionService`.
4. Introduce `provider` for DI instead of constructor threading.
5. Add unit tests for `core/utils` and `VpnViewModel`.
</content>
