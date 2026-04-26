import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/album_provider.dart';
import '../models/models.dart';import '../providers/smb_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/animations.dart';
import 'photo_grid_screen.dart';
import '../services/smb_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/smb_image_widget.dart';

/// SMB 远程图片加载Widget

class SmbRemoteImageState extends State<SmbRemoteImage> {
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

class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localAlbums = ref.watch(localAlbumsProvider);
    final smbServers = ref.watch(smbServersProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                '相册',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1.2,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  const Text(
                    '本地相册',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0x99FFFFFF),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => ref.read(localAlbumsProvider.notifier).load(),
                    icon: const Icon(Icons.refresh, size: 18, color: Color(0x99FFFFFF)),
                    label: const Text('刷新', style: TextStyle(color: Color(0x99FFFFFF))),
                  ),
                ],
              ),
            ),
          ),
          localAlbums.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(child: Text('加载失败: $err', style: const TextStyle(color: Colors.white70))),
            ),
            data: (albums) => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final album = albums[index];
                    return _AlbumCard(
                      name: album.name,
                      count: album.count,
                      coverPath: album.coverPath,
                      source: album.source,
                      onTap: () {
                        Navigator.push(
                          context,
                          PageFadeTransition(
                            child: PhotoGridScreen(
                              albumId: album.id,
                              albumName: album.name,
                              isLocal: true,
                            ),
                          ),
                        );
                      },
                    );
                  },
                  childCount: albums.length,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  const Text(
                    'SMB 相册',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0x99FFFFFF),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () { ref.invalidate(allSmbAlbumsProvider); },
                    icon: const Icon(Icons.refresh, size: 18, color: Color(0x99FFFFFF)),
                    label: const Text('刷新', style: TextStyle(color: Color(0x99FFFFFF))),
                  ),
                ],
              ),
            ),
          ),
          ref.watch(allSmbAlbumsProvider).when(
            loading: () => const SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
            error: (err, _) => SliverToBoxAdapter(
              child: Center(child: Text('加载失败: $err', style: const TextStyle(color: Colors.white70))),
            ),
            data: (albums) {
              if (albums.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: EmptyStateWidget(
                      icon: Icons.folder_off,
                      title: '暂无线 SMB 相册',
                      subtitle: '请检查服务器 rootPath 设置是否正确',
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final album = albums[index];
                      final serverId = album.source is SmbSource
                          ? (album.source as SmbSource).serverId
                          : '';
                      return _AlbumCard(
                        name: album.name,
                        count: album.count,
                        coverPath: album.coverPath,
                        source: album.source,
                        onTap: () {
                          if (serverId.isNotEmpty) {
                            ref.read(selectedSmbServerProvider.notifier).state = serverId;
                            ref.read(smbCurrentPathProvider.notifier).state = album.id;
                            Navigator.push(
                              context,
                              PageFadeTransition(
                                child: PhotoGridScreen(
                                  albumId: serverId,
                                  albumName: album.name,
                                  isLocal: false,
                                ),
                              ),
                            );
                          }
                        },
                        onLongPress: serverId.isNotEmpty
                            ? () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('设置自定义封面'),
                                    content: Text('为相册 "${album.name}" 选择一张照片作为封面？'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('取消'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('选择照片'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;

                                final result = await Navigator.push(
                                    context,
                                    PageFadeTransition(
                                      child: PhotoGridScreen(
                                        albumId: serverId,
                                        albumName: album.name,
                                        isLocal: false,
                                        isSettingCover: true,
                                        albumPath: album.id,
                                      ),
                                    ),
                                );
                                if (result != null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('封面已更新'), duration: Duration(seconds: 1)),
                                  );
                                  // 相册列表会自动刷新（getAlbums 会读取新的自定义封面）
                                }
                              }
                            : null,
                      );
                    },
                    childCount: albums.length,
                  ),
                ),
              );
            },
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final String name;
  final int count;
  final String? coverPath;
  final IconData? icon;
  final MediaSource source;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _AlbumCard({
    required this.name,
    required this.count,
    this.coverPath,
    this.icon,
    required this.source,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return BounceTap(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: -5,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverPath != null)
                if (source is SmbSource)
                  SmbRemoteImage(
                    serverId: (source as SmbSource).serverId,
                    remotePath: coverPath!,
                  )
                else
                  Image.file(
                    File(coverPath!),
                    fit: BoxFit.cover,
                    cacheWidth: 400,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
              else
                _placeholder(),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (count > 0)
                      Text(
                        '$count 张',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: Icon(icon ?? Icons.folder, size: 40, color: Colors.white.withValues(alpha: 0.12)),
      ),
    );
  }
}
