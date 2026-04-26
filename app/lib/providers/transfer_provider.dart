import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../services/local_storage_service.dart';
import '../services/smb_service.dart';

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
  final _storage = LocalStorageService();
  final _smbService = SmbService();

  TransfersNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final tasks = await _storage.getTransfers();
      state = AsyncValue.data(tasks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> cancel(String id) async {
    final tasks = state.valueOrNull ?? [];
    final updated = tasks.map((t) {
      if (t.id == id) {
        return TransferTask(
          id: t.id,
          serverId: t.serverId,
          transferType: t.transferType,
          remotePath: t.remotePath,
          localPath: t.localPath,
          totalBytes: t.totalBytes,
          writtenBytes: t.writtenBytes,
          progress: t.progress,
          status: TransferStatus.failed,
          errorMessage: 'Cancelled by user',
          createdAt: t.createdAt,
          updatedAt: DateTime.now(),
        );
      }
      return t;
    }).toList();
    await _storage.saveTransfers(updated);
    await load();
  }

  Future<void> pause(String id) async {
    final tasks = state.valueOrNull ?? [];
    final updated = tasks.map((t) {
      if (t.id == id) {
        return TransferTask(
          id: t.id,
          serverId: t.serverId,
          transferType: t.transferType,
          remotePath: t.remotePath,
          localPath: t.localPath,
          totalBytes: t.totalBytes,
          writtenBytes: t.writtenBytes,
          progress: t.progress,
          status: TransferStatus.paused,
          errorMessage: null,
          createdAt: t.createdAt,
          updatedAt: DateTime.now(),
        );
      }
      return t;
    }).toList();
    await _storage.saveTransfers(updated);
    await load();
  }

  Future<void> resume(String id) async {
    final tasks = state.valueOrNull ?? [];
    final updated = tasks.map((t) {
      if (t.id == id) {
        return TransferTask(
          id: t.id,
          serverId: t.serverId,
          transferType: t.transferType,
          remotePath: t.remotePath,
          localPath: t.localPath,
          totalBytes: t.totalBytes,
          writtenBytes: t.writtenBytes,
          progress: t.progress,
          status: TransferStatus.pending,
          errorMessage: null,
          createdAt: t.createdAt,
          updatedAt: DateTime.now(),
        );
      }
      return t;
    }).toList();
    await _storage.saveTransfers(updated);
    await load();
  }

  Future<void> clearCompleted() async {
    final tasks = state.valueOrNull ?? [];
    final active = tasks.where((t) => t.status != TransferStatus.done && t.status != TransferStatus.failed).toList();
    await _storage.saveTransfers(active);
    await load();
  }

  Future<BackupResult> backupPhotos(String serverId, List<String> localPaths, String remoteDir) async {
    final servers = await _storage.getSmbServers();
    final server = servers.firstWhere((s) => s.id == serverId);
    var successCount = 0;
    var failedCount = 0;

    for (final path in localPaths) {
      try {
        final file = File(path);
        final bytes = await file.readAsBytes();
        final fileName = path.split('/').last;
        final remotePath = '$remoteDir/$fileName';

        final taskId = DateTime.now().millisecondsSinceEpoch.toString();
        final task = TransferTask(
          id: taskId,
          serverId: serverId,
          transferType: TransferType.upload,
          remotePath: remotePath,
          localPath: path,
          totalBytes: bytes.length,
          writtenBytes: 0,
          progress: 0,
          status: TransferStatus.running,
          errorMessage: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final tasks = state.valueOrNull ?? [];
        await _storage.saveTransfers([...tasks, task]);
        await load();

        await _smbService.uploadFile(server, remotePath, bytes);

        final updatedTasks = state.valueOrNull ?? [];
        final updated = updatedTasks.map((t) {
          if (t.id == taskId) {
            return TransferTask(
              id: t.id,
              serverId: t.serverId,
              transferType: t.transferType,
              remotePath: t.remotePath,
              localPath: t.localPath,
              totalBytes: t.totalBytes,
              writtenBytes: t.totalBytes,
              progress: 1.0,
              status: TransferStatus.done,
              errorMessage: null,
              createdAt: t.createdAt,
              updatedAt: DateTime.now(),
            );
          }
          return t;
        }).toList();
        await _storage.saveTransfers(updated);
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