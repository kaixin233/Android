import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ai_qa_record.dart';
import '../pages/ai_qa_history_page.dart';
import '../pages/ai_settings_page.dart';
import '../services/ai_qa_storage_service.dart';
import '../services/ai_service.dart';

/// AI 学习助手问答浮窗
///
/// 以一个学习内容条目（考点知识 / 题目）为上下文发起多轮问答。
/// 通过 [AiAssistantSheet.show] 打开。
class AiAssistantSheet extends StatefulWidget {
  const AiAssistantSheet({
    super.key,
    required this.itemId,
    required this.itemType,
    required this.itemTitle,
    required this.contextText,
  });

  /// 条目唯一标识（持久化 key）
  final String itemId;

  /// `knowledge`（考点知识）或 `question`（题目）
  final String itemType;

  /// 条目展示标题
  final String itemTitle;

  /// 提问上下文（条目正文或用户选中的文本）
  final String contextText;

  /// 以底部浮窗形式打开 AI 助手
  static Future<void> show(
    BuildContext context, {
    required String itemId,
    required String itemType,
    required String itemTitle,
    required String contextText,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiAssistantSheet(
        itemId: itemId,
        itemType: itemType,
        itemTitle: itemTitle,
        contextText: contextText,
      ),
    );
  }

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  static const List<String> _quickPrompts = <String>[
    '这是什么？',
    '为什么？',
    '举例说明',
    '易错点有哪些？',
    '帮我总结记忆口诀',
  ];

