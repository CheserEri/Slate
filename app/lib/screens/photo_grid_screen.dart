import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/album_provider.dart';
import '../providers/smb_provider.dart';
import '../services/smb_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/animations.dart';
import 'photo_viewer_screen.dart';

class PhotoGridScreen extends ConsumerStatefulWidget {
  final String albumId;
  final String albumName;
  final bool isLocal;
  final bool isSettingCover;
  final String? albumPath;

  const PhotoGridScreen({
    super.key,
    required this.albumId,
    required this.albumName,
    required this.isLocal,
    this.isSettingCover = false,
    this.albumPath,
  });

  @override
  ConsumerState<PhotoGridScreen> createState() => _PhotoGridScreenState();
}

class _PhotoGridScreenState extends ConsumerState<PhotoGridScreen> {
  String? _selectedPhotoName; // 仅保存文件名

  @override
  void initState() {
    super.initState();
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
              final isSelected = _selectedPhotoName == item.name;
              return BounceTap(
                onTap: widget.isSettingCover
                    ? () {
                        setState(() {
                          if (isSelected) {
                            _selectedPhotoName = null;
                          } else {
                            _selectedPhotoName = item.name;
                          }
                        });
                      }
                    : () {
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
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: Colors.blueAccent, width: 3)
                        : null,
                  ),
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
                        : _RemoteImage(
                            serverId: widget.albumId,
                            remotePath: item.path,
                          ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: widget.isSettingCover && _selectedPhotoName != null
          ? FloatingActionButton.extended(
              onPressed: () async {
                if (widget.albumPath == null) return;
                try {
                  final smbService = SmbService();
                  final coverPath = widget.albumPath!.isEmpty
                      ? _selectedPhotoName!
                      : '${widget.albumPath}/$_selectedPhotoName!';
                  await smbService.setCustomCover(
                    widget.albumId,
                    widget.albumPath!,
                    coverPath,
                  );
                  if (mounted) {
                    Navigator.pop(context, coverPath);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('设置失败: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('设为封面'),
              backgroundColor: Colors.blueAccent,
            )
          : null,
    );
  }
}

class _RemoteImage extends StatefulWidget {
  final String serverId;
  final String remotePath;

  const _RemoteImage({
    required this.serverId,
    required this.remotePath,
  });

  @override
  State<_RemoteImage> createState() => _RemoteImageState();
}

class _RemoteImageState extends State<_RemoteImage> {
  Uint8List? _imageData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final servers = await LocalStorageService().getSmbServers();
      final server = servers.firstWhere((s) => s.id == widget.serverId);
      final data = await SmbService().readFile(server, widget.remotePath);
      if (mounted) {
        setState(() {
          _imageData = data;
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
    if (_imageData == null) {
      return Container(
        color: const Color(0xFF1A1A2E),
        child: const Icon(Icons.broken_image, color: Colors.white24),
      );
    }
    return Image.memory(
      _imageData!,
      fit: BoxFit.cover,
      cacheWidth: 400,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF1A1A2E),
        child: const Icon(Icons.broken_image, color: Colors.white24),
      ),
    );
  }
}