import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:async/async.dart';

import '../../core/logging/file_logger.dart';
import '../../domain/repositories/proxy_sharing_controller.dart';

/// Minimal SOCKS5 server (RFC 1928) so other LAN devices can route TCP
/// traffic through this device's active VPN tunnel. No-auth only, `CONNECT`
/// only — no `BIND`/`UDP ASSOCIATE`. Once the tunnel is up, the OS default
/// route already carries this process's own outbound `Socket.connect` calls
/// over it, so relaying a client is just two-way byte piping — no manual
/// packet routing.
class Socks5ProxyDataSource implements ProxySharingController {
  /// Tried first since it's the conventional SOCKS5 port people expect; if
  /// something else already holds it, [start] falls back to port 0 (OS picks
  /// any free one) rather than failing.
  static const int _preferredPort = 1080;

  ServerSocket? _server;
  final List<Socket> _clientSockets = [];
  final StreamController<int> _clientCount = StreamController.broadcast();

  @override
  Stream<int> get connectedClients => _clientCount.stream;

  @override
  bool get isRunning => _server != null;

  @override
  int? get port => _server?.port;

  @override
  Future<int> start() async {
    if (_server case final running?) return running.port;
    try {
      _server =
          await ServerSocket.bind(InternetAddress.anyIPv4, _preferredPort);
    } on SocketException {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    }
    final bound = _server!.port;
    logLine('[socks5] listening on ${InternetAddress.anyIPv4.address}:$bound');
    _server!.listen(
      _handleClient,
      onError: (e) => logLine('[socks5] server error: $e'),
    );
    return bound;
  }

  @override
  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close();
    for (final socket in List<Socket>.from(_clientSockets)) {
      socket.destroy();
    }
    _clientSockets.clear();
  }

  @override
  void dispose() {
    stop();
    _clientCount.close();
  }

  Future<void> _handleClient(Socket client) async {
    final peer = '${client.remoteAddress.address}:${client.remotePort}';
    logLine('[socks5] client connected: $peer');
    _clientSockets.add(client);
    _clientCount.add(_clientSockets.length);
    try {
      await _relay(client);
    } catch (e, st) {
      logLine('[socks5] $peer handshake/relay failed: $e\n$st');
      client.destroy();
    } finally {
      logLine('[socks5] client disconnected: $peer');
      _clientSockets.remove(client);
      _clientCount.add(_clientSockets.length);
    }
  }

  Future<void> _relay(Socket client) async {
    final queue = StreamQueue<Uint8List>(client);
    final buffer = <int>[];

    Future<List<int>> readExact(int n) async {
      while (buffer.length < n) {
        if (!await queue.hasNext) {
          throw const SocketException('client closed during handshake');
        }
        buffer.addAll(await queue.next);
      }
      final result = buffer.sublist(0, n);
      buffer.removeRange(0, n);
      return result;
    }

    // Greeting: version(1) + nmethods(1) + methods(nmethods). We only offer
    // "no auth" regardless of what the client lists.
    final greeting = await readExact(2);
    if (greeting[0] != 0x05) throw const SocketException('not SOCKS5');
    await readExact(greeting[1]);
    client.add([0x05, 0x00]);

    // Request: version(1) cmd(1) rsv(1) atyp(1).
    final header = await readExact(4);
    final cmd = header[1];
    final addrType = header[3];

    late final String host;
    switch (addrType) {
      case 0x01: // IPv4
        host = (await readExact(4)).join('.');
      case 0x03: // domain name
        final len = (await readExact(1))[0];
        host = String.fromCharCodes(await readExact(len));
      case 0x04: // IPv6
        host = InternetAddress.fromRawAddress(
          Uint8List.fromList(await readExact(16)),
          type: InternetAddressType.IPv6,
        ).address;
      default:
        client.add(_reply(0x08)); // address type not supported
        return;
    }
    final portBytes = await readExact(2);
    final destPort = (portBytes[0] << 8) | portBytes[1];

    if (cmd != 0x01) {
      client.add(_reply(0x07)); // command not supported (CONNECT only)
      return;
    }

    final Socket dest;
    try {
      dest = await Socket.connect(
        host,
        destPort,
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      logLine('[socks5] connect to $host:$destPort failed: $e');
      client.add(_reply(0x05)); // connection refused
      return;
    }

    client.add(_reply(0x00)); // succeeded
    if (buffer.isNotEmpty) {
      dest.add(Uint8List.fromList(buffer));
      buffer.clear();
    }

    final done = Completer<void>();
    var pending = 2;
    void complete() {
      pending--;
      if (pending == 0 && !done.isCompleted) done.complete();
    }

    queue.rest.listen(
      dest.add,
      onDone: () {
        dest.destroy();
        complete();
      },
      onError: (_) {
        dest.destroy();
        complete();
      },
      cancelOnError: true,
    );
    dest.listen(
      client.add,
      onDone: () {
        client.destroy();
        complete();
      },
      onError: (_) {
        client.destroy();
        complete();
      },
      cancelOnError: true,
    );
    await done.future;
  }

  /// A fixed-length SOCKS5 reply with the given status code and an all-zero
  /// IPv4 bound address (unused by clients once the tunnel is established).
  List<int> _reply(int status) => [0x05, status, 0x00, 0x01, 0, 0, 0, 0, 0, 0];
}
