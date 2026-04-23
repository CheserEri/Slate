import 'package:photo_manager/photo_manager.dart';
import '../models/models.dart';

class PhotoService {
  static Future<bool> requestPermission() async {
    final result = await PhotoManager.requestPermissionExtend();
    return result.isAuth;
  }

  static Future<List<Album>> getLocalAlbums() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
    );

    return Future.wait(
      paths.map((path) async {
        final count = await path.assetCountAsync;
        String? coverPath;
        if (count > 0) {
          final assets = await path.getAssetListRange(start: 0, end: 1);
          if (assets.isNotEmpty) {
            final file = await assets.first.file;
            coverPath = file?.path;
          }
        }
        return Album(
          id: path.id,
          name: path.name,
          source: MediaSource.local(),
          coverPath: coverPath,
          count: count,
          parentPath: null,
        );
      }).toList(),
    );
  }

  static Future<List<MediaItem>> getMediaItems(
    String albumId, {
    int page = 0,
    int pageSize = 50,
  }) async {
    final path = await AssetPathEntity.fromId(albumId);
    if (pageSize == 0) return [];

    final assets = await path.getAssetListPaged(page: page, size: pageSize);

    return Future.wait(
      assets.map((asset) async {
        final file = await asset.file;
        return MediaItem(
          id: asset.id,
          name: asset.title ?? '',
          path: file?.path ?? '',
          source: MediaSource.local(),
          mimeType: asset.mimeType ?? 'image/jpeg',
          size: asset.size.width.toInt() * asset.size.height.toInt(),
          width: asset.width.toInt(),
          height: asset.height.toInt(),
          modifiedAt: asset.modifiedDateTime,
        );
      }).toList(),
    );
  }

  static Future<List<MediaItem>> getRecentPhotos({int count = 100}) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return [];

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
      onlyAll: true,
    );
    if (paths.isEmpty) return [];

    final allPath = paths.first;
    final total = await allPath.assetCountAsync;
    final assets = await allPath.getAssetListRange(
      start: 0,
      end: count.clamp(0, total),
    );

    return Future.wait(
      assets.map((asset) async {
        final file = await asset.file;
        return MediaItem(
          id: asset.id,
          name: asset.title ?? '',
          path: file?.path ?? '',
          source: MediaSource.local(),
          mimeType: asset.mimeType ?? 'image/jpeg',
          size: asset.size.width.toInt() * asset.size.height.toInt(),
          width: asset.width.toInt(),
          height: asset.height.toInt(),
          modifiedAt: asset.modifiedDateTime,
        );
      }).toList(),
    );
  }
}
