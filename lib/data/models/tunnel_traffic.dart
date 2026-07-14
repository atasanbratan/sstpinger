import 'package:equatable/equatable.dart';

/// Byte counters for the live tunnel.
///
/// Deliberately ours rather than `sstp_flutter`'s `ConnectionTraffic`: the VM and
/// the UI must not be typed against whichever plugin happens to be carrying the
/// tunnel, or they could never run on desktop. Field names match the old type, so
/// widgets reading `traffic?.downloadTraffic` needed no change.
///
/// Every field is nullable because "not reported" and "zero" are different
/// things: the desktop tunnel (`sstp_vpn_plugin`) exposes no byte counters at
/// all, so it reports null rather than a fake 0.
class TunnelTraffic extends Equatable {
  const TunnelTraffic({
    this.downloadTraffic,
    this.totalDownloadTraffic,
    this.uploadTraffic,
    this.totalUploadTraffic,
  });

  /// Current download rate, bytes/sec.
  final int? downloadTraffic;

  /// Bytes downloaded since the tunnel came up.
  final int? totalDownloadTraffic;

  /// Current upload rate, bytes/sec.
  final int? uploadTraffic;

  /// Bytes uploaded since the tunnel came up.
  final int? totalUploadTraffic;

  @override
  List<Object?> get props => [
    downloadTraffic,
    totalDownloadTraffic,
    uploadTraffic,
    totalUploadTraffic,
  ];
}
