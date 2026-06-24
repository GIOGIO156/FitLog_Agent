enum NetworkState { unknown, online, offline }

class NetworkStatus {
  const NetworkStatus({required this.state, this.lastCheckedAt});

  const NetworkStatus.unknown() : this(state: NetworkState.unknown);

  const NetworkStatus.online() : this(state: NetworkState.online);

  const NetworkStatus.offline() : this(state: NetworkState.offline);

  final NetworkState state;
  final DateTime? lastCheckedAt;

  bool get isOffline => state == NetworkState.offline;
}
