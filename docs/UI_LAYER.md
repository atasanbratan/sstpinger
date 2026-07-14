# UI Layer

The UI lives under [lib/ui/](../lib/ui/) and is organized into a shared
**core** (theme) and a feature module (`features/vpn/`) containing the view
model, screens, and widgets.

```
ui/
├── core/theme.dart                 # AppTheme.darkTheme
└── features/vpn/
    ├── view_models/vpn_view_model.dart
    └── views/
        ├── main_vpn_screen.dart    # dashboard (stateful shell)
        ├── username_screen.dart    # onboarding (activation-code paste)
        └── widgets/
            ├── connection_status_panel.dart
            ├── connection_control_card.dart
            ├── server_list_view.dart
            ├── speed_indicator.dart
            ├── profile_settings_sheet.dart
            └── username_prompt.dart   # legacy, unused
```

All widgets are **stateless** and driven by the `VpnViewModel`; the only
stateful pieces are `MainVpnScreen` and `UsernameScreen` (which manage
`BuildContext`-bound concerns like snackbars and dialogs).

---

## Theme
[lib/ui/core/theme.dart](../lib/ui/core/theme.dart)

`AppTheme.darkTheme` defines the app-wide dark look:

| Token | Value | Meaning |
|-------|-------|---------|
| `scaffoldBackgroundColor` | `#0B0F19` | Near-black app background |
| `cardColor` / `surface` | `#151D30` | Card / panel surfaces |
| `primary` | `#00D2FF` | Cyan accent (buttons, highlights, selection) |
| `secondary` | `#9D4EDD` | Purple accent (upload speed, device ID) |
| Font | `Outfit` | Applied to title/body text styles |

The same palette recurs as inline `Color(0xFF…)` literals throughout the
widgets (status greens/ambers, list-row surfaces, etc.).

---

## `VpnViewModel`
[lib/ui/features/vpn/view_models/vpn_view_model.dart](../lib/ui/features/vpn/view_models/vpn_view_model.dart)

A `ChangeNotifier` holding **all** screen state and logic. Constructed with a
`VpnRepository` and kicks off `_init()` immediately.

### Supporting types
- `SSTPConnectionStatusKeys` — string constants matching the plugin's status
  strings: `Connected`, `Connecting`, `Disconnected`, `Disconnecting`.
- `SERVER_SYNC_STATUS` — enum (`initial`, `loading`, `synced`, `error`)
  tracking the one-shot background merge after connecting.

### State (read-only getters)
`isPinging`, `initialized`, `username`, `deviceId`, `servers`,
`isFetchingServers`, `serverFetchError`, `searchQuery`, `connectionStatus`,
`traffic`, `duration`, `selectedServer`, `useCustomConfig`.

### Public text controllers (for the custom-node form)
`customHostController`, `customPortController` (default `443`),
`customUsernameController` (default `vpn`), `customPasswordController`
(default `vpn`). Disposed in `dispose()`.

### Lifecycle — `_init()`
Loads username + device ID, checks the last VPN status, wires up the
`sstp_flutter` listener, loads cached servers (offline-first), then fetches
fresh servers if a username exists. Sets `initialized = true`.

