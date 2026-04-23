import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../models/models.dart';
import '../services/local_photo_service.dart';
import '../services/smb_photo_service.dart';
import '../services/transfer_service.dart';

class ApiRouter {
  final LocalPhotoService localService;
  final SmbPhotoService smbService;
  final TransferService transferService;
  final Map<String, SmbConfig> _smbServers = {};

  ApiRouter({
    required this.localService,
    required this.smbService,
    required this.transferService,
  });

  Router get router {
    final router = Router();

    router.get('/health', _health);
    router.get('/', _info);

    router.get('/local/albums', _getLocalAlbums);
    router.get('/local/albums/<path|.*>/items', _getLocalItems);

    router.post('/smb/servers', _addSmbServer);
    router.get('/smb/servers', _listSmbServers);
    router.get('/smb/servers/<id>', _getSmbServer);
    router.delete('/smb/servers/<id>', _deleteSmbServer);
    router.post('/smb/servers/<id>/connect', _testSmbConnection);
    router.get('/smb/servers/<id>/albums', _getSmbAlbums);
    router.get('/smb/servers/<id>/items', _getSmbItems);
    router.post('/smb/servers/<id>/download', _downloadSmbFile);
    router.post('/smb/servers/<id>/upload', _uploadSmbFile);

    router.get('/transfers', _getTransfers);
    router.delete('/transfers/<id>', _cancelTransfer);
    router.post('/transfers/<id>/pause', _pauseTransfer);
    router.post('/transfers/<id>/resume', _resumeTransfer);

    return router;
  }

  Response _health(Request req) => Response.ok(
        jsonEncode({'status': 'ok'}),
        headers: {'content-type': 'application/json'},
      );

  Response _info(Request req) => Response.ok(
        jsonEncode({
          'name': 'Slate Backend',
          'version': '1.0.0',
          'endpoints': [
            '/health',
            '/local/albums',
            '/smb/servers',
            '/transfers',
          ],
        }),
        headers: {'content-type': 'application/json'},
      );

