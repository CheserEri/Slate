import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/photo_service.dart';

final localAlbumsProvider =
    StateNotifierProvider<LocalAlbumsNotifier, AsyncValue<List<Album>>>(
  (ref) => LocalAlbumsNotifier(),
);

class LocalAlbumsNotifier extends StateNotifier<AsyncValue<List<Album>>> {
  LocalAlbumsNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final albums = await PhotoService.getLocalAlbums();
      state = AsyncValue.data(albums);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final albumItemsProvider = FutureProvider.family<List<MediaItem>, String>(
  (ref, albumId) async {
    return await PhotoService.getMediaItems(albumId);
  },
);
