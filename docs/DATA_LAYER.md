# Data Layer

The data layer lives under [lib/data/](../lib/data/) and is the only part of
the app that performs I/O. It is split into a **model**, two **services**, and
a **repository** that orchestrates them.

```
VpnRepository
 ├── VpnApiClient        (network — Dio → Google Apps Script registry)
 └── PreferencesService  (storage — SharedPreferences + device identity)
      └── VpnServer      (model — JSON <-> Dart)
```

---

## `VpnServer` — model
[lib/data/models/vpn_server.dart](../lib/data/models/vpn_server.dart)

Plain data class describing one VPN node.

| Field | Type | Source JSON | Notes |
|-------|------|-------------|-------|
| `id` | `int` | `id` | Server identity used for selection comparison |
| `hostname` | `String` | `hostname` | Display name |
| `ip` | `String` | `ip` | Used for connecting **and** for TCP ping |
| `port` | `int` | `port` | Defaults to `443` |
| `key` | `String` | `key` | Opaque server key |
| `sessions` | `int` | `sessions` | Current session count (shown in list) |
| `info`, `info2` | `String` | `info`, `info2` | Extra metadata (mostly unused in UI) |
| `country` | `String` | `location.country` | Full country name |
| `countryShort` | `String` | `location.short` | 2-letter code → flag emoji |
| `locationName` | `String` | `location.name` | Location label |
| `ping` | `int?` | `ping` | **Mutable**; latency in ms, `null` until measured |

Key points:
- `ping` is the only **non-final** field — it is mutated in place by the ping
  routine, then persisted.
- `fromJson` is **null-safe**: every field falls back to a sensible default,
  and the nested `location` object is coalesced to `{}` if missing.
- `toJson` re-nests the location fields and **omits `ping` when null**
  (`if (ping != null) 'ping': ping`), keeping cached payloads clean.

```dart
factory VpnServer.fromJson(Map<String, dynamic> json) {
  final loc = json['location'] as Map<String, dynamic>? ?? {};
  return VpnServer(
    id: json['id'] as int? ?? 0,
    ...
    country: loc['country'] as String? ?? '',
    ping: json['ping'] as int?,
  );
}
```

---

## `VpnApiClient` — network
[lib/data/services/vpn_api_client.dart](../lib/data/services/vpn_api_client.dart)

A thin `Dio` wrapper around a single endpoint: a **Google Apps Script**
web app that returns the server registry.

```dart
static const String _url =
  'https://script.google.com/macros/s/AKfycby.../exec';
```

### `fetchVpnServers({username, deviceId}) → Future<List<VpnServer>>`

The interesting part is **manual redirect handling**. Google Apps Script
responds to the initial POST with a redirect (302 / an HTML page with an
`href`) to an "echo" URL that must be fetched with a GET. Dio is configured to
**not** auto-follow redirects so the client can perform the second hop itself:

1. **POST** to `_url` with the payload as both query parameters and JSON body.
   - `followRedirects: false`
   - `validateStatus: (s) => s < 500` (treat 3xx/4xx as non-throwing)
   - `connectTimeout: 10s`
2. **Find the redirect URL**, in priority order:
   - the `location` response header, if present; else
   - a regex `href="([^"]+)"` scraped from the HTML body, with `&amp;`
     decoded back to `&`.
3. **GET** the redirect URL to complete the handshake; that response replaces
   the original.
4. **Parse**: on HTTP 200, decode JSON. If `success == true`, map
   `data[]` → `List<VpnServer>`. Otherwise throw `Exception(decoded['error'])`.
   Non-200 throws `Exception('API responded with status: …')`.

The client is constructor-injectable (`VpnApiClient({Dio? dio})`) for testing.

> The active client in `main.dart` uses **Dio**. The legacy `main2.dart` has a
> commented-out `http` POST alongside its Dio version — the `http` package is
> still a dependency but no longer used by the live code path.

---

## `PreferencesService` — storage & identity
[lib/data/services/preferences_service.dart](../lib/data/services/preferences_service.dart)

