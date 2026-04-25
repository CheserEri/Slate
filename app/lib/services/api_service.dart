import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../utils/constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => 'ApiException: $message';
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Future<List<Album>> fetchLocalAlbums() async {
    final response = await http.get(Uri.parse(ApiConstants.localAlbums));
    return _parseList(response, Album.fromJson);
  }

  Future<List<MediaItem>> fetchLocalItems(String albumId,
      {int page = 0, int pageSize = 50}) async {
    final uri = Uri.parse(ApiConstants.localItems(albumId)).replace(
      queryParameters: {'page': '$page', 'page_size': '$pageSize'},
    );
    final response = await http.get(uri);
    return _parseList(response, MediaItem.fromJson);
  }

  Future<SmbConfig> addSmbServer(SmbConfig config) async {
    final response = await http.post(
      Uri.parse(ApiConstants.smbServers),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(config.toJson()),
    );
    return _parseSingle(response, SmbConfig.fromJson);
  }

  Future<List<SmbConfig>> fetchSmbServers() async {
    final response = await http.get(Uri.parse(ApiConstants.smbServers));
    return _parseList(response, SmbConfig.fromJson);
  }

  Future<bool> testSmbConnection(String id) async {
    final response =
        await http.post(Uri.parse(ApiConstants.smbConnect(id)));
    if (response.statusCode != 200) return false;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['connected'] == true;
  }

  Future<bool> testSmbDraftConnection({
    required String host,
    required int port,
    required String share,
    required String username,
    String? password,
    String domain = '',
  }) async {
    final response = await http.post(
      Uri.parse(ApiConstants.smbProbeConnect),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'host': host,
        'port': port,
        'share': share,
        'username': username,
        'password': password,
        'domain': domain,
      }),
    );
    if (response.statusCode != 200) return false;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['connected'] == true;
  }

  Future<List<String>> probeSmbShares({
    required String host,
    required int port,
    required String username,
    String? password,
    String domain = '',
  }) async {
    final response = await http.post(
      Uri.parse(ApiConstants.smbProbeShares),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'domain': domain,
      }),
    );
    return _parseStringList(response);
  }

  Future<List<String>> probeSmbDirectories({
    required String host,
    required int port,
    required String share,
    required String username,
    String? password,
    String domain = '',
    String path = '',
  }) async {
    final response = await http.post(
      Uri.parse(ApiConstants.smbProbeDirectories),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'host': host,
        'port': port,
        'share': share,
        'username': username,
        'password': password,
        'domain': domain,
        'path': path,
      }),
    );
    return _parseStringList(response);
  }

  Future<void> deleteSmbServer(String id) async {
    final response = await http.delete(Uri.parse(ApiConstants.smbServer(id)));
    if (response.statusCode != 200) {
      throw ApiException('Failed to delete server', statusCode: response.statusCode);
    }
  }

  Future<SmbConfig> updateSmbServer(String id, SmbConfig config) async {
    final response = await http.put(
      Uri.parse(ApiConstants.smbServer(id)),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(config.toJson()),
    );
    return _parseSingle(response, SmbConfig.fromJson);
  }

  Future<String> previewSmbFileUrl(String serverId, String remotePath) async {
    final uri = Uri.parse(ApiConstants.smbPreview(serverId)).replace(
      queryParameters: {'path': remotePath},
    );
    return uri.toString();
  }

  Future<List<Album>> fetchSmbAlbums(String id, {String path = ''}) async {
    final uri = Uri.parse(ApiConstants.smbAlbums(id)).replace(
      queryParameters: path.isNotEmpty ? {'path': path} : null,
    );
    final response = await http.get(uri);
    return _parseList(response, Album.fromJson);
  }

  Future<List<MediaItem>> fetchSmbItems(String id, {String path = ''}) async {
    final uri = Uri.parse(ApiConstants.smbItems(id)).replace(
      queryParameters: path.isNotEmpty ? {'path': path} : null,
    );
    final response = await http.get(uri);
    return _parseList(response, MediaItem.fromJson);
  }

  Future<TransferTask> downloadSmbFile(
    String serverId,
    String remotePath, {
    String localDir = './downloads',
  }) async {
    final response = await http.post(
      Uri.parse(ApiConstants.smbDownload(serverId)),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'remote_path': remotePath,
        'local_dir': localDir,
      }),
    );
    return _parseSingle(response, TransferTask.fromJson);
  }

  Future<TransferTask> uploadSmbFile(
    String serverId,
    String localPath, {
    String remoteDir = '/',
  }) async {
    final response = await http.post(
      Uri.parse(ApiConstants.smbUpload(serverId)),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'local_path': localPath,
        'remote_dir': remoteDir,
      }),
    );
    return _parseSingle(response, TransferTask.fromJson);
  }

  Future<void> downloadSmbFileToLocal(
    String serverId,
    String remotePath,
    String savePath,
  ) async {
    final uri = Uri.parse(ApiConstants.smbPreview(serverId)).replace(
      queryParameters: {'path': remotePath},
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw ApiException('Download failed', statusCode: response.statusCode);
    }
    final file = File(savePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(response.bodyBytes);
  }

  Future<void> fetchHealth() async {
    final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/health'));
    if (response.statusCode != 200) {
      throw ApiException('Health check failed', statusCode: response.statusCode);
    }
  }

  Future<List<TransferTask>> fetchTransfers() async {
    final response = await http.get(Uri.parse(ApiConstants.transfers));
    return _parseList(response, TransferTask.fromJson);
  }

  Future<void> cancelTransfer(String id) async {
    await http.delete(Uri.parse(ApiConstants.transfer(id)));
  }

  Future<void> pauseTransfer(String id) async {
    await http.post(Uri.parse(ApiConstants.transferPause(id)));
  }

  Future<void> resumeTransfer(String id) async {
    await http.post(Uri.parse(ApiConstants.transferResume(id)));
  }

  List<T> _parseList<T>(
    http.Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (response.statusCode != 200) {
      throw ApiException('Request failed', statusCode: response.statusCode);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }

  List<String> _parseStringList(http.Response response) {
    if (response.statusCode != 200) {
      throw ApiException('Request failed', statusCode: response.statusCode);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => e.toString()).toList();
  }

  T _parseSingle<T>(
    http.Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (response.statusCode != 200) {
      throw ApiException('Request failed', statusCode: response.statusCode);
    }
    return fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
