import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/photo_provider.dart';
import '../providers/smb_provider.dart';
import '../providers/transfer_provider.dart';
import '../services/photo_service.dart';
import '../widgets/glass_container.dart';
import 'photo_viewer_screen.dart';

class PhotosScreen extends ConsumerStatefulWidget {
  const PhotosScreen({super.key});

  @override
  ConsumerState<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends ConsumerState<PhotosScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final granted = await PhotoService.requestPermission();
    if (granted) {
      ref.read(localPhotosProvider.notifier).load();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photosAsync = ref.watch(localPhotosProvider);
    final isMultiSelect = ref.watch(isMultiSelectProvider);
    final selected = ref.watch(selectedPhotosProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isMultiSelect
          ? AppBar(
              title: Text(
                '已选择 ${selected.length} 项',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.black.withValues(alpha: 0.7),
              actions: [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: () {
                    final photos = ref.read(localPhotosProvider).valueOrNull ?? [];
                    ref.read(selectedPhotosProvider.notifier).state =
                        photos.map((p) => p.id).toSet();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => toggleMultiSelect(ref),
                ),
              ],
            )
          : null,
      body: photosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (err, _) => Center(
          child: Text('加载失败: $err', style: const TextStyle(color: Colors.white70)),
        ),
        data: (photos) {
          if (photos.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('暂无照片', style: TextStyle(color: Colors.white38, fontSize: 16)),
                ],
              ),
            );
          }
          final grouped = _groupByDate(photos);
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 顶部留白（状态栏下方）
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              // 大标题
              if (!isMultiSelect)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 40, 20, 8),
                    child: Text(
                      '照片',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1.2,
                      ),
                    ),
                  ),
                ),
              for (final entry in grouped.entries) ...[
                SliverToBoxAdapter(
                  child: MagazineDateHeader(_formatDateHeader(entry.key)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final photo = entry.value[index];
                        final isSelected = selected.contains(photo.id);
                        return _PhotoTile(
                          photo: photo,
                          isMultiSelect: isMultiSelect,
                          isSelected: isSelected,
                          onTap: () {
                            if (isMultiSelect) {
                              togglePhotoSelection(ref, photo.id);
                              HapticFeedback.lightImpact();
                            } else {
                              _openViewer(photos, photo);
                            }
                          },
                          onLongPress: () {
                            if (!isMultiSelect) {
                              toggleMultiSelect(ref);
                              togglePhotoSelection(ref, photo.id);
                              HapticFeedback.mediumImpact();
                            }
                          },
                        );
                      },
                      childCount: entry.value.length,
                    ),
                  ),
                ),
              ],
              const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
            ],
          );
        },
      ),
      bottomSheet: isMultiSelect && selected.isNotEmpty
          ? _MultiSelectBottomBar(
              selectedCount: selected.length,
              onBackup: () => _showBackupDialog(selected.toList()),
              onClear: () {
                ref.read(selectedPhotosProvider.notifier).state = {};
              },
            )
          : null,
    );
  }

  Map<DateTime, List<MediaItem>> _groupByDate(List<MediaItem> photos) {
    final map = <DateTime, List<MediaItem>>{};
    for (final photo in photos) {
      final date = DateTime(
        photo.modifiedAt.year,
        photo.modifiedAt.month,
        photo.modifiedAt.day,
      );
      map.putIfAbsent(date, () => []).add(photo);
    }
    final sorted = Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
    return sorted;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == today) return '今天';
    if (date == yesterday) return '昨天';
    return DateFormat('yyyy年M月d日 EEEE', 'zh_CN').format(date);
  }

  void _openViewer(List<MediaItem> photos, MediaItem initial) {
    final index = photos.indexWhere((p) => p.id == initial.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          photos: photos,
          initialIndex: index,
        ),
      ),
    );
  }

  void _showBackupDialog(List<String> photoIds) {
    final photos = ref.read(localPhotosProvider).valueOrNull ?? [];
    final paths = photoIds
        .map((id) => photos.firstWhere((p) => p.id == id).path)
        .where((p) => p.isNotEmpty)
        .toList();

    final serversAsync = ref.read(smbServersProvider);
    final servers = serversAsync.valueOrNull ?? [];

    if (servers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加 SMB 服务器')),
      );
      return;
    }

    String? selectedServer = ref.read(defaultServerProvider);
    if (selectedServer == null || !servers.any((s) => s.id == selectedServer)) {
      selectedServer = servers.first.id;
    }
    var remoteDir = ref.read(defaultBackupPathProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '备份到 SMB',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 20),
                  Text('选择服务器', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: servers.map((s) {
                      return ChoiceChip(
                        label: Text(s.name),
                        selected: selectedServer == s.id,
                        onSelected: (_) => setState(() => selectedServer = s.id),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text('远程目录', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 10),
                  TextField(
                    controller: TextEditingController(text: remoteDir),
                    onChanged: (v) => remoteDir = v,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '/SlateBackup',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('共 ${paths.length} 张照片',
                      style: const TextStyle(color: Colors.white60)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        ref.read(transfersProvider.notifier).backupPhotos(
                              selectedServer!,
                              paths,
                              remoteDir,
                            );
                        ref.read(defaultServerProvider.notifier).state =
                            selectedServer;
                        ref.read(defaultBackupPathProvider.notifier).state =
                            remoteDir;
                        Navigator.pop(context);
                        toggleMultiSelect(ref);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已开始备份')),
                        );
                      },
                      child: const Text('开始备份'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final MediaItem photo;
  final bool isMultiSelect;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PhotoTile({
    required this.photo,
    required this.isMultiSelect,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(photo.path),
              fit: BoxFit.cover,
              cacheWidth: 400,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF1A1A2E),
                child: const Icon(Icons.image, color: Colors.white24),
              ),
            ),
          ),
          if (isMultiSelect)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: isSelected
                    ? Colors.black.withValues(alpha: 0.45)
                    : Colors.transparent,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: AnimatedScale(
                      scale: isSelected ? 1.0 : 0.85,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.6),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MultiSelectBottomBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onBackup;
  final VoidCallback onClear;

  const _MultiSelectBottomBar({
    required this.selectedCount,
    required this.onBackup,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(20),
      blur: 24,
      tint: Colors.black.withValues(alpha: 0.6),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onBackup,
                  icon: const Icon(Icons.cloud_upload, size: 20),
                  label: Text('备份 ($selectedCount)'),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.clear_all),
                tooltip: '清除选择',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
