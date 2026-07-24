<div align="center">

# SSTP Shield

**A cross-platform SSTP VPN client — Android, iOS, Linux and Windows — built with Flutter.**

[![build](https://github.com/sstp-pinger/sstp_shield/actions/workflows/release.yml/badge.svg)](https://github.com/sstp-pinger/sstp_shield/actions/workflows/release.yml)
[![latest release](https://img.shields.io/github/v/release/sstp-pinger/sstp_shield?sort=semver)](https://github.com/sstp-pinger/sstp_shield/releases/latest)
[![platforms](https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Linux%20%7C%20Windows-blue)](#platform-support)

</div>

---

SSTP Shield connects to [SSTP](https://en.wikipedia.org/wiki/Secure_Socket_Tunneling_Protocol)
VPN servers. It fetches a server registry from a backend, lets you measure latency to
each node and sort by it, and brings up a system VPN tunnel.

On **mobile** it tunnels through the third-party [`sstp_flutter`](https://pub.dev/packages/sstp_flutter)
plugin. On **desktop** it runs on our own pure-Dart SSTP + PPP stack —
[`sstp_vpn_plugin`](https://github.com/sstp-pinger/sstp_vpn_plugin), built on
[`sstp_client`](https://github.com/sstp-pinger/sstp_client) — reaching `/dev/net/tun`
on Linux and Wintun on Windows. The handshake and the packet loop run in a dedicated
isolate, off the UI thread.

**Desktop also speaks SoftEther.** A protocol picker (Settings → Protocol) lets you
choose SSTP or SoftEther's SSL-VPN, which reaches the same VPN Gate relays and often
connects where SSTP won't. SoftEther is driven through
[`softether_client`](https://github.com/sstp-pinger/softether_client), a pure-Dart
wrapper around the official SoftEther `vpnclient`/`vpncmd`. On **Linux** the client is
bundled; on **Windows** you must install the official
[SoftEther VPN Client](https://www.softether-download.com/) yourself (its signed adapter
driver can only be staged by SoftEther's own installer) — the app detects and drives it.
Mobile is SSTP-only.

## Platform support

| Platform | Tunnel | Status |
|---|---|---|
| Android | `sstp_flutter` (VpnService) | Supported — signed APKs in [Releases](https://github.com/sstp-pinger/sstp_shield/releases) |
| iOS | `sstp_flutter` (NEVPNManager) | Builds from the same codebase; not distributed here, least exercised |
| Linux (x64, GTK) | `sstp_vpn_plugin` (`/dev/net/tun`) · **SoftEther** (bundled) | Supported — needs a one-time capability setup |
| Windows (10/11, x64) | `sstp_vpn_plugin` (Wintun) · **SoftEther** (official client) | Supported — requests Administrator at launch |

On desktop the tunnel protocol (SSTP or SoftEther) is chosen in Settings; mobile is
SSTP-only. macOS is deliberately **not** supported: `sstp_vpn_plugin` excludes its utun backend,
because that backend has never been proven against a live server.

## Features

- **Onboarding** — an activation code, a USDT subscription with on-chain
  verification, or a one-time free trial, all offered on one screen.
- **Server registry** — nodes fetched from the backend and cached for offline use.
- **Latency sorting** — raw TCP probes to each node's `ip:port`, run in configurable
  concurrent batches, with a live progress counter.
- **Bookmarks** — pin nodes; they survive a server refetch even if the backend drops them.
- **Custom nodes** — connect to an arbitrary host, port and credentials.
- **Protocol choice (desktop)** — SSTP or SoftEther, per your network.
- **Auto-reconnection** — configurable retry count and interval on an unexpected drop.
- **SoftEther transport tuning (desktop)** — toggle NAT-T (direct TCP vs UDP
  acceleration) and set how long to wait before the app retries the other transport.
- **Live tunnel stats** — connection duration, and on mobile, throughput counters.

## Install

Grab a build from the [**latest release**](https://github.com/sstp-pinger/sstp_shield/releases/latest).

**Android** — install `sstp-shield.apk` (universal) or the per-ABI
`sstp-shield-{abi}.apk` for a smaller download. You will need to allow installs
from unknown sources.

**Windows** — unzip `sstp-shield-windows-x64.zip` and run `sstp_shield.exe`. It requests
Administrator at launch (a UAC prompt): creating the Wintun adapter and changing routes
both require it. Keep `wintun.dll` beside the `.exe`. To use the **SoftEther** protocol,
first install the official [SoftEther VPN Client](https://www.softether-download.com/) —
the app detects it automatically. SSTP needs no extra software.

**Linux** — creating a TUN device needs `CAP_NET_ADMIN`, **not** root. Do **not** run it
with `sudo`. Once, with `gcc`, `libcap` and `patchelf` installed:

```sh
tar xzf sstp-shield-linux-x64.tar.gz && cd sstp-shield-linux-x64
./tool/setup_privilege.sh ./sstp_shield   # grants the capability; asks for sudo once
./sstp-vpn                                 # run THIS, not ./sstp_shield directly
```

Re-run the setup script after replacing the bundle with a newer build. What the three
steps do, and why each is necessary, is documented at the top of the script.

## Build from source

Requires the Flutter SDK (stable channel).

```sh
git clone https://github.com/sstp-pinger/sstp_shield.git
cd sstp_shield
flutter pub get

# Android
flutter build apk --release --target lib/main.dart

# Linux — needs: ninja-build libgtk-3-dev clang cmake pkg-config
flutter build linux --release --target lib/main.dart

# Windows — CMake fetches and bundles the signed wintun.dll automatically
flutter build windows --release --target lib/main.dart
```

### One build, every onboarding path

A single entry point (`lib/main.dart`) offers activation code, USDT
subscription (BEP20/TRC20), and a one-time free trial all on one onboarding
screen — no separate variant builds.

The operator console lives in a separate project, so it is neither shipped to end users
nor published here.

### Release signing

Android release builds read `android/key.properties` (gitignored). Copy
[`android/key.properties.example`](android/key.properties.example) and fill it in.
Without it, the release build **falls back to debug keys and says so** — such an APK is
not distributable. CI reconstructs the keystore from repository secrets, and refuses to
publish a tagged release unless real signing is configured.

## Architecture

Clean Architecture with [Bloc](https://bloclibrary.dev). Dependencies point **inward**:

```
presentation  ──▶   domain   ◀──  data
```

`domain/` is pure Dart — no Flutter, no `dio`, no `shared_preferences`. It owns the
entities, the repository **interfaces**, and the use cases. `data/` implements those
interfaces; `presentation/` depends only on the domain. Nothing in the UI knows which
plugin is carrying the tunnel, or that there is more than one.

```
lib/
  domain/          entities · repository INTERFACES · use cases · failures
  data/            DTOs · datasources (dio, prefs, ping, tunnel) · repository impls
  presentation/    blocs · screens · widgets · theme
  core/            di (composition root) · config · utils
  app/             app root
```

**Two blocs**, provided above `MaterialApp` so pushed routes and modal sheets can read them:

- **`ConnectionBloc`** — the tunnel lifecycle, and nothing else.
- **`VpnBloc`** — the cohesive rest: servers, ping, search, bookmarks, selection,
  onboarding, subscription, username.

They are coordinated at the screen with a `BlocListener` (connecting triggers a server
refresh; the ping guard reads connection status). The split stops there deliberately:
the feature's state is too interdependent to carve up further without more cross-bloc
wiring than it would buy.

The platform tunnel is chosen once, in `data/`, behind the domain's `TunnelController`
interface — so no `Platform.isX` check leaks above the data layer.

## Testing

```sh
flutter analyze   # must be clean
flutter test      # bloc + use-case suite
```

The suite uses [`bloc_test`](https://pub.dev/packages/bloc_test) and
[`mocktail`](https://pub.dev/packages/mocktail), mocking the repository interfaces and
driving the real use cases — so it covers the domain and presentation layers together,
with no network and no tunnel. It exercises server fetch, the subscription-expired gate,
ping-and-sort, bookmarks, activation import, and tunnel status mapping.

## Limitations

- **IPv6 leaks outside the tunnel.** Full-tunnel mode overrides only the IPv4 default
  route, and the session negotiates IPv4 (IPCP) only. On a dual-stack host, IPv6 traffic
  keeps egressing over the normal connection, **outside the VPN**. If you read "full
  tunnel" as meaning *all* traffic, disable IPv6 for the duration — and do not rely on
  this for anonymity yet.
- **Desktop is not a turnkey install.** Linux needs the one-time capability setup;
  Windows shows a UAC prompt on every launch. There is no installer.
- **SoftEther is desktop-only**, and on Windows it needs the official SoftEther VPN
  Client installed separately — its signed adapter driver can't be bundled.
- **Desktop is full-tunnel only** — split routing is not exposed in the UI.
- **Auth:** CHAP / MSCHAPv2 only.
- Server certificates are not verified by default, because the public nodes are
  self-signed.

## Related projects

| Project | What it is |
|---|---|
| [`sstp_client`](https://github.com/sstp-pinger/sstp_client) | Pure-Dart SSTP + PPP protocol stack and tunnel backends |
| [`sstp_vpn_plugin`](https://github.com/sstp-pinger/sstp_vpn_plugin) | Flutter plugin wrapping it for Linux + Windows |
| [`softether_client`](https://github.com/sstp-pinger/softether_client) | Pure-Dart driver for the official SoftEther VPN Client (desktop) |

## License

Not yet licensed. Until a licence is added, default copyright applies: no rights to use,
copy, modify or distribute are granted.
