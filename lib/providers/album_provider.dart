import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/local_photo_service.dart';

final localPhotoServiceProvider = Provider<LocalPhotoService>((ref) {
  return LocalPhotoService();
});

final localAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final service = ref.watch(localPhotoServiceProvider);
  return service.getAlbums();
});

final localAlbumsRefreshProvider = StateProvider<int>((ref) => 0);

final localAlbumsComputedProvider = FutureProvider<List<Album>>((ref) async {
  ref.watch(localAlbumsRefreshProvider);
  final service = ref.watch(localPhotoServiceProvider);
  return service.getAlbums();
});

final mediaItemsProvider = FutureProvider.family<List<MediaItem>, String>((
  ref,
  albumId,
) async {
  final service = ref.watch(localPhotoServiceProvider);
  return service.getMediaItems(albumId);
});

final selectedTabProvider = StateProvider<int>((ref) => 0);

final smbConfigsProvider = FutureProvider<List<SmbConfig>>((ref) async {
  return [];
});
