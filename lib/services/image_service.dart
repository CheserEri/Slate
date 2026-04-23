import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

class ThumbnailCache {
  static final ThumbnailCache _instance = ThumbnailCache._internal();
  factory ThumbnailCache() => _instance;
  ThumbnailCache._internal();

  final Map<String, Uint8List> _memoryCache = {};
  static const int _maxMemoryCacheSize = 100;
  String _cacheKey(String serverId, String path) =>
      '${serverId}_${path.hashCode}';

  Future<Directory> get _cacheDir async {
    final dir = await getApplicationCacheDirectory();
    return dir;
  }

  Future<Uint8List?> getThumbnail(String serverId, String remotePath) async {
    final key = _cacheKey(serverId, remotePath);

    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }

    final cacheDir = await _cacheDir;
    final file = File('${cacheDir.path}/thumb_$key.jpg');
    if (await file.exists()) {
      final data = await file.readAsBytes();
      _addToMemoryCache(key, data);
      return data;
    }

    return null;
  }

  Future<void> cacheThumbnail(
    String serverId,
    String remotePath,
    Uint8List data,
  ) async {
    final key = _cacheKey(serverId, remotePath);

    _addToMemoryCache(key, data);

    final cacheDir = await _cacheDir;
    final file = File('${cacheDir.path}/thumb_$key.jpg');
    await file.writeAsBytes(data);
  }

  void _addToMemoryCache(String key, Uint8List data) {
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[key] = data;
  }

  void clearMemoryCache() {
    _memoryCache.clear();
  }

  Future<void> clearAll() async {
    _memoryCache.clear();
    final cacheDir = await _cacheDir;
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  }
}

class ImageService {
  final ThumbnailCache _cache = ThumbnailCache();

  Future<Uint8List?> getLocalThumbnail(String path, {int maxSize = 256}) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;

      final data = await file.readAsBytes();
      final size = data.length;

      if (size > maxSize * 1024) {
        final partial = data.take(maxSize * 1024).toList();
        return Uint8List.fromList(partial);
      }

      return data;
    } catch (e) {
      debugPrint('Error loading thumbnail: $e');
      return null;
    }
  }

  Future<Uint8List?> getSmbThumbnail(
    String serverId,
    String remotePath, {
    int maxSize = 256,
  }) async {
    final cached = await _cache.getThumbnail(serverId, remotePath);
    if (cached != null) return cached;

    return null;
  }

  Future<void> cacheSmbThumbnail(
    String serverId,
    String remotePath,
    Uint8List data,
  ) async {
    await _cache.cacheThumbnail(serverId, remotePath, data);
  }

  Future<(int, int)?> getImageDimensions(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;

      final data = await file.readAsBytes();

      return _parseDimensions(data);
    } catch (e) {
      return null;
    }
  }

  (int, int)? _parseDimensions(Uint8List data) {
    if (data.length < 4) return null;

    if (data[0] == 0xFF && data[1] == 0xD8) {
      return _parseJpegDimensions(data);
    } else if (data[0] == 0x89 && data[1] == 0x50) {
      return _parsePngDimensions(data);
    }

    return null;
  }

  (int, int)? _parseJpegDimensions(Uint8List data) {
    int offset = 2;
    while (offset < data.length) {
      if (data[offset] != 0xFF) break;

      final marker = data[offset + 1];
      if (marker == 0xC0 || marker == 0xC2) {
        final height = (data[offset + 5] << 8) | data[offset + 6];
        final width = (data[offset + 7] << 8) | data[offset + 8];
        return (width, height);
      }

      final length = (data[offset + 2] << 8) | data[offset + 3];
      offset += 2 + length;
    }
    return null;
  }

  (int, int)? _parsePngDimensions(Uint8List data) {
    if (data.length < 24) return null;
    final width =
        (data[16] << 24) | (data[17] << 16) | (data[18] << 8) | data[19];
    final height =
        (data[20] << 24) | (data[21] << 16) | (data[22] << 8) | data[23];
    return (width, height);
  }
}

final imageServiceProvider = ImageService();
