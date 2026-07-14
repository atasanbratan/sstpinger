# Feature Walkthroughs

End-to-end traces of each user-facing feature, from UI tap down through the
view model and data layer. File references use the active (`main.dart`) code
path.

---

## Startup & offline-first load

**Entry:** `main()` → `SstpVpnApp` → `VpnViewModel._init()`.

```
_init():
  username  = repository.getUsername()           // SharedPreferences
  deviceId  = repository.getOrCreateDeviceId()    // Ad ID or UUID v4
  checkLastStatus()                               // last VPN state from plugin
  setupSstpListener()                             // subscribe to VPN events
  loadCachedServers()                             // show cached list immediately
  if username not empty: fetchServers()           // refresh from registry
  initialized = true → notifyListeners()
```

`_loadCachedServers()` reads `servers_with_ping` and populates the list **only
if** no servers are loaded yet — so a returning user sees their last list
(with ping values) instantly, before the network call returns. Until
`initialized` flips true, `MainVpnScreen` shows a spinner.

---

## Onboarding — activation-code import

Shown when `username.isEmpty` (→ `UsernameScreen`).

1. User taps **"Import activation code"**.
2. `_pasteFromClipboard()` reads the clipboard and, if non-empty, calls
   `viewModel.importActivationCode(text)`.
3. `VpnViewModel.importActivationCode` → `repository.importActivationCode`:
   - `base64Decode` → `utf8.decode` → `jsonDecode` yields
     `{ username, data: [ …server json… ] }`;
   - maps `data` to `VpnServer`s;
   - saves the username and the server list (updates cache).
4. Back in the view model: `username` and `servers` are refreshed, the first
   server is auto-selected, `notifyListeners()` fires, and
   `sortServersByPing()` runs so the freshly imported list is immediately
   ordered by latency.

Because `username` is now set, `MainVpnScreen` swaps `UsernameScreen` for the
dashboard on the next rebuild.

> The legacy typed-username onboarding (enter a name → fetch from registry)
> exists only in `main2.dart` and the unused `UsernamePrompt` widget.

---

## Fetching the server registry

**Trigger:** startup (if username set), after saving a username, or the AppBar
**Refresh** button.

