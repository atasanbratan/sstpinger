# SSTP Shield — Documentation

**SSTP Shield** (`sstpinger`) is a Flutter mobile VPN client for connecting to
[SSTP](https://en.wikipedia.org/wiki/Secure_Socket_Tunneling_Protocol) VPN
servers. It fetches a list of available VPN nodes from a remote registry,
lets the user measure latency (ping) to each node, and establishes a system
VPN tunnel through the [`sstp_flutter`](https://pub.dev/packages/sstp_flutter)
plugin.

> The app targets **Android and iOS** and renders portrait-only in a dark,
> cyan-accented theme branded as *"SSTP SHIELD — Your Secure Gateway to SSTP
> VPN Nodes."*

---

## Documentation index

| Document | Contents |
|----------|----------|
| [README.md](README.md) (this file) | Overview, features, quick start |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Layered MVVM structure, data flow, the two entrypoints |
| [DATA_LAYER.md](DATA_LAYER.md) | Model, API client, preferences service, repository |
| [UI_LAYER.md](UI_LAYER.md) | View model, screens, widgets, theme |
| [FEATURES.md](FEATURES.md) | End-to-end feature walkthroughs (onboarding, connect, ping, custom nodes) |

---

## Feature summary

- **Onboarding via activation code** — the user pastes a Base64 activation
  code from the clipboard; it decodes to a username plus a bundled server
  list.
- **Remote server registry** — servers are fetched from a Google Apps Script
  endpoint (which redirects, so the client follows the redirect hop manually).
- **Latency sorting ("Sort by Ping")** — opens a raw TCP socket to each
  server's `ip:port` and records the round-trip time in milliseconds, then
  sorts ascending. Runs in batches of 25 concurrent probes.
- **Server persistence & caching** — the last-known server list (including
  measured ping values) is cached in `SharedPreferences` so it is available
  offline / on next launch.
- **VPN connect / disconnect** — a single power button toggles the tunnel;
  live upload/download speed and total-traffic counters plus a session timer
  are shown while connected.
- **Custom node override** — an advanced toggle lets the user enter their own
  host, port, VPN username, and password instead of using a registry node.
- **Device identity** — a stable device ID (Google Advertising ID, or a
  generated UUID v4 fallback) is sent with each registry request.

---

## Tech stack

| Concern | Choice |
|---------|--------|
| Framework | Flutter (Dart SDK `^3.12.2`) |
| VPN engine | `sstp_flutter: ^1.3.0` |
| HTTP client | `dio: ^5.10.0` (with `http` also present) |
| Local storage | `shared_preferences: ^2.2.2` |
| Device ID | `advertising_id: ^2.4.0` |
| State management | `ChangeNotifier` + `ListenableBuilder` (no external state lib) |

See [pubspec.yaml](../pubspec.yaml) for the full dependency list.

---

## Quick start

```bash
flutter pub get       # install dependencies
flutter run           # run on a connected device / emulator
flutter analyze       # static analysis (see analysis_options.yaml)
flutter test          # run the widget test
```

The app entrypoint is [lib/main.dart](../lib/main.dart), which boots the
layered MVVM app in [lib/app/app.dart](../lib/app/app.dart).

> **Note:** [lib/main2.dart](../lib/main2.dart) is a **legacy, self-contained
> version** of the entire app in a single file. It is not the active
> entrypoint and is retained only for reference. See
> [ARCHITECTURE.md](ARCHITECTURE.md#the-two-entrypoints) for details.

---

## Project layout

```
lib/
├── main.dart                       # Active entrypoint → SstpVpnApp
├── main2.dart                      # Legacy monolithic version (reference only)
├── app/
│   └── app.dart                    # Root widget: builds VpnViewModel, MaterialApp
├── data/
│   ├── models/
│   │   └── vpn_server.dart         # VpnServer data model (JSON <-> Dart)
│   ├── services/
│   │   ├── vpn_api_client.dart     # Dio client for the server registry
│   │   └── preferences_service.dart# SharedPreferences + device-ID logic
│   └── repositories/
│       └── vpn_repository.dart     # Orchestrates API + preferences + cache
└── ui/
    ├── core/
    │   └── theme.dart              # AppTheme.darkTheme
    └── features/vpn/
        ├── view_models/
        │   └── vpn_view_model.dart # All screen state + connection logic
        └── views/
            ├── main_vpn_screen.dart
            ├── username_screen.dart
            └── widgets/
                ├── connection_status_panel.dart
                ├── connection_control_card.dart
                ├── server_list_view.dart
                ├── speed_indicator.dart
                ├── profile_settings_sheet.dart
                └── username_prompt.dart   # (unused legacy widget)
```