  /// 发送给 API 时携带的历史轮数上限
  static const int _historyTurnsForApi = 8;

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  AiQaRecord? _record;
  bool _isLoading = true;
  bool _isAsking = false;
  String? _error;
  String? _failedQuestion;
  bool _hasProvider = false;
  bool _contextExpanded = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final record = await AiQaStorageService.loadRecord(widget.itemId);
    final hasProvider = await AiService.hasAnyProvider();
    if (!mounted) return;
    setState(() {
      _record = record;
      _hasProvider = hasProvider;
      _isLoading = false;
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ========== 提问流程 ==========

  String _buildSystemPrompt() {
    final typeLabel = widget.itemType == 'question' ? '练习题' : '考点知识';
    final contextSnippet = widget.contextText.length > 4000
        ? '${widget.contextText.substring(0, 4000)}……（内容过长已截断）'
        : widget.contextText;
    return '你是一位专业的二级建造师考试辅导老师，正在帮助学员理解学习内容。\n'
        '当前学员正在学习的$typeLabel是「${widget.itemTitle}」，内容如下：\n'
        '【学习内容开始】\n$contextSnippet\n【学习内容结束】\n'
        '请始终紧扣上述学习内容回答，不要泛泛而谈；'
        '如果学员的提问超出该内容范围，请先回答再简要提示其与当前内容的关联。\n'
        '回答要求：通俗易懂、条理清晰，可适当使用编号列表；'
        '结合考试实际说明考点考法；篇幅控制在 300 字以内，除非学员要求详细展开。';
  }

  List<AiChatMessage> _buildApiMessages(String question,
      {bool excludeLastTurn = false}) {
    final messages = <AiChatMessage>[
      AiChatMessage(role: 'system', content: _buildSystemPrompt()),
    ];
    var history = _record?.messages ?? <AiQaMessage>[];
    if (excludeLastTurn && history.isNotEmpty) {
      history = history.sublist(0, history.length - 1);
    }
    final start = history.length > _historyTurnsForApi
        ? history.length - _historyTurnsForApi
        : 0;
    for (final m in history.sublist(start)) {
      messages.add(AiChatMessage(role: 'user', content: m.question));
      messages.add(AiChatMessage(role: 'assistant', content: m.answer));
    }
    messages.add(AiChatMessage(role: 'user', content: question));
    return messages;
  }

  Future<void> _ask(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || _isAsking) return;
    if (!_hasProvider) {
      _showNoProviderDialog(trimmed);
      return;
    }
    _inputController.clear();
    await _executeAiRequest(trimmed);
  }

  /// 重新生成最后一条回答
  Future<void> _regenerate() async {
    final messages = _record?.messages;
    if (messages == null || messages.isEmpty || _isAsking) return;
    await _executeAiRequest(messages.last.question, replaceLast: true);
  }

  /// 发起一次 AI 请求并持久化结果
  ///
  /// [replaceLast] 为 true 时用新回答覆盖最后一条记录（重新生成），
  /// 否则作为新一轮问答追加。
  Future<void> _executeAiRequest(String question,
      {bool replaceLast = false}) async {
    if (!_hasProvider) {
      _showNoProviderDialog(question);
      return;
    }

    setState(() {
      _isAsking = true;
      _error = null;
      _failedQuestion = null;
    });
    _scrollToBottom();

    try {
      final answer = await AiService.chat(
          _buildApiMessages(question, excludeLastTurn: replaceLast));
      final message = AiQaMessage(question: question, answer: answer);
      AiQaRecord? record;
      if (replaceLast) {
        await AiQaStorageService.replaceLastMessage(widget.itemId, message);
        record = await AiQaStorageService.loadRecord(widget.itemId);
      } else {
        record = await AiQaStorageService.appendMessage(
          itemId: widget.itemId,
          itemType: widget.itemType,
          itemTitle: widget.itemTitle,
          contextText: widget.contextText,
          message: message,
        );
      }
      if (!mounted) return;
      setState(() {
        _record = record;
        _isAsking = false;
      });
      _scrollToBottom();
    } on AiApiException catch (e) {
      _handleRequestError(e.message, question);
    } catch (e) {
      _handleRequestError('出现未知错误，请重试', question);
    }
  }

  void _handleRequestError(String message, String question) {
    if (!mounted) return;
    setState(() {
      _isAsking = false;
      _error = message;
      _failedQuestion = question;
    });
    _scrollToBottom();
  }

  Future<void> _clearRecord() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除问答记录'),
        content: const Text('将删除该条目的全部 AI 问答记录，且无法恢复。确定清除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AiQaStorageService.deleteRecord(widget.itemId);
    if (!mounted) return;
    setState(() {
      _record = null;
      _error = null;
    });
  }

  // ========== 未配置提供方 ==========

  void _showNoProviderDialog(String question) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.auto_awesome_rounded,
            color: theme.colorScheme.primary, size: 32),
        title: const Text('尚未配置 AI 提供方'),
        content: const Text(
          '请先在「AI 助手设置」中填写以下任一方式，即可在 App 内直接提问并自动保存回答：\n\n'
          '• 网页端 Token（免费，优先）：从 chat.deepseek.com 的 Local Storage 复制 userToken\n'
          '• 官方 API Key（备用）：前往 DeepSeek 开放平台创建',
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiSettingsPage()),
              );
              final hasProvider = await AiService.hasAnyProvider();
              if (mounted) setState(() => _hasProvider = hasProvider);
            },
            child: const Text('去配置'),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ========== UI ==========

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: screenHeight * 0.88,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _buildHeader(theme),
            _buildContextCard(theme),
            const Divider(height: 1),
            Expanded(child: _buildBody(theme)),
            if (_error != null) _buildErrorCard(theme),
            _buildQuickPrompts(theme),
            _buildInputBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final hasMessages = _record?.messages.isNotEmpty ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.auto_awesome_rounded,
                color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI 学习助手',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  widget.itemTitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: '全部问答记录',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiQaHistoryPage()),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'regenerate') _regenerate();
              if (value == 'clear') _clearRecord();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'regenerate',
                enabled: hasMessages && !_isAsking,
                child: const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.refresh_rounded),
                  title: Text('重新生成最后一条'),
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                enabled: hasMessages,
                child: const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('清除该条目记录'),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: '关闭',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContextCard(ThemeData theme) {
    final excerpt = widget.contextText.trim();
    if (excerpt.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GestureDetector(
        onTap: () => setState(() => _contextExpanded = !_contextExpanded),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.format_quote_rounded,
                  size: 16, color: theme.colorScheme.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  excerpt,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                  maxLines: _contextExpanded ? null : 2,
                  overflow: _contextExpanded ? null : TextOverflow.ellipsis,
                ),
              ),
              Icon(
                _contextExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final messages = _record?.messages ?? <AiQaMessage>[];
    if (messages.isEmpty && !_isAsking) {
      return _buildEmptyState(theme);
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: messages.length + (_isAsking ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= messages.length) {
          return _buildLoadingBubble(theme);
        }
        final m = messages[index];
        return Column(
          children: [
            _buildUserBubble(theme, m.question),
            _buildAiBubble(theme, m.answer),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology_alt_rounded,
                size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('就当前内容向 AI 提问吧',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '点击下方快捷问题或直接输入，\nAI 会紧扣所选内容为你解答，回答自动保存。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            if (!_hasProvider) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AiSettingsPage()),
                  );
                  final hasProvider = await AiService.hasAnyProvider();
                  if (mounted) setState(() => _hasProvider = hasProvider);
                },
                icon: const Icon(Icons.key_rounded, size: 18),
                label: const Text('配置后体验更佳'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserBubble(ThemeData theme, String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(left: 48, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(text,
            style: TextStyle(color: theme.colorScheme.onPrimary, height: 1.5)),
      ),
    );
  }

  Widget _buildAiBubble(ThemeData theme, String text) {
    final isDark = theme.brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 32, bottom: 16),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(text, style: const TextStyle(height: 1.6)),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                tooltip: '复制回答',
                visualDensity: VisualDensity.compact,
                color: theme.colorScheme.outline,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已复制回答'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble(ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 32, bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text('AI 正在思考…',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: theme.colorScheme.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                  color: theme.colorScheme.onErrorContainer, fontSize: 13),
            ),
          ),
          if (_failedQuestion != null)
            TextButton(
              onPressed: _isAsking ? null : () => _ask(_failedQuestion!),
              child: const Text('重试'),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickPrompts(ThemeData theme) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickPrompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(_quickPrompts[index]),
            labelStyle: const TextStyle(fontSize: 13),
            visualDensity: VisualDensity.compact,
            onPressed: _isAsking ? null : () => _ask(_quickPrompts[index]),
          );
        },
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocus,
              enabled: !_isAsking,
              textInputAction: TextInputAction.send,
              onSubmitted: _ask,
              maxLines: null,
              decoration: InputDecoration(
                hintText: '输入你的问题，可连续追问…',
                hintStyle: const TextStyle(fontSize: 14),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed:
                _isAsking ? null : () => _ask(_inputController.text),
            icon: const Icon(Icons.send_rounded),
            tooltip: '发送',
          ),
        ],
      ),
    );
  }
}
