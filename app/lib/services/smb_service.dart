import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smb_connect/smb_connect.dart';
import 'package:smb_connect/src/exceptions.dart' show SmbException;
import '../models/models.dart';

/// 连接包装器，管理 SMB 连接的生命周期和健康状态
class _ConnectionWrapper {
  final SmbConnect connect;
  DateTime lastUsed;
  bool isValid;

  _ConnectionWrapper(this.connect, this.lastUsed, {this.isValid = true});
}

class SmbService {
  final Map<String, _ConnectionWrapper> _connections = {};
  static const _maxConnectionAge = Duration(minutes: 1); // 缩短到1分钟，更快发现失效连接
  SharedPreferences? _prefs;

  /// 获取 SharedPreferences 实例（懒加载）
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// 路径规范化：确保路径格式正确
  String _normalizePath(String path) {
    if (path.isEmpty) return '';
    final trimmed = path.replaceAll(RegExp(r'^/+|/+$'), '');
    return '/$trimmed';
  }

  /// 构建完整的 SMB 路径（相对于共享）
  String _buildSMBPath(SmbConfig config, String path) {
    final share = config.share.replaceAll(RegExp(r'^/+|/+$'), '');
    final root = config.rootPath.replaceAll(RegExp(r'^/+|/+$'), '');
    final p = path.replaceAll(RegExp(r'^/+|/+$'), '');

    final buffer = StringBuffer('/$share');
    if (root.isNotEmpty) {
      buffer.write('/$root');
    }
    if (p.isNotEmpty) {
      buffer.write('/$p');
    }
    return buffer.toString();
  }

  /// 获取或创建连接（带健康检查）
  Future<SmbConnect> _getConnection(SmbConfig config) async {
    final key = '${config.host}:${config.username}';
    final now = DateTime.now();

    // 检查现有连接是否有效
    if (_connections.containsKey(key)) {
      final wrapper = _connections[key]!;
      if (wrapper.isValid && now.difference(wrapper.lastUsed) < _maxConnectionAge) {
        // 快速验证连接是否仍然有效
        try {
          await wrapper.connect.listShares();
          wrapper.lastUsed = now;
          return wrapper.connect;
        } catch (_) {
          // 连接已失效，清理并继续创建新连接
          await wrapper.connect.close();
          _connections.remove(key);
        }
      } else {
        // 连接过期或标记为无效，清理
        await wrapper.connect.close();
        _connections.remove(key);
      }
    }

    // 创建新连接（带断开回调）
    try {
      final connect = await SmbConnect.connectAuth(
        host: config.host,
        domain: config.domain,
        username: config.username,
        password: config.password ?? '',
        onDisconnect: (c) {
          _connections[key]?.isValid = false;
          _connections.remove(key);
        },
      );
      _connections[key] = _ConnectionWrapper(connect, now);
      return connect;
    } catch (e) {
      _connections.remove(key);
      rethrow;
    }
  }

  /// 标记连接为需要重连
  void _invalidateConnection(String host, String username) {
    final key = '$host:$username';
    _connections[key]?.isValid = false;
    _connections.remove(key);
  }

