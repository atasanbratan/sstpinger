import 'package:equatable/equatable.dart';

/// The user's subscription window, as last reported by the backend and cached
/// locally. [expireTime] is when access lapses; [lastFetch] is when the server
/// list was last refreshed (used to decide whether a refresh is due).
class Subscription extends Equatable {
  final DateTime? expireTime;
  final DateTime? lastFetch;

  const Subscription({this.expireTime, this.lastFetch});

  @override
  List<Object?> get props => [expireTime, lastFetch];
}
