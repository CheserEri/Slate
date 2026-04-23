import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

enum NetworkStatus { online, offline, unknown }

final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, NetworkStatus>((ref) {
  return ConnectivityNotifier();
});

class ConnectivityNotifier extends StateNotifier<NetworkStatus> {
  Timer? _timer;

  ConnectivityNotifier() : super(NetworkStatus.unknown) {
    check();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => check());
  }

  Future<void> check() async {
    try {
      await ApiService().fetchHealth().timeout(const Duration(seconds: 3));
      if (state != NetworkStatus.online) state = NetworkStatus.online;
    } catch (_) {
      if (state != NetworkStatus.offline) state = NetworkStatus.offline;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class NetworkStatusBanner extends ConsumerWidget {
  const NetworkStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectivityProvider);
    if (status == NetworkStatus.online) return const SizedBox.shrink();
    return Container(
      color: Colors.red,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            status == NetworkStatus.offline ? '后端连接断开' : '检查后端连接...',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
