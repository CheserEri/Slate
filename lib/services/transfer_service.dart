import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

enum TransferState { idle, running, paused }

class TransferTaskUi {
  final String id;
  final String serverId;
  final TransferType transferType;
  final String remotePath;
  final String localPath;
  final int totalBytes;
  final int writtenBytes;
  final TransferStatus status;
  final String? errorMessage;

  TransferTaskUi({
    required this.id,
    required this.serverId,
    required this.transferType,
    required this.remotePath,
    required this.localPath,
    required this.totalBytes,
    required this.writtenBytes,
    required this.status,
    this.errorMessage,
  });

  double get progress => totalBytes > 0 ? writtenBytes / totalBytes : 0;

  String get progressText => '${(progress * 100).toStringAsFixed(1)}%';

  String get sizeText {
    final downloaded = _formatBytes(writtenBytes);
    final total = _formatBytes(totalBytes);
    return '$downloaded / $total';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class TransferService {
  final Ref ref;

  TransferService(this.ref);

  final List<TransferTaskUi> _tasks = [];
  final Map<String, double> _progressMap = {};

  List<TransferTaskUi> get tasks => List.unmodifiable(_tasks);

  Stream<TransferTaskUi> startDownload({
    required String id,
    required String serverId,
    required String remotePath,
    required String localPath,
    required int totalBytes,
  }) async* {
    final task = TransferTaskUi(
      id: id,
      serverId: serverId,
      transferType: TransferType.download,
      remotePath: remotePath,
      localPath: localPath,
      totalBytes: totalBytes,
      writtenBytes: 0,
      status: TransferStatus.running,
    );

    _tasks.add(task);

    yield task;

    for (int written = 0; written <= totalBytes; written += totalBytes ~/ 20) {
      await Future.delayed(const Duration(milliseconds: 100));

      final index = _tasks.indexWhere((t) => t.id == id);
      if (index >= 0) {
        _tasks[index] = TransferTaskUi(
          id: id,
          serverId: serverId,
          transferType: TransferType.download,
          remotePath: remotePath,
          localPath: localPath,
          totalBytes: totalBytes,
          writtenBytes: written,
          status: TransferStatus.running,
        );
        yield _tasks[index];
      }
    }
  }

  Future<void> pauseTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index >= 0) {
      final task = _tasks[index];
      _tasks[index] = TransferTaskUi(
        id: task.id,
        serverId: task.serverId,
        transferType: task.transferType,
        remotePath: task.remotePath,
        localPath: task.localPath,
        totalBytes: task.totalBytes,
        writtenBytes: task.writtenBytes,
        status: TransferStatus.paused,
      );
    }
  }

  Future<void> resumeTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index >= 0) {
      final task = _tasks[index];
      _tasks[index] = TransferTaskUi(
        id: task.id,
        serverId: task.serverId,
        transferType: task.transferType,
        remotePath: task.remotePath,
        localPath: task.localPath,
        totalBytes: task.totalBytes,
        writtenBytes: task.writtenBytes,
        status: TransferStatus.running,
      );
    }
  }

  Future<void> cancelTask(String taskId) async {
    _tasks.removeWhere((t) => t.id == taskId);
  }

  void clearCompleted() {
    _tasks.removeWhere(
      (t) =>
          t.status == TransferStatus.done || t.status == TransferStatus.failed,
    );
  }
}

final transferServiceProvider = Provider<TransferService>((ref) {
  return TransferService(ref);
});

final transferTasksProvider =
    StateNotifierProvider<TransferTasksNotifier, List<TransferTaskUi>>((ref) {
      return TransferTasksNotifier(ref);
    });

class TransferTasksNotifier extends StateNotifier<List<TransferTaskUi>> {
  final Ref ref;

  TransferTasksNotifier(this.ref) : super([]);

  void addTask(TransferTaskUi task) {
    state = [...state, task];
  }

  void updateTask(String id, TransferTaskUi task) {
    state = [
      for (final t in state)
        if (t.id == id) task else t,
    ];
  }

  void removeTask(String id) {
    state = state.where((t) => t.id != id).toList();
  }

  void clearCompleted() {
    state = state
        .where(
          (t) =>
              t.status != TransferStatus.done &&
              t.status != TransferStatus.failed,
        )
        .toList();
  }
}

final downloadQueueProvider = Provider<List<TransferTaskUi>>((ref) {
  final tasks = ref.watch(transferTasksProvider);
  return tasks.where((t) => t.transferType == TransferType.download).toList();
});

final uploadQueueProvider = Provider<List<TransferTaskUi>>((ref) {
  final tasks = ref.watch(transferTasksProvider);
  return tasks.where((t) => t.transferType == TransferType.upload).toList();
});

final activeTransferCountProvider = Provider<int>((ref) {
  final tasks = ref.watch(transferTasksProvider);
  return tasks.where((t) => t.status == TransferStatus.running).length;
});
