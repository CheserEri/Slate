import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/album_provider.dart';
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
                    : Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.image, color: Colors.white54),
                      ),
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
