import 'dart:io';
import 'package:flutter/material.dart';
import '../models/models.dart';

class MediaViewerScreen extends StatefulWidget {
  final List<MediaItem> items;
  final int initialIndex;

  const MediaViewerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  final TransformationController _transformController =
      TransformationController();
  bool _showAppBar = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showAppBar
          ? AppBar(
              backgroundColor: Colors.black54,
              title: Text('${_currentIndex + 1} / ${widget.items.length}'),
              actions: [
                IconButton(icon: const Icon(Icons.share), onPressed: _share),
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: _download,
                ),
                PopupMenuButton<String>(
                  onSelected: _onMenuSelected,
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'info', child: Text('Info')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            )
          : null,
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return GestureDetector(
            onTap: () => setState(() => _showAppBar = !_showAppBar),
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(child: _buildImage(item)),
            ),
          );
        },
      ),
      bottomNavigationBar: _showAppBar ? _buildBottomBar() : null,
    );
  }

  Widget _buildImage(MediaItem item) {
    if (item.source is LocalSource) {
      return Image.file(
        File(item.path),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Failed to load image', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Container(
      color: Colors.grey[900],
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildBottomBar() {
    final item = widget.items[_currentIndex];
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.name,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${item.width} x ${item.height}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  _formatSize(item.size),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void _share() {}
  void _download() {}
  void _onMenuSelected(String value) {}
}
