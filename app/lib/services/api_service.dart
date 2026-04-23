import 'dart:convert';
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

  Future<void> deleteSmbServer(String id) async {
    final response = await http.delete(Uri.parse(ApiConstants.smbServer(id)));
    if (response.statusCode != 200) {
      throw ApiException('Failed to delete server', statusCode: response.statusCode);
    }
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
