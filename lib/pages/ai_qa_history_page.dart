import 'package:flutter/material.dart';

import '../models/ai_qa_record.dart';
import '../services/ai_qa_storage_service.dart';
import '../widgets/ai_assistant_sheet.dart';

/// AI 问答记录历史页 - 查看所有条目的历史问答
class AiQaHistoryPage extends StatefulWidget {
  const AiQaHistoryPage({super.key});

  @override
  State<AiQaHistoryPage> createState() => _AiQaHistoryPageState();
}

class _AiQaHistoryPageState extends State<AiQaHistoryPage> {
  List<AiQaRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await AiQaStorageService.loadAllRecords();
    if (!mounted) return;
    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空全部问答记录'),
        content: const Text('将删除所有条目的 AI 问答记录，且无法恢复。确定清空吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AiQaStorageService.clearAll();
    await _load();
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 问答记录'),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: '清空全部',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.forum_outlined,
                          size: 64,
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      const Text('暂无 AI 问答记录',
                          style: TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 8),
                      const Text(
                        '在考点知识或练习题目中点击"问 AI"即可开始',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final record = _records[index];
                    final lastMessage = record.messages.isNotEmpty
                        ? record.messages.last
                        : null;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor:
                              theme.colorScheme.primaryContainer,
                          child: Icon(
                            record.itemType == 'question'
                                ? Icons.quiz_rounded
                                : Icons.menu_book_rounded,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          record.itemTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              lastMessage != null
                                  ? '问：${lastMessage.question}'
                                  : '暂无问答',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${record.messages.length} 轮问答 · '
                              '${_formatTime(record.updatedAt)}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 20),
                          tooltip: '删除该记录',
                          onPressed: () async {
                            await AiQaStorageService.deleteRecord(
                                record.itemId);
                            await _load();
                          },
                        ),
                        onTap: () async {
                          // 以保存的上下文重新打开问答浮窗
                          await AiAssistantSheet.show(
                            context,
                            itemId: record.itemId,
                            itemType: record.itemType,
                            itemTitle: record.itemTitle,
                            contextText: record.contextText,
                          );
                          await _load();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