`VpnViewModel.fetchServers()`:
1. bail if `username` or `deviceId` is empty;
2. set `isFetchingServers = true`, clear error, notify (list shows spinner);
3. `repository.fetchVpnServers()` →
   `VpnApiClient.fetchVpnServers(username, deviceId)` performs the
   POST → redirect-hop → GET → JSON parse described in
   [DATA_LAYER.md](DATA_LAYER.md#vpnapiclient--network); the repository
   persists the result to the cache;
4. auto-select the first server if none selected;
5. on error, route the message to `onErrorMessage` (snackbar);
6. `finally`: clear `isFetchingServers`, notify.

---

## Sort by ping (latency measurement)

**Trigger:** AppBar **Sort by Ping** (speed icon). Disabled while `isPinging`.

`VpnViewModel.sortServersByPing()`:
1. guard against re-entry / empty list; set `isPinging = true`, notify (AppBar
   shows a spinner).
2. Process servers in **batches of 25**, each batch probed concurrently with
   `Future.wait`.
3. `_pingServer(server)` opens a raw TCP `Socket.connect(ip, port,
   timeout: 3s)`, measures elapsed ms with a `Stopwatch`, closes the socket,
   and returns the value — or `null` on any failure/timeout.
4. Sort ascending by `ping` (nulls sort last via a `999999` sentinel).
5. `isPinging = false`, notify, then persist the list with its new ping values
   (`repository.saveServersWithPing`).

The measured values render as color-coded badges in `ServerListView`
(green `< 80`, orange `< 150`, red otherwise).

> This is a **TCP-connect latency**, not an ICMP ping — it measures time to
> establish a socket to the VPN port, which is a good proxy for reachability
> and responsiveness.

---

## Connecting & disconnecting

**Trigger:** tapping the power button (`ConnectionStatusPanel`) →
`viewModel.toggleVpnConnection()`.

### If already connected/connecting → disconnect
Calls `_sstpFlutter.disconnect()`; errors surface via `onErrorMessage`.

### Otherwise → connect
1. **Validate target.** If not in custom mode and no server is selected →
   error snackbar and abort. Resolve the target from either the custom
   controllers or the selected server:
   - host = custom host **or** `selectedServer.ip`
   - port = custom port (parsed, default `443`) **or** `selectedServer.port`
   - username/password = custom values **or** fixed `vpn` / `vpn`
   - abort if host is empty.
2. Set status to `Connecting`, notify.
3. `_sstpFlutter.takePermission()` — request the OS VPN permission.
4. Build an `SSTPServer` config:
   - **Android:** `verifyHostName/verifySSLCert/useTrustedCert = false`,
     `sslVersion = TLSv1.3`, a persistent disconnect notification.
   - **iOS:** `enablePAP` + `enableMSCHAP2` on, `enableTLS`/`enableCHAP` off.
5. `saveServerData(server: …)` then `connectVpn()`.
6. On any exception: reset status to `Disconnected`, notify, surface the error.

Actual state transitions arrive **asynchronously** through the plugin listener
(next section), not from this method's return.

---

## Live status & traffic (the SSTP listener)

`_setupSstpListener()` subscribes to `sstp_flutter` callbacks and maps them to
state + `notifyListeners()`:

| Callback | Effect |
|----------|--------|
| `onConnectedResult(traffic, duration)` | status → `Connected`; store `traffic` + `duration`; trigger one-shot background sync (below) |
| `onConnectingResult()` | status → `Connecting` |
| `onDisconnectedResult()` | status → `Disconnected`; clear traffic/duration |
| `onError()` | status → `Disconnected`; clear traffic; snackbar "Connection failed. Please choose another server." |

While connected, `ConnectionControlCard` renders the download/upload speed and
totals from `traffic`, and `ConnectionStatusPanel` shows the running
`duration` timer.

### Background server sync
On the **first** successful connection (`_hasSyncedServers` is `initial` or
`error`), the view model schedules — after a 1-second delay — a
`_refreshServers()` call, which runs `repository.fetchServersAndMerge()` to
non-destructively merge any new registry nodes into the cached list without
losing existing ping data. The sync status flips to `synced` or `error`
accordingly, and it won't run again for the session. This lets the client
top up its server list over the freshly established tunnel.

---

## Search / filter

The dashboard search field calls `viewModel.updateSearchQuery(q)` on every
keystroke. `getFilteredServers()` returns the full list when the query is
blank, otherwise a case-insensitive match against **country**, **hostname**,
or **IP**. The header count and `ServerListView` both read the filtered list.

---

## Profile & settings

AppBar **Settings** opens `ProfileSettingsSheet` (a modal bottom sheet):

- **Username** — shown with an edit button that closes the sheet and opens the
  `_promptEditUsername` dialog; saving calls `viewModel.saveUsername`, which
  persists and re-fetches.
- **Device Advertising ID** — shown with a copy-to-clipboard button.
- **Use custom node settings** — a switch (`setUseCustomConfig`) that reveals
  host / port / VPN user / VPN password fields bound to the view model's
  controllers. When enabled, `toggleVpnConnection` uses these values instead of
  a selected registry node, and the control card shows the `CUSTOM` badge.

---

## Custom node override

With the custom switch on:
- `ConnectionControlCard` shows 🔧 + "Custom Node Configuration" +
  `host:port` and a `CUSTOM` badge.
- Connecting uses `customHostController` / `customPortController` /
  `customUsernameController` / `customPasswordController` (defaults
  `443` / `vpn` / `vpn`).
- Selecting any server from the list turns custom mode **off** again
  (`selectServer` sets `useCustomConfig = false`).
