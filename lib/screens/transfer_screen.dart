import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/transfer_service.dart';
import '../models/models.dart';

class TransferScreen extends ConsumerWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(transferTasksProvider);
    final activeCount = ref.watch(activeTransferCountProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transfers'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Downloading'),
              Tab(text: 'Uploading'),
              Tab(text: 'Completed'),
            ],
          ),
          actions: [
            if (activeCount > 0)
              IconButton(
                icon: const Icon(Icons.pause_circle),
                onPressed: () {},
                tooltip: 'Pause All',
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear') {
                  ref.read(transferTasksProvider.notifier).clearCompleted();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear',
                  child: Text('Clear Completed'),
                ),
              ],
            ),
          ],
        ),
        body: tasks.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swap_vert, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No transfers', style: TextStyle(color: Colors.grey)),
                    Text(
                      'Select photos to download or upload',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            : TabBarView(
                children: [
                  _buildTaskList(context, ref, tasks, TransferType.download),
                  _buildTaskList(context, ref, tasks, TransferType.upload),
                  _buildTaskList(context, ref, tasks, null),
                ],
              ),
      ),
    );
  }

  Widget _buildTaskList(
    BuildContext context,
    WidgetRef ref,
    List<TransferTaskUi> tasks,
    TransferType? filterType,
  ) {
    final filtered = filterType == null
        ? tasks.where(
            (t) =>
                t.status == TransferStatus.done ||
                t.status == TransferStatus.failed,
          )
        : tasks.where((t) => t.transferType == filterType);

    if (filtered.isEmpty) {
      return const Center(child: Text('No tasks'));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final task = filtered.elementAt(index);
        return _TransferTaskTile(task: task);
      },
    );
  }
}

class _TransferTaskTile extends StatelessWidget {
  final TransferTaskUi task;

  const _TransferTaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  task.transferType == TransferType.download
                      ? Icons.download
                      : Icons.upload,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.remotePath.split('/').last,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusChip(),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: task.progress,
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task.sizeText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  task.progressText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (task.status == TransferStatus.running)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.pause, size: 18),
                      label: const Text('Pause'),
                    ),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String text;

    switch (task.status) {
      case TransferStatus.pending:
        color = Colors.orange;
        text = 'Pending';
      case TransferStatus.running:
        color = Colors.blue;
        text = 'Running';
      case TransferStatus.paused:
        color = Colors.orange;
        text = 'Paused';
      case TransferStatus.done:
        color = Colors.green;
        text = 'Done';
      case TransferStatus.failed:
        color = Colors.red;
        text = 'Failed';
    }

    return Chip(
      label: Text(text, style: TextStyle(color: color, fontSize: 12)),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
