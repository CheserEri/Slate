import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/smb_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/animations.dart';
import 'photo_grid_screen.dart';

class SmbScreen extends ConsumerWidget {
  const SmbScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serversAsync = ref.watch(smbServersProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  const Text(
                    'SMB 服务器',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                    onPressed: () => _showAddDialog(context, ref),
                  ),
                ],
              ),
            ),
          ),
          serversAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(
                child: Text('加载失败: $err', style: const TextStyle(color: Colors.white70)),
              ),
            ),
            data: (servers) {
              if (servers.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off, size: 64, color: Colors.white24),
                        SizedBox(height: 16),
                        Text('暂无 SMB 服务器', style: TextStyle(color: Colors.white38)),
                        const SizedBox(height: 8),
                        Text('点击右上角添加', style: TextStyle(color: Colors.white24, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final server = servers[index];
                    return FadeSlideIn(
                      index: index,
                      child: StatusCard(
                      statusColor: const Color(0xFF60A5FA),
                      onTap: () {
                        ref.read(selectedSmbServerProvider.notifier).state = server.id;
                        ref.read(smbCurrentPathProvider.notifier).state = '';
                        Navigator.push(
                          context,
                          PageFadeTransition(
                            child: PhotoGridScreen(
                              albumId: server.id,
                              albumName: server.name,
                              isLocal: false,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF60A5FA).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.computer, color: Color(0xFF60A5FA), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    server.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${server.host}:${server.port}/${server.share}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                              color: const Color(0xFF0F172A),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'test', child: Text('测试连接', style: TextStyle(color: Colors.white))),
                                const PopupMenuItem(value: 'browse', child: Text('浏览目录', style: TextStyle(color: Colors.white))),
                                const PopupMenuItem(value: 'edit', child: Text('编辑', style: TextStyle(color: Colors.white))),
                                const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Color(0xFFF87171)))),
                              ],
                              onSelected: (value) {
                                if (value == 'test') _testConnection(context, ref, server);
                                if (value == 'browse') {
                                  ref.read(selectedSmbServerProvider.notifier).state = server.id;
                                  ref.read(smbCurrentPathProvider.notifier).state = '';
                                  Navigator.push(
                                    context,
                                    PageFadeTransition(
                                      child: PhotoGridScreen(
                                        albumId: server.id,
                                        albumName: server.name,
                                        isLocal: false,
                                      ),
                                    ),
                                  );
                                }
                                if (value == 'edit') _showEditDialog(context, ref, server);
                                if (value == 'delete') _confirmDelete(context, ref, server);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                  },
                  childCount: servers.length,
                ),
              );
            },
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final hostCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '445');
    final shareCtrl = TextEditingController();
    final rootPathCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final domainCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('添加 SMB 服务器', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField(nameCtrl, '名称', hint: '我的NAS'),
              _buildField(hostCtrl, '主机', hint: '192.168.1.100'),
              _buildField(portCtrl, '端口', keyboard: TextInputType.number, hint: '445'),
              _buildField(shareCtrl, '共享名', hint: 'Photos'),
              _buildField(rootPathCtrl, '根路径 (可选)', hint: '留空表示共享根目录'),
              _buildField(userCtrl, '用户名', hint: 'admin'),
              _buildField(passCtrl, '密码', obscure: true, hint: '可选'),
              _buildField(domainCtrl, '域 (可选)', hint: 'WORKGROUP'),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '提示：主机可填 IP 或主机名，如 nas.local',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () async {
              final config = SmbConfig(
                id: '',
                name: nameCtrl.text,
                host: hostCtrl.text,
                port: int.tryParse(portCtrl.text) ?? 445,
                share: shareCtrl.text,
                rootPath: rootPathCtrl.text,
                username: userCtrl.text,
                password: passCtrl.text.isEmpty ? null : passCtrl.text,
                domain: domainCtrl.text,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              await ref.read(smbServersProvider.notifier).addServer(config);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, SmbConfig server) {
    final nameCtrl = TextEditingController(text: server.name);
    final hostCtrl = TextEditingController(text: server.host);
    final portCtrl = TextEditingController(text: server.port.toString());
    final shareCtrl = TextEditingController(text: server.share);
    final rootPathCtrl = TextEditingController(text: server.rootPath);
    final userCtrl = TextEditingController(text: server.username);
    final passCtrl = TextEditingController(text: server.password ?? '');
    final domainCtrl = TextEditingController(text: server.domain);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('编辑 SMB 服务器', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField(nameCtrl, '名称', hint: '我的NAS'),
              _buildField(hostCtrl, '主机', hint: '192.168.1.100'),
              _buildField(portCtrl, '端口', keyboard: TextInputType.number, hint: '445'),
              _buildField(shareCtrl, '共享名', hint: 'Photos'),
              _buildField(rootPathCtrl, '根路径 (可选)', hint: '留空表示共享根目录'),
              _buildField(userCtrl, '用户名', hint: 'admin'),
              _buildField(passCtrl, '密码', obscure: true, hint: '可选'),
              _buildField(domainCtrl, '域 (可选)', hint: 'WORKGROUP'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () async {
              final updated = server.copyWith(
                name: nameCtrl.text,
                host: hostCtrl.text,
                port: int.tryParse(portCtrl.text) ?? 445,
                share: shareCtrl.text,
                rootPath: rootPathCtrl.text,
                username: userCtrl.text,
                password: passCtrl.text.isEmpty ? null : passCtrl.text,
                domain: domainCtrl.text,
                updatedAt: DateTime.now(),
              );
              await ref.read(smbServersProvider.notifier).updateServer(server.id, updated);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    TextInputType? keyboard,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Color(0x99FFFFFF)),
          hintStyle: const TextStyle(color: Color(0x61FFFFFF)),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Future<void> _testConnection(BuildContext context, WidgetRef ref, SmbConfig server) async {
    final ok = await ref.read(smbServersProvider.notifier).testConnection(server.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '连接成功' : '连接失败'),
          backgroundColor: ok ? const Color(0xFF34D399) : const Color(0xFFF87171),
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, SmbConfig server) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('删除服务器', style: TextStyle(color: Colors.white)),
        content: Text('确定删除 "${server.name}" 吗？', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF87171)),
            onPressed: () async {
              await ref.read(smbServersProvider.notifier).deleteServer(server.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
