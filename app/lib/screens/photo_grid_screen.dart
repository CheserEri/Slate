import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/album_provider.dart';
import '../providers/smb_provider.dart';
import '../services/api_service.dart';
import '../widgets/glass_container.dart';
import '../widgets/animations.dart';
import 'photo_viewer_screen.dart';

class PhotoGridScreen extends ConsumerStatefulWidget {
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
  ConsumerState<PhotoGridScreen> createState() => _PhotoGridScreenState();
}

class _PhotoGridScreenState extends ConsumerState<PhotoGridScreen> {
  @override
  void initState() {
    super.initState();
    // FutureProvider auto-loads on watch, no need to manually trigger
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = widget.isLocal
        ? ref.watch(albumItemsProvider(widget.albumId))
        : ref.watch(smbItemsProvider(widget.albumId));

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.albumName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: itemsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (err, _) => Center(
          child: Text('加载失败: $err', style: const TextStyle(color: Colors.white70)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('暂无照片', style: TextStyle(color: Colors.white38)),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 100, 16, 120),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return BounceTap(
                onTap: () {
                  Navigator.push(
                    context,
                    PageFadeTransition(
                      child: PhotoViewerScreen(
                        photos: items,
                        initialIndex: index,
                        isRemote: !widget.isLocal,
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: widget.isLocal
                      ? Image.file(
                          File(item.path),
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF1A1A2E),
                            child: const Icon(Icons.image, color: Colors.white24),
                          ),
                        )
                      : PhotoFadeIn(
                        child: _RemoteImage(
                          serverId: widget.albumId,
                          remotePath: item.path,
                          name: item.name,
                        ),
                      ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RemoteImage extends StatefulWidget {
  final String serverId;
  final String remotePath;
  final String name;

  const _RemoteImage({
    required this.serverId,
    required this.remotePath,
    required this.name,
  });

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
        color: const Color(0xFF1A1A2E),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }
    if (_url == null) {
      return Container(
        color: const Color(0xFF1A1A2E),
        child: const Icon(Icons.broken_image, color: Colors.white24),
      );
    }
    return Image.network(
      _url!,
      fit: BoxFit.cover,
      headers: const {'Accept': 'image/*'},
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFF1A1A2E),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF1A1A2E),
        child: const Icon(Icons.broken_image, color: Colors.white24),
      ),
    );
  }
}
