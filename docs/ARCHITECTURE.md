# Architecture

SSTP Shield follows a **layered MVVM** architecture. State and business logic
live in a single `ChangeNotifier` view model; the UI is a tree of stateless
widgets that rebuild via `ListenableBuilder`; and all I/O (network, storage,
device identity) is isolated behind a repository.

```
┌─────────────────────────────────────────────────────────────┐
│                          UI LAYER                            │
│  MainVpnScreen / UsernameScreen  ── ListenableBuilder ──┐    │
│  widgets/ (stateless, driven by view-model getters)     │    │
└───────────────────────────┬─────────────────────────────┘    │
                            │ reads getters / calls methods    │
                            ▼         ▲ notifyListeners()       │
┌─────────────────────────────────────────────────────────────┐
│                     VIEW-MODEL LAYER                         │
│  VpnViewModel (ChangeNotifier)                              │
│   • holds all screen state       • ping / sort logic        │
│   • owns SstpFlutter listener     • connect / disconnect     │
└───────────────────────────┬─────────────────────────────────┘
                            │ awaits Futures
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                        DATA LAYER                           │
│  VpnRepository ── orchestrates ──┬── VpnApiClient (Dio)      │
│   • in-memory cache              └── PreferencesService      │
│                                       (SharedPreferences +   │
│                                        Advertising ID)       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
        VpnServer model  ·  sstp_flutter plugin (native VPN)
```

---

## Layer responsibilities

### UI layer — `lib/ui/features/vpn/views/`
Pure presentation. Every view/widget takes the `VpnViewModel` (or specific
callbacks) as a constructor argument, reads its getters to render, and calls
its methods on user interaction. Widgets never touch the network or storage
directly. See [UI_LAYER.md](UI_LAYER.md).

### View-model layer — `lib/ui/features/vpn/view_models/vpn_view_model.dart`
The single source of truth for screen state. It:
- exposes read-only getters for every piece of state (`servers`,
  `connectionStatus`, `traffic`, `isPinging`, …);
- calls `notifyListeners()` after every mutation to trigger UI rebuilds;
- owns the `sstp_flutter` result listener (connection status + traffic);
- implements ping measurement, batching, sorting, and the connect/disconnect
  flow;
- delegates all persistence and network work to `VpnRepository`.

It communicates UI-facing errors through an `onErrorMessage` callback rather
than depending on `BuildContext`, keeping it framework-light.

### Data layer — `lib/data/`
- **`VpnRepository`** — the single entry point the view model talks to. It
  coordinates the API client, the preferences service, and an in-memory
  `_cachedServers` list. It also implements merge logic (`fetchServersAndMerge`)
  and activation-code import.
- **`VpnApiClient`** — wraps `Dio` and knows how to talk to the Google Apps
  Script registry, including the manual redirect-hop handling.
- **`PreferencesService`** — wraps `SharedPreferences` for username, device
  ID, and the cached server list; also contains the Advertising-ID / UUID
  device-identity logic.
- **`VpnServer`** — the plain data model with `fromJson` / `toJson`.

See [DATA_LAYER.md](DATA_LAYER.md).

---

## State management pattern

The app uses **no external state-management package**. The pattern is:

1. `SstpVpnApp` (in [app/app.dart](../lib/app/app.dart)) creates the
   `VpnViewModel` once in `initState` and disposes it in `dispose`.
2. The view model is passed down the widget tree by constructor injection.
3. `MainVpnScreen` wraps its body in a `ListenableBuilder` listening to the
   view model, so any `notifyListeners()` call rebuilds the screen.
4. Child widgets are `StatelessWidget`s that read view-model getters.

```dart
// app/app.dart
_viewModel = VpnViewModel(repository: VpnRepository());
...
home: MainVpnScreen(viewModel: _viewModel),

// main_vpn_screen.dart
return ListenableBuilder(
  listenable: widget.viewModel,
  builder: (context, _) { ... },
);
```

### Error surfacing
Because the view model has no `BuildContext`, it exposes a
`void Function(String)? onErrorMessage` hook. `MainVpnScreen` assigns its
`_showSnackBar` method to this hook in `initState` (and clears it in
`dispose`). The view model calls `onErrorMessage?.call(...)` for connection
errors, empty-field validation, and fetch failures.

---

## Application flow (high level)

```
main() ─► SstpVpnApp ─► VpnViewModel._init()
                            │
                            ├─ load username + device ID (SharedPreferences)
                            ├─ check last VPN status (sstp_flutter)
                            ├─ set up VPN result listener
                            ├─ load cached servers (offline-first)
                            └─ if username set → fetchServers() from registry
                            
MainVpnScreen rebuilds on each notifyListeners():
   • not initialized      → loading spinner
   • username empty        → UsernameScreen (paste activation code)
   • otherwise             → main dashboard (status, control card, server list)
```

See [FEATURES.md](FEATURES.md) for detailed per-feature walkthroughs.

---

## The two entrypoints

The repository contains **two parallel implementations** of the app:

| File | Role | Architecture |
|------|------|--------------|
| [lib/main.dart](../lib/main.dart) | **Active entrypoint** | Layered MVVM (`app/`, `data/`, `ui/`) |
| [lib/main2.dart](../lib/main2.dart) | **Legacy / reference** | Monolithic — the entire app (model, screen, networking, state) in a single `_MainVpnScreenState` |

`main2.dart` was the original single-file prototype. The code was later
refactored into the layered structure driven by `main.dart`. The two are **not
identical in behavior** — notably:

- `main2.dart` onboards with a **typed username** (`_buildUsernameScreen`),
  while the current `UsernameScreen` onboards by **pasting a Base64 activation
  code** (`importActivationCode`).
- `main2.dart` has no server caching, no merge-on-connect refresh, and no
  activation-code import.

`main2.dart` is retained for reference only; new work should target the
layered code reachable from `main.dart`. Treat `main2.dart` and the unused
[widgets/username_prompt.dart](../lib/ui/features/vpn/views/widgets/username_prompt.dart)
as legacy that could be removed in a cleanup pass.

---

## Known rough edges

These are documented so future contributors know they are intentional
observations, not hidden requirements:

- **Debug `print` statements** remain in `VpnViewModel` (`"H" * 20`, `"A" * 20`)
  and `VpnRepository` (`"Merged" * 4`) — leftover tracing that should be
  removed or replaced with `debugPrint`.
- **Pull-to-refresh is a no-op** on the main screen (`onRefresh: () async {}`);
  the commented-out intent was to call `fetchServers`.
- **Hard-coded secrets/URL** — the registry endpoint and the default custom
  credentials (`vpn`/`vpn`) are hard-coded. See
  [DATA_LAYER.md](DATA_LAYER.md#security-notes).
- **`serverFetchError` is effectively unused** — `fetchServers` routes errors
  to `onErrorMessage` instead of setting `serverFetchError`, so the error card
  in `ServerListView` rarely appears from that path.