  Future<Response> _getLocalAlbums(Request req) async {
    try {
      final albums = await localService.getAlbums();
      return Response.ok(
        jsonEncode(albums.map((a) => a.toJson()).toList()),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _getLocalItems(Request req, String path) async {
    try {
      final albumPath = path.isEmpty
          ? localService.rootPath
          : '${localService.rootPath}${Platform.pathSeparator}$path';
      final page = int.tryParse(req.url.queryParameters['page'] ?? '0') ?? 0;
      final pageSize =
          int.tryParse(req.url.queryParameters['page_size'] ?? '50') ?? 50;
      final items =
          await localService.getMediaItems(albumPath, page: page, pageSize: pageSize);
      return Response.ok(
        jsonEncode(items.map((i) => i.toJson()).toList()),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _addSmbServer(Request req) async {
    try {
      final body = await req.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final config = SmbConfig(
        id: json['id'] ?? 'smb_${DateTime.now().millisecondsSinceEpoch}',
        name: json['name'] as String,
        host: json['host'] as String,
        port: (json['port'] as num?)?.toInt() ?? 445,
        share: json['share'] as String,
        rootPath: json['root_path'] as String? ?? '',
        username: (json['username'] as String?) ?? 'guest',
        password: json['password'] as String?,
        domain: json['domain'] as String? ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _smbServers[config.id] = config;
      return Response.ok(
        jsonEncode(config.toJson(includePassword: false)),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Response _listSmbServers(Request req) {
    final list = _smbServers.values
        .map((s) => s.toJson(includePassword: false))
        .toList();
    return Response.ok(
      jsonEncode(list),
      headers: {'content-type': 'application/json'},
    );
  }

  Response _getSmbServer(Request req, String id) {
    final config = _smbServers[id];
    if (config == null) {
      return Response.notFound(
        jsonEncode({'error': 'Server not found'}),
        headers: {'content-type': 'application/json'},
      );
    }
    return Response.ok(
      jsonEncode(config.toJson(includePassword: false)),
      headers: {'content-type': 'application/json'},
    );
  }

  Response _deleteSmbServer(Request req, String id) {
    _smbServers.remove(id);
    return Response.ok(
      jsonEncode({'success': true}),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> _testSmbConnection(Request req, String id) async {
    final config = _smbServers[id];
    if (config == null) {
      return Response.notFound(
        jsonEncode({'error': 'Server not found'}),
        headers: {'content-type': 'application/json'},
      );
    }
    try {
      final success = await smbService.testConnection(config);
      return Response.ok(
        jsonEncode({'connected': success}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.ok(
        jsonEncode({'connected': false, 'error': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _getSmbAlbums(Request req, String id) async {
    final config = _smbServers[id];
    if (config == null) {
      return Response.notFound(
        jsonEncode({'error': 'Server not found'}),
        headers: {'content-type': 'application/json'},
      );
    }
    try {
      final path = req.url.queryParameters['path'] ?? '';
      final files = await smbService.listDirectory(config, path);
      final albums = files
          .where((f) => f.isDirectory)
          .map(
            (f) => Album(
              id: '$id/${f.name}',
              name: f.name,
              source: MediaSource.smb(id),
              coverPath: null,
              count: 0,
              parentPath: path,
            ),
          )
          .toList();
      return Response.ok(
        jsonEncode(albums.map((a) => a.toJson()).toList()),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _getSmbItems(Request req, String id) async {
    final config = _smbServers[id];
    if (config == null) {
      return Response.notFound(
        jsonEncode({'error': 'Server not found'}),
        headers: {'content-type': 'application/json'},
      );
    }
    try {
      final path = req.url.queryParameters['path'] ?? '';
      final files = await smbService.listDirectory(config, path);
      final items = files
          .where((f) => !f.isDirectory)
          .where((f) => _isImageFile(f.name))
          .map(
            (f) => MediaItem(
              id: '$id/$path/${f.name}',
              name: f.name,
              path: '$id/$path/${f.name}',
              source: MediaSource.smb(id),
              mimeType: _guessMimeType(f.name),
              size: f.size,
              width: 0,
              height: 0,
              modifiedAt: f.modifiedAt ?? DateTime.now(),
            ),
          )
          .toList();
      return Response.ok(
        jsonEncode(items.map((i) => i.toJson()).toList()),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _downloadSmbFile(Request req, String id) async {
    final config = _smbServers[id];
    if (config == null) {
      return Response.notFound(
        jsonEncode({'error': 'Server not found'}),
        headers: {'content-type': 'application/json'},
      );
    }
    try {
      final body = await req.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final remotePath = json['remote_path'] as String;
      final localDir = json['local_dir'] as String? ?? './downloads';

      final task = await transferService.startDownload(
        config: config,
        remotePath: remotePath,
        localDir: localDir,
      );
      return Response.ok(
        jsonEncode(task.toJson()),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _uploadSmbFile(Request req, String id) async {
    final config = _smbServers[id];
    if (config == null) {
      return Response.notFound(
        jsonEncode({'error': 'Server not found'}),
        headers: {'content-type': 'application/json'},
      );
    }
    try {
      final body = await req.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final localPath = json['local_path'] as String;
      final remoteDir = json['remote_dir'] as String? ?? '/';

      final task = await transferService.startUpload(
        config: config,
        localPath: localPath,
        remoteDir: remoteDir,
      );
      return Response.ok(
        jsonEncode(task.toJson()),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Response _getTransfers(Request req) {
    final list = transferService.tasks.map((t) => t.toJson()).toList();
    return Response.ok(
      jsonEncode(list),
      headers: {'content-type': 'application/json'},
    );
  }

  Response _cancelTransfer(Request req, String id) {
    transferService.cancelTask(id);
    return Response.ok(
      jsonEncode({'success': true}),
      headers: {'content-type': 'application/json'},
    );
  }

  Response _pauseTransfer(Request req, String id) {
    transferService.pauseTask(id);
    return Response.ok(
      jsonEncode({'success': true}),
      headers: {'content-type': 'application/json'},
    );
  }

  Response _resumeTransfer(Request req, String id) {
    transferService.resumeTask(id);
    return Response.ok(
      jsonEncode({'success': true}),
      headers: {'content-type': 'application/json'},
    );
  }

  bool _isImageFile(String name) {
    final ext = name.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.webp') ||
        ext.endsWith('.bmp') ||
        ext.endsWith('.heic') ||
        ext.endsWith('.heif');
  }

  String _guessMimeType(String name) {
    final ext = name.toLowerCase();
    if (ext.endsWith('.png')) return 'image/png';
    if (ext.endsWith('.gif')) return 'image/gif';
    if (ext.endsWith('.webp')) return 'image/webp';
    if (ext.endsWith('.bmp')) return 'image/bmp';
    if (ext.endsWith('.heic') || ext.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }
}
