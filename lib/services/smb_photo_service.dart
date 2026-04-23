import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/models.dart';

class SmbPhotoService {
  Future<bool> testConnection(SmbConfig config) async {
    final result = await _runSmbClient(config, 'ls');
    return result.exitCode == 0;
  }

  Future<List<SmbFileInfo>> listDirectory(SmbConfig config, String path) async {
    final effectivePath = _effectivePath(config, path);
    final normalized = _normalizePath(effectivePath);
    final command = normalized.isEmpty || normalized == '\\'
        ? 'ls'
        : 'cd "$normalized"; ls';
    final result = await _runSmbClient(config, command);
    if (result.exitCode != 0) {
      throw Exception('SMB list failed: ${result.stderr}');
    }
    return _parseLsOutput(result.stdout as String);
  }

  Future<void> downloadFile(
    SmbConfig config,
    String remotePath,
    String localPath, {
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = Directory(localPath).parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final normalizedRemote = remotePath.replaceAll('/', '\\');
    final args = <String>[
      '//${config.host}/${config.share}',
      '-p',
      '${config.port}',
      '-U',
      config.username,
      '--password=${config.password ?? ''}',
      '-c',
      'get "$normalizedRemote" "$localPath"',
    ];
    if (config.domain.isNotEmpty) {
      args.addAll(['-W', config.domain]);
    }
    final process = await Process.start(
      'smbclient',
      args,
    );

    Timer? timer;
    if (onProgress != null) {
      timer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
        final file = File(localPath);
        if (await file.exists()) {
          final received = await file.length();
          onProgress(received, 0);
        }
      });
    }

    final exitCode = await process.exitCode;
    timer?.cancel();

    if (exitCode != 0) {
      final stderr = await process.stderr.transform(utf8.decoder).join();
      throw Exception('Download failed: $stderr');
    }
  }

  Future<void> uploadFile(
    SmbConfig config,
    String localPath,
    String remotePath, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('Local file not found: $localPath');
    }
    final totalBytes = await file.length();

    final normalizedRemote = remotePath.replaceAll('/', '\\');
    final args = <String>[
      '//${config.host}/${config.share}',
      '-p',
      '${config.port}',
      '-U',
      config.username,
      '--password=${config.password ?? ''}',
      '-c',
      'put "$localPath" "$normalizedRemote"',
    ];
    if (config.domain.isNotEmpty) {
      args.addAll(['-W', config.domain]);
    }
    final process = await Process.start(
      'smbclient',
      args,
    );

    Timer? timer;
    if (onProgress != null) {
      timer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
        onProgress(0, totalBytes);
      });
    }

    final exitCode = await process.exitCode;
    timer?.cancel();

    if (exitCode != 0) {
      final stderr = await process.stderr.transform(utf8.decoder).join();
      throw Exception('Upload failed: $stderr');
    }
  }

  Future<ProcessResult> _runSmbClient(SmbConfig config, String command) async {
    final args = <String>[
      '//${config.host}/${config.share}',
      '-p',
      '${config.port}',
      '-U',
      config.username,
      '--password=${config.password ?? ''}',
      '-c',
      command,
    ];
    if (config.domain.isNotEmpty) {
      args.addAll(['-W', config.domain]);
    }
    return Process.run(
      'smbclient',
      args,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  }

  String _normalizePath(String path) {
    if (path.isEmpty || path == '/') return '';
    return path.replaceAll('/', '\\');
  }

  String _effectivePath(SmbConfig config, String path) {
    if (config.rootPath.isEmpty) return path;
    if (path.isEmpty || path == '/') return config.rootPath;
    return '${config.rootPath}/$path';
  }

  List<SmbFileInfo> _parseLsOutput(String output) {
    final results = <SmbFileInfo>[];
    final lines = LineSplitter.split(output);

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final reg = RegExp(r'([DA])\s+(\d+)\s+(.+)$');
      final match = reg.firstMatch(line);
      if (match == null) continue;

      final type = match.group(1)!;
      final sizeStr = match.group(2)!;
      final dateStr = match.group(3)!;
      final name = line.substring(0, match.start).trim();

      if (name == '.' || name == '..') continue;

      DateTime? modifiedAt;
      try {
        modifiedAt = _parseSmbDate(dateStr);
      } catch (_) {
        modifiedAt = null;
      }

      results.add(SmbFileInfo(
        name: name,
        isDirectory: type == 'D',
        size: int.tryParse(sizeStr) ?? 0,
        modifiedAt: modifiedAt,
      ));
    }

    return results;
  }

  DateTime? _parseSmbDate(String s) {
    try {
      final parts = s.trim().split(RegExp(r'\s+'));
      if (parts.length < 5) return null;
      final year = int.parse(parts.last);
      final timeParts = parts[parts.length - 2].split(':');
      if (timeParts.length != 3) return null;
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final second = int.parse(timeParts[2]);
      final day = int.parse(parts[parts.length - 3]);
      final month = _monthNameToNumber(parts[parts.length - 4]);
      if (month == null) return null;
      return DateTime(year, month, day, hour, minute, second);
    } catch (_) {
      return null;
    }
  }

  int? _monthNameToNumber(String name) {
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    for (final entry in months.entries) {
      if (name.toLowerCase().startsWith(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return null;
  }
}
