import 'package:flutter/material.dart';

import '../models/question.dart';
import '../services/ai_question_service.dart';
import '../services/question_service.dart';

/// AI 出题页
///
/// 输入科目 / 主题（可选，来自考点上下文），选择题型与题量，调用 DeepSeek 生成题目，
/// 预览勾选后导入题库（自动归入指定章节/小节）。
class AiGeneratePage extends StatefulWidget {
  const AiGeneratePage({super.key, this.predefinedContext});

  /// 从考点知识页进入时带入的上下文（科目/章/节/考点正文）
  final AiQuestionContext? predefinedContext;

  @override
  State<AiGeneratePage> createState() => _AiGeneratePageState();
}

class _AiGeneratePageState extends State<AiGeneratePage> {
  late QuestionSubject _subject;
  late TextEditingController _topicController;
  final Set<QuestionType> _types = {QuestionType.singleChoice};
  int _count = 5;

  bool _generating = false;
  String _streamText = '';
  String? _error;
  List<Question> _generated = [];
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _subject = widget.predefinedContext?.subject ?? QuestionSubject.law;
    _topicController = TextEditingController(
      text: widget.predefinedContext?.sectionTitle ??
          widget.predefinedContext?.topic ??
          '',
    );
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_generating) return;
    if (_types.isEmpty) {
      setState(() => _error = '请至少选择一种题型');
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
      _streamText = '';
      _generated = [];
      _selected.clear();
    });

    final ctx = AiQuestionContext(
      subject: _subject,
      topic: _topicController.text.trim(),
      chapterNumber: widget.predefinedContext?.chapterNumber,
      subsection: widget.predefinedContext?.subsection,
      sectionTitle: widget.predefinedContext?.sectionTitle,
      knowledgeContext: widget.predefinedContext?.knowledgeContext,
    );

    try {
      final list = await AiQuestionService.generate(
        context: ctx,
        types: _types,
        count: _count,
        onProgress: (p) {
          if (mounted) setState(() => _streamText = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _generating = false;
        _generated = list;
        _selected.addAll(List.generate(list.length, (i) => i));
        if (list.isEmpty) {
          _error = '未解析到有效题目，可调整主题后重试';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = '$e';
      });
    }
  }

  Future<void> _importSelected() async {
    final picked = [
      for (var i = 0; i < _generated.length; i++)
        if (_selected.contains(i)) _generated[i],
    ];
    if (picked.isEmpty) return;
    try {
      final n = await QuestionService.importQuestions(picked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入 $n 道题目到题库')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ctxName = widget.predefinedContext?.displayName;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 出题'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (ctxName != null && ctxName.isNotEmpty)
            Card(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.auto_awesome_rounded),
                title: const Text('出题范围已锁定'),
                subtitle: Text(ctxName),
              ),
            ),
          const SizedBox(height: 8),

          // 科目
          DropdownButtonFormField<QuestionSubject>(
            initialValue: _subject,
            decoration: const InputDecoration(
              labelText: '科目',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final s in QuestionSubject.values)
                DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: _generating
                ? null
                : (v) => setState(() => _subject = v ?? _subject),
          ),
          const SizedBox(height: 12),

          // 主题
          TextField(
            controller: _topicController,
            enabled: !_generating,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '命题主题 / 范围（可留空）',
              hintText: '如：建设工程物权制度、施工进度控制…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // 题型
          Text('题型', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final t in const [
                QuestionType.singleChoice,
                QuestionType.multipleChoice,
                QuestionType.trueFalse,
              ])
                FilterChip(
                  label: Text(t.label),
                  selected: _types.contains(t),
                  onSelected: _generating
                      ? null
                      : (v) => setState(() {
                            if (v) {
                              _types.add(t);
                            } else {
                              _types.remove(t);
                            }
                          }),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 题量
          Row(
            children: [
              Text('题量', style: theme.textTheme.titleSmall),
              Expanded(
                child: Slider(
                  value: _count.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '$_count',
                  onChanged: _generating
                      ? null
                      : (v) => setState(() => _count = v.round()),
                ),
              ),
              Text('$_count 题'),
            ],
          ),

          FilledButton.icon(
            onPressed: _generating ? null : _generate,
            icon: _generating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(_generating ? '生成中…' : '开始生成'),
          ),

          if (_generating && _streamText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: Text(_streamText,
                    style: const TextStyle(fontSize: 12, height: 1.5)),
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],

          if (_generated.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text('生成结果（${_generated.length}）',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    if (_selected.length == _generated.length) {
                      _selected.clear();
                    } else {
                      _selected.addAll(List.generate(_generated.length, (i) => i));
                    }
                  }),
                  child: Text(_selected.length == _generated.length ? '全不选' : '全选'),
                ),
              ],
            ),
            ...List.generate(_generated.length, (i) {
              final q = _generated[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  value: _selected.contains(i),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selected.add(i);
                    } else {
                      _selected.remove(i);
                    }
                  }),
                  title: Text(q.prompt, style: const TextStyle(fontSize: 14)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('【${q.type.label}】', style: const TextStyle(fontSize: 12)),
                      ...List.generate(q.options.length, (oi) {
                        final isAns = q.type == QuestionType.multipleChoice
                            ? q.answerIndices.contains(oi)
                            : q.answerIndex == oi;
                        return Text(
                          '${String.fromCharCode(65 + oi)}. ${q.options[oi]}${isAns ? '  ✓' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isAns ? Colors.green : null,
                            fontWeight: isAns ? FontWeight.bold : null,
                          ),
                        );
                      }),
                      if (q.type == QuestionType.trueFalse)
                        Text('答案：${q.isCorrect == true ? '正确' : '错误'}',
                            style: const TextStyle(fontSize: 12, color: Colors.green)),
                      if (q.explanation.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('解析：${q.explanation}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _selected.isEmpty ? null : _importSelected,
              icon: const Icon(Icons.save_alt_rounded),
              label: Text('导入所选题（${_selected.length}）'),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