### Key methods
| Method | Purpose |
|--------|---------|
| `fetchServers()` | Fetch registry servers; auto-selects the first server; errors go to `onErrorMessage` |
| `saveUsername(name)` | Persist username then re-fetch |
| `updateSearchQuery(q)` | Update the list filter |
| `selectServer(s)` | Select a node (and clear custom-config mode) |
| `setUseCustomConfig(b)` | Toggle custom-node mode |
| `getFilteredServers()` | Filter servers by country / hostname / IP |
| `toggleVpnConnection()` | Connect or disconnect (see [FEATURES.md](FEATURES.md#connecting--disconnecting)) |
| `sortServersByPing()` | Batch-ping all servers, sort ascending, persist |
| `importActivationCode(b64)` | Onboard from an activation code, then sort by ping |

`onErrorMessage` is the `BuildContext`-free channel used to raise snackbars in
the UI. See [ARCHITECTURE.md](ARCHITECTURE.md#error-surfacing).

---

## `MainVpnScreen`
[lib/ui/features/vpn/views/main_vpn_screen.dart](../lib/ui/features/vpn/views/main_vpn_screen.dart)

The stateful shell for the whole dashboard. It:

- assigns `viewModel.onErrorMessage = _showSnackBar` in `initState` (and clears
  it in `dispose`);
- wraps everything in a `ListenableBuilder` on the view model, so it rebuilds
  on every `notifyListeners()`;
- renders one of three states:
  1. **`!initialized`** → centered cyan spinner;
  2. **`username.isEmpty`** → `UsernameScreen`;
  3. otherwise → the **dashboard**.

### Dashboard composition (top to bottom)
1. **AppBar** — shield title + three actions: *Sort by Ping* (spinner while
   `isPinging`), *Refresh server list*, *Settings / Profile*.
2. **`ConnectionStatusPanel`** — the big power button + status + timer.
3. **`ConnectionControlCard`** — selected-node summary + live speeds.
4. **"VPN SERVERS" header** with an available-count.
5. **Search field** (`_buildSearchField`) — filters via
   `updateSearchQuery`.
6. **`ServerListView`** — the node list.

### Local helpers (also passed down to children)
- `_getFlagEmoji(code)` — turns a 2-letter country code into a 🇺🇸-style flag
  emoji via Unicode regional-indicator math; returns 🌐 for invalid codes.
- `_formatDuration(d)` — `HH:MM:SS`.
- `_showSnackBar`, `_showProfileAndSettingsModal`, `_promptEditUsername` —
  `BuildContext`-bound UI (snackbar, bottom sheet, dialog).

> **Note:** `RefreshIndicator.onRefresh` is currently a no-op
> (`() async {}`); pull-to-refresh does not re-fetch (the wiring is commented
> out).

---

## `UsernameScreen`
[lib/ui/features/vpn/views/username_screen.dart](../lib/ui/features/vpn/views/username_screen.dart)

The onboarding screen shown while no username is set. Branded hero (VPN lock
icon, "SSTP SHIELD" title) above a card with a single **"Import activation
code"** tap target. Tapping it:

1. reads the clipboard (`Clipboard.getData`);
2. if non-empty, passes the text to `viewModel.importActivationCode`.

The older typed-username flow is present but fully commented out. See
[FEATURES.md](FEATURES.md#onboarding--activation-code-import).

---

## Widgets

### `ConnectionStatusPanel`
[connection_status_panel.dart](../lib/ui/features/vpn/views/widgets/connection_status_panel.dart) —
The tappable power button. Three concentric circles (outer ring, glow ring,
core) whose color reflects state: grey (disconnected), amber `#F59E0B`
(connecting, with a larger glow), emerald `#10B981` (connected). Below it: the
status label and a session timer (`formatDuration(duration)` when connected,
else `00:00:00`). Tapping calls `onToggle`.

### `ConnectionControlCard`
[connection_control_card.dart](../lib/ui/features/vpn/views/widgets/connection_control_card.dart) —
Summarizes the active target. Shows the flag/🔧 icon, the country/hostname (or
custom host:port), and a `API NODES` / `CUSTOM` badge. When **connected**, it
reveals a divider and two `SpeedIndicator`s (download in cyan, upload in
purple). Contains its own byte-formatting helpers:
- `_formatSpeed(bytesPerSecond)` → e.g. `1.5 MB/s`;
- `_formatTraffic(bytes)` → e.g. `250.0 MB`.

Both use a log-base-1024 index into a suffix table.

### `SpeedIndicator`
[speed_indicator.dart](../lib/ui/features/vpn/views/widgets/speed_indicator.dart) —
Small presentational row: icon + label + current speed + `Total: …`. Purely a
layout of the strings passed in.

### `ServerListView`
[server_list_view.dart](../lib/ui/features/vpn/views/widgets/server_list_view.dart) —
Renders the server list with four states:
1. **fetching** → spinner;
2. **`serverFetchError != null`** → red error card with **RETRY**
   (`fetchServers`) and **CHANGE USERNAME** (`onEditUsername`);
3. **empty filtered list** → "No servers match your search filter.";
4. **list** → a non-scrolling `ListView.builder` (it lives inside the outer
   `SingleChildScrollView`).

Each row shows the flag, country, hostname, `ip:port`, session count, and a
color-coded ping badge — **green `< 80 ms`**, **orange `< 150 ms`**, **red
otherwise**, or `--` if unmeasured. The selected row is highlighted with a cyan
border and a check icon; others show a chevron. Tapping calls
`viewModel.selectServer`.

### `ProfileSettingsSheet`
[profile_settings_sheet.dart](../lib/ui/features/vpn/views/widgets/profile_settings_sheet.dart) —
The **Settings / Profile** bottom sheet. Shows the username (with an edit
button → `onEditUsername`) and the device advertising ID (with a copy-to-
clipboard button). Below, a **"USE CUSTOM NODE SETTINGS"** switch
(`onUseCustomConfigChanged`) that, when on, reveals the host / port / VPN user
/ VPN password fields bound to the view model's controllers. Uses a
`StatefulBuilder` so the switch updates the sheet without rebuilding the whole
screen.

### `UsernamePrompt` (legacy, unused)
[username_prompt.dart](../lib/ui/features/vpn/views/widgets/username_prompt.dart) —
A typed-username onboarding card taking a `controller` + `onSubmit`. It is
**not referenced anywhere**; onboarding now uses the activation-code paste
flow in `UsernameScreen`. Retained for reference / potential removal.
