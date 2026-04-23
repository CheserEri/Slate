import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/models.dart';

class PersistentStore {
  final String _dataDir;

  PersistentStore(String dataDir) : _dataDir = dataDir {
    Directory(_dataDir).createSync(recursive: true);
  }

  String get _serversFile => path.join(_dataDir, 'smb_servers.json');
  String get _tasksFile => path.join(_dataDir, 'transfer_tasks.json');

  List<SmbConfig> loadServers() {
    final file = File(_serversFile);
    if (!file.existsSync()) return [];
    try {
      final json = jsonDecode(file.readAsStringSync()) as List<dynamic>;
      return json.map((e) => SmbConfig.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  void saveServers(List<SmbConfig> servers) {
    final json = servers.map((s) => s.toJson()).toList();
    File(_serversFile).writeAsStringSync(jsonEncode(json));
  }

  List<TransferTask> loadTasks() {
    final file = File(_tasksFile);
    if (!file.existsSync()) return [];
    try {
      final json = jsonDecode(file.readAsStringSync()) as List<dynamic>;
      return json.map((e) => TransferTask.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  void saveTasks(List<TransferTask> tasks) {
    final json = tasks.map((t) => t.toJson()).toList();
    File(_tasksFile).writeAsStringSync(jsonEncode(json));
  }
}
