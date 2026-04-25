import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class BackupResult {
  final int successCount;
  final int failedCount;

  const BackupResult({required this.successCount, required this.failedCount});

  bool get allSucceeded => failedCount == 0;
  bool get allFailed => successCount == 0 && failedCount > 0;
}

final transfersProvider = StateNotifierProvider<TransfersNotifier, AsyncValue<List<TransferTask>>>(
  (ref) => TransfersNotifier(),
);

class TransfersNotifier extends StateNotifier<AsyncValue<List<TransferTask>>> {
  Timer? _timer;

  TransfersNotifier() : super(const AsyncValue.loading()) {
    load();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final tasks = await ApiService().fetchTransfers();
      state = AsyncValue.data(tasks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> cancel(String id) async {
    await ApiService().cancelTransfer(id);
    await load();
  }

  Future<void> pause(String id) async {
    await ApiService().pauseTransfer(id);
    await load();
  }

  Future<void> resume(String id) async {
    await ApiService().resumeTransfer(id);
    await load();
  }

  Future<void> clearCompleted() async {
    final tasks = state.valueOrNull ?? [];
    final active = tasks.where((t) => t.status != TransferStatus.done && t.status != TransferStatus.failed).toList();
    state = AsyncValue.data(active);
  }

  Future<BackupResult> backupPhotos(String serverId, List<String> localPaths, String remoteDir) async {
    var successCount = 0;
    var failedCount = 0;

    for (final path in localPaths) {
      try {
        await ApiService().uploadSmbFile(serverId, path, remoteDir: remoteDir);
        successCount += 1;
      } catch (_) {
        failedCount += 1;
      }
    }

    await load();
    return BackupResult(successCount: successCount, failedCount: failedCount);
  }
}

final activeTransferCountProvider = Provider<int>((ref) {
  final tasks = ref.watch(transfersProvider);
  return tasks.valueOrNull?.where((t) => t.status == TransferStatus.running).length ?? 0;
});
