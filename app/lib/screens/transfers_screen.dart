import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/transfer_provider.dart';

class TransfersScreen extends ConsumerWidget {
  const TransfersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(transfersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('传输任务'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(transfersProvider.notifier).load(),
          ),
        ],
      ),
      body: transfers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('加载失败: $err')),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_done, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无传输任务', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final running = tasks.where((t) => t.status == TransferStatus.running).toList();
          final pending = tasks.where((t) => t.status == TransferStatus.pending).toList();
          final paused = tasks.where((t) => t.status == TransferStatus.paused).toList();
          final done = tasks.where((t) => t.status == TransferStatus.done).toList();
          final failed = tasks.where((t) => t.status == TransferStatus.failed).toList();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (running.isNotEmpty) _buildSection(context, '进行中', running, ref),
              if (pending.isNotEmpty) _buildSection(context, '等待中', pending, ref),
              if (paused.isNotEmpty) _buildSection(context, '已暂停', paused, ref),
              if (done.isNotEmpty) _buildSection(context, '已完成', done, ref),
              if (failed.isNotEmpty) _buildSection(context, '失败', failed, ref),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<TransferTask> tasks,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          child: Text(
            '$title (${tasks.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        ...tasks.map((task) => _TransferCard(task: task, ref: ref)),
      ],
    );
  }
}

class _TransferCard extends StatelessWidget {
  final TransferTask task;
  final WidgetRef ref;

  const _TransferCard({required this.task, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isUpload = task.transferType == TransferType.upload;
    final name = task.remotePath.split('/').last;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isUpload ? Icons.cloud_upload : Icons.cloud_download,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                _StatusChip(status: task.status),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: task.progress,
              backgroundColor: Colors.grey[800],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(task.progress * 100).toStringAsFixed(1)}%'),
                Text(_formatBytes(task.writtenBytes)),
              ],
            ),
            if (task.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  task.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (task.status == TransferStatus.running)
                  TextButton.icon(
                    onPressed: () => ref.read(transfersProvider.notifier).pause(task.id),
                    icon: const Icon(Icons.pause, size: 18),
                    label: const Text('暂停'),
                  ),
                if (task.status == TransferStatus.paused)
                  TextButton.icon(
                    onPressed: () => ref.read(transfersProvider.notifier).resume(task.id),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('继续'),
                  ),
                TextButton.icon(
                  onPressed: () => ref.read(transfersProvider.notifier).cancel(task.id),
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('取消'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _StatusChip extends StatelessWidget {
  final TransferStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TransferStatus.pending => ('等待', Colors.orange),
      TransferStatus.running => ('传输', Colors.blue),
      TransferStatus.paused => ('暂停', Colors.amber),
      TransferStatus.done => ('完成', Colors.green),
      TransferStatus.failed => ('失败', Colors.red),
    };

    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
