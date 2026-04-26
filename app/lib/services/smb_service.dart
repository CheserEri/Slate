import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:smb_connect/smb_connect.dart';
import '../models/models.dart';

class SmbService {
  Future<bool> testConnection(SmbConfig config) async {
    try {
      final connect = await SmbConnect.connectAuth(
        host: config.host,
        domain: config.domain,
        username: config.username,
        password: config.password ?? '',
      );
      await connect.listShares();
      await connect.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> listShares(SmbConfig config) async {
    final connect = await SmbConnect.connectAuth(
      host: config.host,
      domain: config.domain,
      username: config.username,
      password: config.password ?? '',
    );
    final shares = await connect.listShares();
    await connect.close();
    return shares.map((s) => s.name).toList();
  }

  Future<List<String>> listDirectories(SmbConfig config, String path) async {
    final connect = await SmbConnect.connectAuth(
      host: config.host,
      domain: config.domain,
      username: config.username,
      password: config.password ?? '',
    );
    final share = '${config.share}${config.rootPath}$path';
    final folder = await connect.file(share);
    final files = await connect.listFiles(folder);
    await connect.close();
    return files.where((f) => f.isDirectory).map((f) => f.name).toList();
  }

  Future<List<MediaItem>> getMediaItems(SmbConfig config, {String path = ''}) async {
    final connect = await SmbConnect.connectAuth(
      host: config.host,
      domain: config.domain,
      username: config.username,
      password: config.password ?? '',
    );
    final share = '${config.share}${config.rootPath}$path';
    final folder = await connect.file(share);
    final files = await connect.listFiles(folder);
    await connect.close();

    final items = <MediaItem>[];
    for (final file in files) {
      if (!file.isDirectory && _isImage(file.name)) {
        items.add(MediaItem(
          id: file.path,
          name: file.name,
          path: '${config.id}$path/${file.name}',
          source: SmbSource(config.id),
          mimeType: _getMimeType(file.name),
          size: file.size ?? 0,
          width: 0,
          height: 0,
          modifiedAt: file.modified ?? DateTime.now(),
        ));
      }
    }
    return items;
  }

  Future<List<Album>> getAlbums(SmbConfig config, {String currentPath = ''}) async {
    final connect = await SmbConnect.connectAuth(
      host: config.host,
      domain: config.domain,
      username: config.username,
      password: config.password ?? '',
    );
    final share = '${config.share}${config.rootPath}$currentPath';
    final folder = await connect.file(share);
    final files = await connect.listFiles(folder);
    await connect.close();

    final albums = <Album>[];
    for (final file in files) {
      if (file.isDirectory) {
        albums.add(Album(
          id: file.path,
          name: file.name,
          source: SmbSource(config.id),
          coverPath: null,
          count: 0,
          parentPath: currentPath,
        ));
      }
    }
    return albums;
  }

  Future<Uint8List> readFile(SmbConfig config, String remotePath) async {
    final connect = await SmbConnect.connectAuth(
      host: config.host,
      domain: config.domain,
      username: config.username,
      password: config.password ?? '',
    );
    final share = '${config.share}${config.rootPath}/$remotePath';
    final file = await connect.file(share);
    final stream = await connect.openRead(file);
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
    await connect.close();
    return Uint8List.fromList(bytes);
  }

  Future<String> downloadFile(SmbConfig config, String remotePath) async {
    final data = await readFile(config, remotePath);
    final dir = await getApplicationDocumentsDirectory();
    final fileName = remotePath.split('/').last;
    final localPath = '${dir.path}/$fileName';
    await File(localPath).writeAsBytes(data);
    return localPath;
  }

  Future<void> uploadFile(SmbConfig config, String remotePath, Uint8List data) async {
    final connect = await SmbConnect.connectAuth(
      host: config.host,
      domain: config.domain,
      username: config.username,
      password: config.password ?? '',
    );
    final share = '${config.share}${config.rootPath}/$remotePath';
    final file = await connect.createFile(share);
    final writer = await connect.openWrite(file);
    writer.add(data);
    await writer.flush();
    await writer.close();
    await connect.close();
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
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}