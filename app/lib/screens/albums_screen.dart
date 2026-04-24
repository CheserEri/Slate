import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/album_provider.dart';
import '../providers/smb_provider.dart';
import '../widgets/glass_container.dart';
import 'photo_grid_screen.dart';

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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PhotoGridScreen(
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
                    '网络相册',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0x99FFFFFF),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => ref.read(smbServersProvider.notifier).load(),
                    icon: const Icon(Icons.refresh, size: 18, color: Color(0x99FFFFFF)),
                    label: const Text('刷新', style: TextStyle(color: Color(0x99FFFFFF))),
                  ),
                ],
              ),
            ),
          ),
          smbServers.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
            error: (err, _) => SliverToBoxAdapter(
              child: Center(child: Text('加载失败: $err', style: const TextStyle(color: Colors.white70))),
            ),
            data: (servers) {
              if (servers.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.cloud_off, size: 48, color: Colors.white24),
                          SizedBox(height: 12),
                          Text('暂无 SMB 服务器', style: TextStyle(color: Colors.white30)),
                        ],
                      ),
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
                      final server = servers[index];
                      return _AlbumCard(
                        name: server.name,
                        count: 0,
                        coverPath: null,
                        icon: Icons.computer,
                        onTap: () {
                          ref.read(selectedSmbServerProvider.notifier).state = server.id;
                          ref.read(smbCurrentPathProvider.notifier).state = '';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PhotoGridScreen(
                                albumId: server.id,
                                albumName: server.name,
                                isLocal: false,
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount: servers.length,
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
  final VoidCallback onTap;

  const _AlbumCard({
    required this.name,
    required this.count,
    this.coverPath,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
