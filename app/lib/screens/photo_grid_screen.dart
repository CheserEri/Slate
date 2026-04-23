import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/album_provider.dart';
import '../services/api_service.dart';
import '../providers/smb_provider.dart';
import 'photo_viewer_screen.dart';

class PhotoGridScreen extends ConsumerWidget {
  final String albumId;
  final String albumName;
  final bool isLocal;

  const PhotoGridScreen({
    super.key,
    required this.albumId,
    required this.albumName,
    required this.isLocal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = isLocal
        ? ref.watch(albumItemsProvider(albumId))
        : ref.watch(smbItemsProvider(albumId));

    return Scaffold(
      appBar: AppBar(title: Text(albumName)),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('加载失败: $err')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('暂无照片'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotoViewerScreen(
                        photos: items,
                        initialIndex: index,
                        isRemote: !isLocal,
                      ),
                    ),
                  );
                },
                child: isLocal
                    ? Image.file(
                        File(item.path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallback(),
                      )
                    : _RemoteImage(serverId: albumId, remotePath: item.path, name: item.name),
              );
            },
          );
        },
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: Colors.grey[800],
      child: const Icon(Icons.broken_image, color: Colors.white54),
    );
  }
}

class _RemoteImage extends StatefulWidget {
  final String serverId;
  final String remotePath;
  final String name;
  const _RemoteImage({required this.serverId, required this.remotePath, required this.name});

  @override
  State<_RemoteImage> createState() => _RemoteImageState();
}

class _RemoteImageState extends State<_RemoteImage> {
  String? _url;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      final url = await ApiService().previewSmbFileUrl(widget.serverId, widget.remotePath);
      if (mounted) {
        setState(() {
          _url = url;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: Colors.grey[800],
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_url == null) {
      return Container(
        color: Colors.grey[800],
        child: const Icon(Icons.broken_image, color: Colors.white54),
      );
    }
    return Image.network(
      _url!,
      fit: BoxFit.cover,
      headers: const {'Accept': 'image/*'},
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Colors.grey[800],
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey[800],
        child: const Icon(Icons.broken_image, color: Colors.white54),
      ),
    );
  }
}
