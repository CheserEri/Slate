import 'dart:async';
import 'dart:io';
import '../models/models.dart';
import 'smb_photo_service.dart';

class TransferService {
  final SmbPhotoService _smbService;
  final Map<String, TransferTask> _tasks = {};
  int _idCounter = 0;

  TransferService(this._smbService);

  List<TransferTask> get tasks => List.unmodifiable(_tasks.values);

  Future<TransferTask> startDownload({
    required SmbConfig config,
    required String remotePath,
    required String localDir,
  }) async {
    final id = 'dl_${++_idCounter}_${DateTime.now().millisecondsSinceEpoch}';
    final fileName = remotePath.split('/').last;
    final localPath = '$localDir/${_sanitizeFileName(fileName)}';

    final task = TransferTask(
      id: id,
      serverId: config.id,
      transferType: TransferType.download,
      remotePath: remotePath,
      localPath: localPath,
      totalBytes: 0,
      writtenBytes: 0,
      status: TransferStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _tasks[id] = task;

    try {
      final parentPath = remotePath.contains('/')
          ? remotePath.substring(0, remotePath.lastIndexOf('/'))
          : '';
      final files = await _smbService.listDirectory(
        config,
        parentPath.isEmpty ? '/' : parentPath,
      );
      final remoteFile = files.firstWhere(
        (f) => f.name == fileName,
        orElse: () => throw Exception('File not found: $remotePath'),
      );
      _tasks[id] = task.copyWith(
        totalBytes: remoteFile.size,
        status: TransferStatus.running,
      );
    } catch (e) {
      _tasks[id] = task.copyWith(
        status: TransferStatus.failed,
        errorMessage: e.toString(),
      );
      return _tasks[id]!;
    }

    _runDownload(id, config, remotePath, localPath);

    return _tasks[id]!;
  }

  Future<TransferTask> startUpload({
    required SmbConfig config,
    required String localPath,
    required String remoteDir,
  }) async {
    final id = 'ul_${++_idCounter}_${DateTime.now().millisecondsSinceEpoch}';
    final fileName = localPath.split(Platform.pathSeparator).last;
    final remotePath = remoteDir.endsWith('/')
        ? '$remoteDir$fileName'
        : '$remoteDir/$fileName';

    final file = File(localPath);
    int totalBytes = 0;
    if (await file.exists()) {
      totalBytes = await file.length();
    }

    final task = TransferTask(
      id: id,
      serverId: config.id,
      transferType: TransferType.upload,
      remotePath: remotePath,
      localPath: localPath,
      totalBytes: totalBytes,
      writtenBytes: 0,
      status: TransferStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _tasks[id] = task;
    _tasks[id] = task.copyWith(status: TransferStatus.running);

    _runUpload(id, config, localPath, remotePath);

    return _tasks[id]!;
  }

  Future<void> _runDownload(
    String id,
    SmbConfig config,
    String remotePath,
    String localPath,
  ) async {
    try {
      await _smbService.downloadFile(
        config,
        remotePath,
        localPath,
        onProgress: (received, _) {
          _updateTask(id, received: received, status: TransferStatus.running);
        },
      );

      final localFile = File(localPath);
      final finalSize = await localFile.length();
      _updateTask(
        id,
        received: finalSize,
        status: TransferStatus.done,
      );
    } catch (e) {
      _updateTask(id, status: TransferStatus.failed, errorMessage: e.toString());
    }
  }

  Future<void> _runUpload(
    String id,
    SmbConfig config,
    String localPath,
    String remotePath,
  ) async {
    try {
      await _smbService.uploadFile(
        config,
        localPath,
        remotePath,
        onProgress: (sent, total) {
          _updateTask(id, received: sent, status: TransferStatus.running);
        },
      );
      _updateTask(id, received: _tasks[id]!.totalBytes, status: TransferStatus.done);
    } catch (e) {
      _updateTask(id, status: TransferStatus.failed, errorMessage: e.toString());
    }
  }

  void _updateTask(
    String id, {
    int? received,
    TransferStatus? status,
    String? errorMessage,
  }) {
    final task = _tasks[id];
    if (task == null) return;

    _tasks[id] = task.copyWith(
      writtenBytes: received ?? task.writtenBytes,
      status: status ?? task.status,
      errorMessage: errorMessage ?? task.errorMessage,
      updatedAt: DateTime.now(),
    );
  }

  void pauseTask(String id) {
    _updateTask(id, status: TransferStatus.paused);
  }

  void resumeTask(String id) {
    _updateTask(id, status: TransferStatus.running);
  }

  void cancelTask(String id) {
    _tasks.remove(id);
  }

  void clearCompleted() {
    _tasks.removeWhere(
      (_, t) => t.status == TransferStatus.done || t.status == TransferStatus.failed,
    );
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\/:*?"<>|]'), '_');
  }
}
