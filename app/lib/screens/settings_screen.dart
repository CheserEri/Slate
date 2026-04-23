import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const _SectionHeader('外观'),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('主题模式'),
            subtitle: Text(_themeLabel(themeMode)),
            onTap: () => _showThemePicker(context, ref),
          ),
          const Divider(),
          const _SectionHeader('存储'),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('本地相册根目录'),
            subtitle: const Text('/storage/emulated/0/Pictures'),
            onTap: () {
              // TODO: 目录选择器
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_download),
            title: const Text('下载目录'),
            subtitle: const Text('/storage/emulated/0/Download/Slate'),
          ),
          const Divider(),
          const _SectionHeader('网络'),
          ListTile(
            leading: const Icon(Icons.dns),
            title: const Text('后端地址'),
            subtitle: const Text('http://localhost:8080'),
            onTap: () => _showBackendUrlDialog(context, ref),
          ),
          const Divider(),
          const _SectionHeader('关于'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('版本'),
            subtitle: Text('1.0.0'),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return '浅色';
      case ThemeMode.dark: return '深色';
      case ThemeMode.system: return '跟随系统';
    }
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('跟随系统'),
              leading: const Icon(Icons.brightness_auto),
              selected: ref.read(appSettingsProvider) == ThemeMode.system,
              onTap: () {
                ref.read(appSettingsProvider.notifier).setTheme(ThemeMode.system);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('浅色'),
              leading: const Icon(Icons.brightness_7),
              selected: ref.read(appSettingsProvider) == ThemeMode.light,
              onTap: () {
                ref.read(appSettingsProvider.notifier).setTheme(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('深色'),
              leading: const Icon(Icons.brightness_2),
              selected: ref.read(appSettingsProvider) == ThemeMode.dark,
              onTap: () {
                ref.read(appSettingsProvider.notifier).setTheme(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBackendUrlDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(text: 'http://localhost:8080');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('后端地址'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'http://localhost:8080')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('保存')),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}
