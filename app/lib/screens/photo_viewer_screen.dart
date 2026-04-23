import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/transfer_provider.dart';
import '../providers/smb_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:exif/exif.dart' as exif_pkg;
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class PhotoViewerScreen extends StatefulWidget {
  final List<MediaItem> photos;
  final int initialIndex;
  final bool isRemote;

  const PhotoViewerScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
    this.isRemote = false,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showUI = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showUI = !_showUI),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemCount: widget.photos.length,
              itemBuilder: (context, index) {
                final item = widget.photos[index];
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: widget.isRemote
                        ? _RemotePhotoViewer(serverId: _extractServerId(item.path), remotePath: item.path, name: item.name)
                        : Image.file(
                            File(item.path),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[900],
                              child: const Icon(Icons.broken_image, size: 64, color: Colors.white30),
                            ),
                          ),
                  ),
                );
              },
            ),
            AnimatedOpacity(
              opacity: _showUI ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),
            if (_showUI)
              SafeArea(
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            '${_currentIndex + 1} / ${widget.photos.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const Spacer(),
                    _BottomActionBar(
                      photo: photo,
                      isRemote: widget.isRemote,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomActionBar extends ConsumerWidget {
  final MediaItem photo;
  final bool isRemote;

  const _BottomActionBar({required this.photo, required this.isRemote});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(smbServersProvider).valueOrNull ?? [];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.share,
            label: '分享',
            onTap: () => _sharePhoto(context),
          ),
          if (!isRemote && servers.isNotEmpty)
            _ActionButton(
              icon: Icons.cloud_upload,
              label: '备份',
              onTap: () => _backup(context, ref, servers.first.id),
            ),
          if (isRemote)
            _ActionButton(
              icon: Icons.download,
              label: '下载',
              onTap: () => _downloadRemote(context),
            ),
          _ActionButton(
            icon: Icons.info_outline,
            label: '信息',
            onTap: () => _showInfo(context),
          ),
        ],
      ),
    );
  }

  void _backup(BuildContext context, WidgetRef ref, String serverId) {
    ref.read(transfersProvider.notifier).backupPhotos(
          serverId,
          [photo.path],
          '/SlateBackup',
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已加入备份队列')),
    );
  }

  Future<void> _sharePhoto(BuildContext context) async {
    try {
      if (isRemote) {
        final serverId = _extractServerId(photo.path);
        final url = await ApiService().previewSmbFileUrl(serverId, photo.path);
        await Share.share(url, subject: photo.name);
      } else {
        await Share.shareXFiles([XFile(photo.path)], text: photo.name);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  Future<void> _downloadRemote(BuildContext context) async {
    try {
      final serverId = _extractServerId(photo.path);
      final dir = Directory('/storage/emulated/0/Download/Slate');
      await dir.create(recursive: true);
      final savePath = '${dir.path}/${photo.name}';
      await ApiService().downloadSmbFileToLocal(serverId, photo.path, savePath);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已保存到 Downloads/Slate/${photo.name}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }

  String _extractServerId(String path) {
    return path.split('/').first;
  }

  void _showInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      builder: (_) => _ExifInfoSheet(photo: photo, isRemote: isRemote),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RemotePhotoViewer extends StatefulWidget {
  final String serverId;
  final String remotePath;
  final String name;
  const _RemotePhotoViewer({required this.serverId, required this.remotePath, required this.name});

  @override
  State<_RemotePhotoViewer> createState() => _RemotePhotoViewerState();
}

class _RemotePhotoViewerState extends State<_RemotePhotoViewer> {
  String? _url;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final url = await ApiService().previewSmbFileUrl(widget.serverId, widget.remotePath);
      if (mounted) setState(() { _url = url; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: Colors.grey[900],
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_url == null) {
      return Container(
        color: Colors.grey[900],
        child: const Icon(Icons.broken_image, size: 64, color: Colors.white30),
      );
    }
    return Image.network(
      _url!,
      fit: BoxFit.contain,
      headers: const {'Accept': 'image/*'},
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Colors.grey[900],
          child: const Center(child: CircularProgressIndicator()),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey[900],
        child: const Icon(Icons.broken_image, size: 64, color: Colors.white30),
      ),
    );
  }
}

class _ExifInfoSheet extends StatefulWidget {
  final MediaItem photo;
  final bool isRemote;
  const _ExifInfoSheet({required this.photo, required this.isRemote});

  @override
  State<_ExifInfoSheet> createState() => _ExifInfoSheetState();
}

class _ExifInfoSheetState extends State<_ExifInfoSheet> {
  Map<String, dynamic>? _exif;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExif();
  }

  Future<void> _loadExif() async {
    try {
      if (!widget.isRemote) {
        final fileBytes = await File(widget.photo.path).readAsBytes();
        final data = await exif_pkg.readExifFromBytes(fileBytes);
        _exif = data.map((k, v) => MapEntry(k, v.toString()));
      } else {
        final serverId = widget.photo.path.split('/').first;
        final url = await ApiService().previewSmbFileUrl(serverId, widget.photo.path);
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = await exif_pkg.readExifFromBytes(response.bodyBytes);
          _exif = data.map((k, v) => MapEntry(k, v.toString()));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (_, controller) {
        return Container(
          color: Colors.grey[900],
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: controller,
            children: [
              Text('文件信息', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
              const SizedBox(height: 12),
              _InfoRow('名称', widget.photo.name),
              _InfoRow('路径', widget.photo.path),
              _InfoRow('大小', _formatSize(widget.photo.size)),
              _InfoRow('类型', widget.photo.mimeType),
              _InfoRow('时间', widget.photo.modifiedAt.toString()),
              _InfoRow('分辨率', '${widget.photo.width} x ${widget.photo.height}'),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_exif != null && _exif!.isNotEmpty) ...[
                Text('EXIF', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 8),
                ..._exif!.entries.take(20).map((e) => _InfoRow(e.key, e.value)),
              ] else
                const Text('无 EXIF 数据', style: TextStyle(color: Colors.grey)),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
