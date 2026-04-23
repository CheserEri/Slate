import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/api_service.dart';

final smbServersProvider =
    StateNotifierProvider<SmbServersNotifier, AsyncValue<List<SmbConfig>>>(
  (ref) => SmbServersNotifier(),
);

class SmbServersNotifier extends StateNotifier<AsyncValue<List<SmbConfig>>> {
  SmbServersNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final servers = await ApiService().fetchSmbServers();
      state = AsyncValue.data(servers);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addServer(SmbConfig config) async {
    await ApiService().addSmbServer(config);
    await load();
  }

  Future<void> deleteServer(String id) async {
    await ApiService().deleteSmbServer(id);
    await load();
  }

  Future<bool> testConnection(String id) async {
    return await ApiService().testSmbConnection(id);
  }
}

final selectedSmbServerProvider = StateProvider<String?>((ref) => null);
final smbCurrentPathProvider = StateProvider<String>((ref) => '');

final smbAlbumsProvider = FutureProvider.family<List<Album>, String>(
  (ref, serverId) async {
    final path = ref.watch(smbCurrentPathProvider);
    return await ApiService().fetchSmbAlbums(serverId, path: path);
  },
);

final smbItemsProvider = FutureProvider.family<List<MediaItem>, String>(
  (ref, serverId) async {
    final path = ref.watch(smbCurrentPathProvider);
    return await ApiService().fetchSmbItems(serverId, path: path);
  },
);
