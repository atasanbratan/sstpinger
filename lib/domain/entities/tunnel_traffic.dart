import 'package:equatable/equatable.dart';

/// Byte counters for the live tunnel.
///
/// Every field is nullable because "not reported" and "zero" differ: the desktop
/// tunnel exposes no byte counters, so it reports null rather than a fake 0. The
/// UI renders null as 0.
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
