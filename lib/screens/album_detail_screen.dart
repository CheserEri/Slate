import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/album_provider.dart';
import '../models/models.dart';
import 'media_viewer_screen.dart';

class AlbumDetailScreen extends ConsumerStatefulWidget {
  final Album album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  ConsumerState<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends ConsumerState<AlbumDetailScreen> {
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(mediaItemsProvider(widget.album.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedIds.length} selected'
              : widget.album.name,
        ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _selectAll,
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _selectedIds.isNotEmpty ? _downloadSelected : null,
            ),
          ] else
            IconButton(icon: const Icon(Icons.grid_view), onPressed: () {}),
        ],
      ),
      body: mediaAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text('No photos in this album'),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = _selectedIds.contains(item.id);

              return GestureDetector(
                onLongPress: () {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedIds.add(item.id);
                  });
                },
                onTap: () {
                  if (_isSelectionMode) {
                    setState(() {
                      if (isSelected) {
                        _selectedIds.remove(item.id);
                        if (_selectedIds.isEmpty) _isSelectionMode = false;
                      } else {
                        _selectedIds.add(item.id);
                      }
                    });
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MediaViewerScreen(
                          items: items,
                          initialIndex: index,
                        ),
                      ),
                    );
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildThumbnail(item),
                    if (_isSelectionMode)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSelected ? Icons.check : null,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: _isSelectionMode && _selectedIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _downloadSelected,
              icon: const Icon(Icons.download),
              label: Text('Download (${_selectedIds.length})'),
            )
          : null,
    );
  }

  Widget _buildThumbnail(MediaItem item) {
    if (item.source is LocalSource) {
      return Image.file(
        File(item.path),
        fit: BoxFit.cover,
        cacheWidth: 200,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image)),
      );
    }

    return Container(
      color: Colors.grey[200],
      child: const Center(child: Icon(Icons.image)),
    );
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll() {
    // TODO: implement select all
  }

  void _downloadSelected() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Download ${_selectedIds.length} items')),
    );
    _exitSelectionMode();
  }
}
