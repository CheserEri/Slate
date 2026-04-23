import 'dart:io';
import 'package:mime/mime.dart';
import '../models/models.dart';

class _FileStat {
  final File file;
  final FileStat stat;
  _FileStat(this.file, this.stat);
}

class LocalPhotoService {
  final String rootPath;

  LocalPhotoService(this.rootPath);

  Future<List<Album>> getAlbums() async {
    final root = Directory(rootPath);
    if (!await root.exists()) {
      return [];
    }

    final albums = <Album>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is Directory) {
        final name = entity.path.split(Platform.pathSeparator).last;
        final count = await _countImageFiles(entity);
        String? coverPath;
        await for (final file in entity.list(followLinks: false)) {
          if (file is File && _isImageFile(file.path)) {
            coverPath = file.path;
            break;
          }
        }

        albums.add(Album(
          id: entity.path,
          name: name,
          source: MediaSource.local(),
          coverPath: coverPath,
          count: count,
          parentPath: rootPath,
        ));
      }
    }

    albums.sort((a, b) => a.name.compareTo(b.name));
    return albums;
  }

  Future<List<MediaItem>> getMediaItems(
    String albumId, {
    int page = 0,
    int pageSize = 50,
  }) async {
    final dir = Directory(albumId);
    if (!await dir.exists()) return [];

    final fileStats = <_FileStat>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && _isImageFile(entity.path)) {
        final stat = await entity.stat();
        fileStats.add(_FileStat(entity, stat));
      }
    }

    fileStats.sort((a, b) => b.stat.modified.compareTo(a.stat.modified));

    final start = page * pageSize;
    if (start >= fileStats.length) return [];

    final end = (start + pageSize).clamp(start, fileStats.length);
    final pageFiles = fileStats.sublist(start, end);

    return pageFiles.map((fs) {
      final file = fs.file;
      final stat = fs.stat;
      final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
      return MediaItem(
        id: file.path,
        name: file.path.split(Platform.pathSeparator).last,
        path: file.path,
        source: MediaSource.local(),
        mimeType: mimeType,
        size: stat.size,
        width: 0,
        height: 0,
        modifiedAt: stat.modified,
      );
    }).toList();
  }

  Future<int> _countImageFiles(Directory dir) async {
    int count = 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && _isImageFile(entity.path)) {
        count++;
      }
    }
    return count;
  }

  bool _isImageFile(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.webp') ||
        ext.endsWith('.bmp') ||
        ext.endsWith('.heic') ||
        ext.endsWith('.heif');
  }
}
