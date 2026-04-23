import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/smb_provider.dart';

class SmbScreen extends ConsumerWidget {
  const SmbScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(smbServersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMB 服务器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddServerDialog(context, ref),
          ),
        ],
      ),
      body: servers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('加载失败: $err')),
        data: (list) {
          if (list.isEmpty) {
            return _EmptyState(onAdd: () => _showAddServerDialog(context, ref));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final server = list[index];
              return _ServerCard(
                server: server,
                onDelete: () => _confirmDelete(context, ref, server),
                onTest: () => _testConnection(context, ref, server),
                onBrowse: () => _browseServer(context, ref, server),
                onEdit: () => _showEditDialog(context, ref, server),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddServerDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final hostCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '445');
    final shareCtrl = TextEditingController();
    final rootPathCtrl = TextEditingController();
    final userCtrl = TextEditingController(text: 'guest');
    final passCtrl = TextEditingController();
    final domainCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加 SMB 服务器'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名称')),
              TextField(controller: hostCtrl, decoration: const InputDecoration(labelText: '主机')),
              TextField(controller: portCtrl, decoration: const InputDecoration(labelText: '端口'), keyboardType: TextInputType.number),
              TextField(controller: shareCtrl, decoration: const InputDecoration(labelText: '共享名')),
              TextField(controller: rootPathCtrl, decoration: const InputDecoration(labelText: '根路径 (可选)', hintText: '/')),
              TextField(controller: userCtrl, decoration: const InputDecoration(labelText: '用户名')),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: '密码'), obscureText: true),
              TextField(controller: domainCtrl, decoration: const InputDecoration(labelText: '域 (可选)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final config = SmbConfig(
                id: 'smb_${DateTime.now().millisecondsSinceEpoch}',
                name: nameCtrl.text,
                host: hostCtrl.text,
                port: int.tryParse(portCtrl.text) ?? 445,
                share: shareCtrl.text,
                rootPath: rootPathCtrl.text,
                username: userCtrl.text,
                password: passCtrl.text,
                domain: domainCtrl.text,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              await ref.read(smbServersProvider.notifier).addServer(config);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, SmbConfig server) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除服务器'),
        content: Text('确定要删除 "${server.name}" 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
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
        title: const Text('编辑 SMB 服务器'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名称')),
              TextField(controller: hostCtrl, decoration: const InputDecoration(labelText: '主机')),
              TextField(controller: portCtrl, decoration: const InputDecoration(labelText: '端口'), keyboardType: TextInputType.number),
              TextField(controller: shareCtrl, decoration: const InputDecoration(labelText: '共享名')),
              TextField(controller: rootPathCtrl, decoration: const InputDecoration(labelText: '根路径 (可选)', hintText: '/')),
              TextField(controller: userCtrl, decoration: const InputDecoration(labelText: '用户名')),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: '密码'), obscureText: true),
              TextField(controller: domainCtrl, decoration: const InputDecoration(labelText: '域 (可选)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
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

  Future<void> _testConnection(BuildContext context, WidgetRef ref, SmbConfig server) async {
    final result = await ref.read(smbServersProvider.notifier).testConnection(server.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result ? '连接成功' : '连接失败'),
          backgroundColor: result ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _browseServer(BuildContext context, WidgetRef ref, SmbConfig server) {
    ref.read(selectedSmbServerProvider.notifier).state = server.id;
    ref.read(smbCurrentPathProvider.notifier).state = '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SmbBrowserScreen(server: server),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('暂无 SMB 服务器', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('添加服务器'),
          ),
        ],
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  final SmbConfig server;
  final VoidCallback onDelete;
  final VoidCallback onTest;
  final VoidCallback onBrowse;
  final VoidCallback onEdit;

  const _ServerCard({
    required this.server,
    required this.onDelete,
    required this.onTest,
    required this.onBrowse,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.computer)),
        title: Text(server.name),
        subtitle: Text('${server.host}:${server.port}/${server.share}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'test') onTest();
            if (value == 'browse') onBrowse();
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'test', child: Text('测试连接')),
            const PopupMenuItem(value: 'browse', child: Text('浏览目录')),
            const PopupMenuItem(value: 'edit', child: Text('编辑')),
            const PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
      ),
    );
  }
}

class _SmbBrowserScreen extends ConsumerStatefulWidget {
  final SmbConfig server;
  const _SmbBrowserScreen({required this.server});

  @override
  ConsumerState<_SmbBrowserScreen> createState() => _SmbBrowserScreenState();
}

class _SmbBrowserScreenState extends ConsumerState<_SmbBrowserScreen> {
  final List<String> _pathStack = [''];

  String get _currentPath => _pathStack.last;

  void _pushPath(String name) {
    setState(() {
      _pathStack.add(_currentPath.isEmpty ? name : '$_currentPath/$name');
    });
    ref.read(smbCurrentPathProvider.notifier).state = _currentPath;
  }

  void _popPath() {
    if (_pathStack.length > 1) {
      setState(() {
        _pathStack.removeLast();
      });
      ref.read(smbCurrentPathProvider.notifier).state = _currentPath;
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(smbItemsProvider(widget.server.id));
    final albumsAsync = ref.watch(smbAlbumsProvider(widget.server.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPath.isEmpty ? widget.server.name : _currentPath.split('/').last),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_pathStack.length > 1) {
              _popPath();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Column(
        children: [
          if (_pathStack.length > 1)
            Padding(
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() => _pathStack.removeRange(1, _pathStack.length));
                        ref.read(smbCurrentPathProvider.notifier).state = '';
                      },
                      child: const Text('根目录'),
                    ),
                    for (int i = 1; i < _pathStack.length; i++) ...[
                      const Icon(Icons.chevron_right, size: 16),
                      TextButton(
                        onPressed: () {
                          setState(() => _pathStack.removeRange(i + 1, _pathStack.length));
                          ref.read(smbCurrentPathProvider.notifier).state = _currentPath;
                        },
                        child: Text(_pathStack[i].split('/').last),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          Expanded(
            child: albumsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('错误: $err')),
              data: (albums) {
                return itemsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('错误: $err')),
                  data: (items) {
                    return ListView(
                      children: [
                        if (albums.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text('文件夹', style: Theme.of(context).textTheme.titleSmall),
                          ),
                        ...albums.map((a) => ListTile(
                          leading: const Icon(Icons.folder),
                          title: Text(a.name),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _pushPath(a.name),
                        )),
                        if (items.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text('照片 (${items.length})', style: Theme.of(context).textTheme.titleSmall),
                          ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(2),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                          itemCount: items.length,
                          itemBuilder: (_, index) {
                            return Container(
                              color: Colors.grey[800],
                              child: const Icon(Icons.image, color: Colors.white54),
                            );
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