  /// 测试连接
  Future<bool> testConnection(SmbConfig config) async {
    try {
      final connect = await _getConnection(config);
      await connect.listShares();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 列出共享目录
  Future<List<String>> listShares(SmbConfig config) async {
    try {
      final connect = await _getConnection(config);
      final shares = await connect.listShares();
      return shares.map((s) => s.name).toList();
    } catch (_) {
      rethrow;
    }
  }

  /// 列出目录
  Future<List<String>> listDirectories(SmbConfig config, String path) async {
    int retries = 3; // 增加重试次数
    while (retries-- > 0) {
      try {
        final connect = await _getConnection(config);
        final smbPath = _buildSMBPath(config, path);
        final folder = await connect.file(smbPath);
        final files = await connect.listFiles(folder);
        return files.where((f) => f.isDirectory()).map((f) => f.name).toList();
      } on SmbException catch (e) {
        final msg = e.toString().toLowerCase();
        // 判断是否为连接错误（应该重试）
        final isConnectionError = msg.contains('network name') ||
                                   msg.contains('nt_status') ||
                                   msg.contains('not available') ||
                                   msg.contains('disconnected') ||
                                   msg.contains('connection reset') ||
                                   msg.contains('reset by peer');
        if (!isConnectionError) {
          // 非连接错误（如权限不足、路径不存在）直接抛出
          rethrow;
        }
        // 连接错误，检查重试次数
        if (retries == 0) rethrow;
        _invalidateConnection(config.host, config.username);
      } on Exception {
        if (retries == 0) rethrow;
        _invalidateConnection(config.host, config.username);
      }
    }
    return [];
  }

  /// 获取媒体文件列表
  Future<List<MediaItem>> getMediaItems(SmbConfig config, {String path = ''}) async {
    int retries = 3;
    while (retries-- > 0) {
      try {
        final connect = await _getConnection(config);
        final smbPath = _buildSMBPath(config, path);
        final folder = await connect.file(smbPath);
        final files = await connect.listFiles(folder);

        final items = <MediaItem>[];
        for (final file in files) {
          if (!file.isDirectory() && _isImage(file.name)) {
            items.add(MediaItem(
              id: file.path,
              name: file.name,
              path: '${config.id}/$path/${file.name}',
              source: SmbSource(config.id),
              mimeType: _getMimeType(file.name),
              size: file.size ?? 0,
              width: 0,
              height: 0,
              modifiedAt: file.lastModified != 0
                  ? DateTime.fromMillisecondsSinceEpoch(file.lastModified * 1000)
                  : DateTime.now(),
            ));
          }
        }
        return items;
      } on SmbException catch (e) {
        final msg = e.toString().toLowerCase();
        final isConnectionError = msg.contains('network name') ||
                                   msg.contains('nt_status') ||
                                   msg.contains('not available') ||
                                   msg.contains('disconnected') ||
                                   msg.contains('connection reset') ||
                                   msg.contains('reset by peer');
        if (!isConnectionError) rethrow;
        if (retries == 0) rethrow;
        _invalidateConnection(config.host, config.username);
      } on Exception {
        if (retries == 0) rethrow;
        _invalidateConnection(config.host, config.username);
      }
    }
    return [];
  }

  /// 创建远程目录
  Future<void> createDirectory(SmbConfig config, String path) async {
    int retries = 3;
    while (retries-- > 0) {
      try {
        final connect = await _getConnection(config);
        final smbPath = _buildSMBPath(config, path);
        await connect.createFolder(smbPath);
        return;
      } on SmbException catch (e) {
        final msg = e.toString().toLowerCase();
        final isConnectionError = msg.contains('network name') ||
                                   msg.contains('nt_status') ||
                                   msg.contains('not available') ||
                                   msg.contains('disconnected') ||
                                   msg.contains('connection reset') ||
                                   msg.contains('reset by peer');
        if (!isConnectionError) rethrow;
        if (retries == 0) rethrow;
        _invalidateConnection(config.host, config.username);
      } on Exception {
        if (retries == 0) rethrow;
        _invalidateConnection(config.host, config.username);
      }
    }
  }

  /// 获取相册列表（扫描 rootPath 下的所有子文件夹）
  /// 每个子文件夹作为一个相册，统计图片数量，取最新图片作为封面
  Future<List<Album>> getAlbums(SmbConfig config, {String currentPath = ''}) async {
    int retries = 3;
    while (retries-- > 0) {
      try {
        final connect = await _getConnection(config);
        final smbPath = _buildSMBPath(config, currentPath);
        final folder = await connect.file(smbPath);
        final files = await connect.listFiles(folder);

        final albums = <Album>[];
        for (final file in files) {
          if (!file.isDirectory()) continue;

          final albumFolderName = file.name;
          final albumFullPath = currentPath.isEmpty
              ? albumFolderName
              : '$currentPath/$albumFolderName';

          // 扫描该目录下的所有文件
          try {
            final subFolder = await connect.file(_buildSMBPath(config, albumFullPath));
            final subFiles = await connect.listFiles(subFolder);

            // 筛选图片文件
            final imageFiles = subFiles.where((f) => !f.isDirectory() && _isImage(f.name)).toList();

            if (imageFiles.isEmpty) {
              // 没有图片的文件夹不显示为相册
              continue;
            }

            // 先尝试读取自定义封面
            String? coverPath;
            final prefs = await _getPrefs();
            final customCoverKey = 'custom_cover_${config.id}_$albumFullPath';
            final customCover = prefs.getString(customCoverKey);

            // 验证自定义封面文件是否存在（通过尝试构造 SmbFile）
            if (customCover != null) {
              try {
                final coverFile = await connect.file(_buildSMBPath(config, customCover));
                // SmbFile 构造成功不抛异常，认为路径有效
                // 实际读取图片时会再次验证
                coverPath = customCover;
              } catch (_) {
                // 自定义封面失效，使用自动选择
                coverPath = null;
                prefs.remove(customCoverKey);
              }
            }

            // 如果没有自定义封面或自定义封面失效，找最新修改的图片作为封面
            if (coverPath == null) {
              SmbFile? latestImage;
              for (final img in imageFiles) {
                if (latestImage == null ||
                    (img.lastModified != null && img.lastModified > (latestImage.lastModified ?? 0))) {
                  latestImage = img;
                }
              }
              coverPath = latestImage != null
                  ? '$albumFullPath/${latestImage!.name}'
                  : null;
            }

            albums.add(Album(
              id: albumFullPath,
              name: albumFolderName,
              source: SmbSource(config.id),
              coverPath: coverPath,
              count: imageFiles.length,
              parentPath: currentPath,
            ));
          } catch (e) {
            // 无法读取该子目录，跳过
            continue;
          }
        }

        // 按名称排序
        albums.sort((a, b) => a.name.compareTo(b.name));
        return albums;
      } on SmbException catch (e) {
        final msg = e.toString().toLowerCase();
        final isConnectionError = msg.contains('network name') ||
                                   msg.contains('nt_status') ||
                                   msg.contains('not available') ||
                                   msg.contains('disconnected') ||
                                   msg.contains('connection reset') ||
                                   msg.contains('reset by peer');
        if (!isConnectionError) rethrow;
        if (retries == 0) rethrow;
        _invalidateConnection(config.host, config.username);
      } on Exception {
        if (retries == 0) rethrow;
        _invalidateConnection(config.host, config.username);
      }
    }
    return [];
  }

  /// 读取文件
  Future<Uint8List> readFile(SmbConfig config, String remotePath) async {
    int retries = 3;
    while (retries-- > 0) {
      try {
        final connect = await _getConnection(config);
        String fullPath;
        if (remotePath.startsWith('/')) {
          fullPath = _buildSMBPath(config, remotePath.substring(1));
        } else {
          fullPath = _buildSMBPath(config, remotePath);
        }
        final file = await connect.file(fullPath);
        final stream = await connect.openRead(file);
        final bytes = <int>[];
        await for (final chunk in stream) {
          bytes.addAll(chunk);
        }
        return Uint8List.fromList(bytes);
      } on SmbException catch (e) {
        final msg = e.toString().toLowerCase();
        final isConnectionError = msg.contains('network name') ||
                                   msg.contains('nt_status') ||
                                   msg.contains('not available') ||
                                   msg.contains('disconnected') ||
                                   msg.contains('connection reset') ||
                                   msg.contains('reset by peer');
        if (!isConnectionError) rethrow;
        if (retries == 0) rethrow;
        _invalidateConnection(config.host, config.username);
      } on Exception {
        if (retries == 0) rethrow;
        _invalidateConnection(config.host, config.username);
      }
    }
    return Uint8List(0);
  }

  /// 下载文件
  Future<String> downloadFile(SmbConfig config, String remotePath) async {
    final data = await readFile(config, remotePath);
    final dir = await getApplicationDocumentsDirectory();
    final fileName = remotePath.split('/').last;
    final localPath = '${dir.path}/$fileName';
    await File(localPath).writeAsBytes(data);
    return localPath;
  }

  /// 上传文件
  Future<void> uploadFile(SmbConfig config, String remotePath, Uint8List data) async {
    int retries = 3;
    while (retries-- > 0) {
      try {
        final connect = await _getConnection(config);
        String fullPath;
        if (remotePath.startsWith('/')) {
          fullPath = _buildSMBPath(config, remotePath.substring(1));
        } else {
          fullPath = _buildSMBPath(config, remotePath);
        }
        final file = await connect.createFile(fullPath);
        final writer = await connect.openWrite(file);
        writer.add(data);
        await writer.flush();
        await writer.close();
        return;
      } on SmbException catch (e) {
        final msg = e.toString().toLowerCase();
        final isConnectionError = msg.contains('network name') ||
                                   msg.contains('nt_status') ||
                                   msg.contains('not available') ||
                                   msg.contains('disconnected') ||
                                   msg.contains('connection reset') ||
                                   msg.contains('reset by peer');
        if (!isConnectionError) rethrow;
        if (retries == 0) rethrow;
        _invalidateConnection(config.host, config.username);
      } on Exception {
        if (retries == 0) rethrow;
        _invalidateConnection(config.host, config.username);
      }
    }
  }

  /// 关闭指定服务器的连接
  Future<void> closeConnection(String serverId) async {
    final keysToRemove = <String>[];
    for (final entry in _connections.entries) {
      if (entry.key.contains(serverId)) {
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      final wrapper = _connections.remove(key);
      if (wrapper != null) {
        await wrapper.connect.close();
      }
    }
  }

  /// 关闭所有连接
  Future<void> closeAllConnections() async {
    for (final wrapper in _connections.values) {
      await wrapper.connect.close();
    }
    _connections.clear();
  }

  /// 设置相册自定义封面
  /// [serverId] 服务器 ID，[albumPath] 相册相对路径，[coverPath] 封面图片相对路径
  Future<void> setCustomCover(String serverId, String albumPath, String coverPath) async {
    final prefs = await _getPrefs();
    final key = 'custom_cover_${serverId}_$albumPath';
    await prefs.setString(key, coverPath);
  }

  /// 获取相册自定义封面
  /// 返回封面图片的相对路径，如果没有设置则返回 null
  Future<String?> getCustomCover(String serverId, String albumPath) async {
    final prefs = await _getPrefs();
    final key = 'custom_cover_${serverId}_$albumPath';
    return prefs.getString(key);
  }

  /// 清除相册自定义封面
  Future<void> clearCustomCover(String serverId, String albumPath) async {
    final prefs = await _getPrefs();
    final key = 'custom_cover_${serverId}_$albumPath';
    await prefs.remove(key);
  }

  bool _isImage(String name) {
    final ext = name.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic', 'heif'].contains(ext);
  }

  String _getMimeType(String name) {
    final ext = name.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }
}