Wraps `SharedPreferences`. Three storage keys:

| Constant | Key | Stores |
|----------|-----|--------|
| `_keyUsername` | `username` | The user's registry username |
| `_keyDeviceId` | `device_id` | Stable device identifier |
| — | `servers_with_ping` | JSON-encoded cached server list |

### Username
- `getUsername()` → stored value or `''`.
- `saveUsername(name)` → stores `name.trim()`.

### Device identity — `getOrCreateDeviceId()`
Returns a stable ID, computing it once and caching it:

1. If `device_id` is already stored, return it.
2. Otherwise call `_generateOrFetchDeviceId`:
   - Try the **Google Advertising ID** via `AdvertisingId.id(true)`. Accept it
     unless it is null, empty, or the all-zero opt-out value
     (`00000000-0000-0000-0000-000000000000`).
   - **Fallback:** generate an [RFC 4122 UUID v4](https://www.rfc-editor.org/rfc/rfc4122)
     from 16 random bytes (version nibble set to `4`, variant bits set to
     `10`), formatted `8-4-4-4-12` hex.
   - Persist whichever value was produced.

### Server cache
- `saveServersWithPing(servers)` — JSON-encodes `servers.map(toJson)` under
  `servers_with_ping`.
- `loadServersWithPing()` — decodes that string back into `List<VpnServer>`,
  or `[]` if absent. This is what enables **offline-first** startup.

---

## `VpnRepository` — orchestration
[lib/data/repositories/vpn_repository.dart](../lib/data/repositories/vpn_repository.dart)

The façade the view model uses. Holds an in-memory `_cachedServers` list
(exposed read-only via `cachedServers`) and both services (both
constructor-injectable, defaulting to real implementations).

### Pass-through methods
- `getUsername()`, `saveUsername()`, `getOrCreateDeviceId()`,
  `loadServersWithPing()` — delegate straight to `PreferencesService`.
- `saveServersWithPing(servers)` — persists **and** updates the in-memory
  cache.

### `fetchVpnServers() → Future<List<VpnServer>>`
The primary fetch. Loads username + device ID; if either is empty it clears
the cache and returns `[]`. Otherwise it calls the API client, persists the
result (`saveServersWithPing`), updates `_cachedServers`, and returns it.

### `fetchServersAndMerge() → Future<List<VpnServer>>`
A **non-destructive** refresh used after a successful VPN connection (see
[FEATURES.md](FEATURES.md#background-server-sync)). It:
1. loads the cached (old) servers;
2. fetches the latest list from the API;
3. starts from the old list and appends only servers **not already present**,
   deduplicating on `(ip, port)`;
4. persists and returns the merged list.

This preserves previously measured `ping` values and any older nodes that
dropped off the latest registry response.

### `importActivationCode(base64) → Future<void>`
Onboarding path. Decodes a Base64 string → UTF-8 → JSON containing
`{ username, data: [...] }`, maps `data` to `VpnServer`s, then saves the
username and the server list (updating the cache). See
[FEATURES.md](FEATURES.md#onboarding--activation-code-import).

> A `saveServerPing` helper is present but **commented out**; per-server ping
> saves are currently done by re-saving the whole list.

---

## Security notes

These are hard-coded in source and worth flagging for any production hardening:

- **Registry URL** is embedded as a constant in `VpnApiClient` (and duplicated
  in `main2.dart`).
- **Default custom-node credentials** are `vpn` / `vpn`, and registry nodes
  connect with a fixed username/password of `vpn`/`vpn` (see the view model's
  `toggleVpnConnection`).
- **TLS verification is disabled** for the tunnel on Android
  (`verifyHostName: false`, `verifySSLCert: false`, `useTrustedCert: false`).
  This is typical for these community SSTP nodes but means the transport is not
  certificate-authenticated.

Per [AGENTS.md](../AGENTS.md), secrets should move to configuration rather than
living in source; this is a candidate for a future change.
