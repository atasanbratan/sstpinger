import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sstp_shield/domain/entities/tunnel_config.dart';
import 'package:sstp_shield/domain/entities/tunnel_status.dart';
import 'package:sstp_shield/domain/entities/tunnel_traffic.dart';
import 'package:sstp_shield/domain/entities/tunnel_update.dart';
import 'package:sstp_shield/domain/usecases/connect_tunnel.dart';
import 'package:sstp_shield/domain/usecases/disconnect_tunnel.dart';
import 'package:sstp_shield/domain/usecases/watch_tunnel.dart';
import 'package:sstp_shield/presentation/bloc/connection/connection_bloc.dart';

import 'support/mocks.dart';

void main() {
  late MockTunnelController tunnel;
  late StreamController<TunnelUpdate> updates;

  setUpAll(registerFallbacks);

  setUp(() {
    tunnel = MockTunnelController();
    updates = StreamController<TunnelUpdate>.broadcast();
    when(() => tunnel.updates).thenAnswer((_) => updates.stream);
    when(() => tunnel.lastStatus())
        .thenAnswer((_) async => TunnelStatus.disconnected);
    when(() => tunnel.requestPermission()).thenAnswer((_) async {});
    when(() => tunnel.connect(any())).thenAnswer((_) async {});
    when(() => tunnel.disconnect()).thenAnswer((_) async {});
  });

  tearDown(() => updates.close());

  ConnectionBloc build() => ConnectionBloc(
    connect: ConnectTunnel(tunnel),
    disconnect: DisconnectTunnel(tunnel),
    watch: WatchTunnel(tunnel),
  );

  const config = TunnelConfigStub();

  blocTest<ConnectionBloc, VpnConnectionState>(
    'maps a connected tunnel report to connected state with traffic',
    build: build,
    act: (bloc) async {
      // Let ConnectionStarted subscribe first.
      await Future<void>.delayed(Duration.zero);
      updates.add(
        const TunnelUpdate(
          status: TunnelStatus.connected,
          traffic: TunnelTraffic(downloadTraffic: 10),
          duration: Duration(seconds: 3),
        ),
      );
    },
    wait: const Duration(milliseconds: 50),
    verify: (bloc) {
      expect(bloc.state.status, TunnelStatus.connected);
      expect(bloc.state.isConnected, isTrue);
      expect(bloc.state.traffic?.downloadTraffic, 10);
      expect(bloc.state.duration, const Duration(seconds: 3));
    },
  );

  blocTest<ConnectionBloc, VpnConnectionState>(
    'a failure report goes back to disconnected and carries the error',
    build: build,
    act: (bloc) async {
      await Future<void>.delayed(Duration.zero);
      updates.add(
        const TunnelUpdate(
          status: TunnelStatus.disconnected,
          errorMessage: 'boom',
        ),
      );
    },
    wait: const Duration(milliseconds: 50),
    verify: (bloc) {
      expect(bloc.state.status, TunnelStatus.disconnected);
      expect(bloc.state.error?.message, 'boom');
    },
  );

  blocTest<ConnectionBloc, VpnConnectionState>(
    'ConnectRequested optimistically emits connecting and calls connect',
    build: build,
    act: (bloc) => bloc.add(ConnectRequested(config.value)),
    wait: const Duration(milliseconds: 50),
    verify: (bloc) {
      verify(() => tunnel.requestPermission()).called(1);
      verify(() => tunnel.connect(config.value)).called(1);
    },
  );

  blocTest<ConnectionBloc, VpnConnectionState>(
    'DisconnectRequested tears the tunnel down',
    build: build,
    act: (bloc) => bloc.add(const DisconnectRequested()),
    wait: const Duration(milliseconds: 50),
    verify: (_) => verify(() => tunnel.disconnect()).called(1),
  );
}

/// Small holder so the const config is easy to reference in verify().
class TunnelConfigStub {
  const TunnelConfigStub();
  TunnelConfig get value => const TunnelConfig(
    host: 'h',
    port: 443,
    username: 'u',
    password: 'p',
    label: 'l',
  );
}
