import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

class SmbServer {
  final String host;
  final int port;
  final String share;
  final String username;
  final String password;

  SmbServer({
    required this.host,
    required this.port,
    required this.share,
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'share': share,
    'username': username,
    'password': password,
  };
}

class SmbPhotoService {
  final Ref ref;

  SmbPhotoService(this.ref);

  Future<bool> testConnection(SmbServer server) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  Future<List<Album>> getAlbums(SmbServer server) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [];
  }

  Future<List<MediaItem>> getMediaItems(SmbServer server, String path) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [];
  }
}

final smbPhotoServiceProvider = Provider<SmbPhotoService>((ref) {
  return SmbPhotoService(ref);
});

final smbServersProvider =
    StateNotifierProvider<SmbServersNotifier, List<SmbServer>>((ref) {
      return SmbServersNotifier();
    });

class SmbServersNotifier extends StateNotifier<List<SmbServer>> {
  SmbServersNotifier() : super([]);

  void addServer(SmbServer server) {
    state = [...state, server];
  }

  void removeServer(int index) {
    state = [...state]..removeAt(index);
  }
}

final selectedSmbIndexProvider = StateProvider<int?>((ref) => null);

final currentSmbAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final index = ref.watch(selectedSmbIndexProvider);
  final servers = ref.watch(smbServersProvider);

  if (index == null || index >= servers.length) return [];

  final service = ref.watch(smbPhotoServiceProvider);
  return service.getAlbums(servers[index]);
});
