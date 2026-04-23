import 'package:photo_manager/photo_manager.dart';
import '../models/models.dart';

class LocalPhotoService {
  Future<bool> requestPermission() async {
    final result = await PhotoManager.requestPermissionExtend();
    return result.isAuth;
  }

  Future<List<Album>> getAlbums() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
    );

    return Future.wait(
      albums.map((path) async {
        final count = await path.assetCountAsync;
        final firstAsset = count > 0
            ? (await path.getAssetListRange(start: 0, end: 1)).firstOrNull
            : null;
        String? coverPath;
        if (firstAsset != null) {
          final file = await firstAsset.file;
          coverPath = file?.path;
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

  Future<List<MediaItem>> getMediaItems(
    String albumId, {
    int page = 0,
    int pageSize = 50,
  }) async {
    final path = await AssetPathEntity.fromId(albumId);
    if (path == null || pageSize == 0) return [];

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
}
