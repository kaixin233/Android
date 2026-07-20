import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/question.dart';
import '../services/question_service.dart';
import '../services/storage_service.dart';
import 'practice_page.dart';

/// 题库页面 - 支持搜索、筛选、收藏、导入、删除
class QuestionBankPage extends StatefulWidget {
  const QuestionBankPage({super.key});

  @override
  State<QuestionBankPage> createState() => _QuestionBankPageState();
}

class _QuestionBankPageState extends State<QuestionBankPage> {
  List<Question> _questions = [];
  Set<String> _favorites = {};
  bool _isLoading = true;
  String _searchKeyword = '';
  QuestionSubject? _filterSubject;
  QuestionType? _filterType;
  bool _onlyFavorites = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final questions = await QuestionService.getAllQuestions();
    final favorites = await StorageService.loadFavorites();
    setState(() {
      _questions = questions;
      _favorites = favorites;
      _isLoading = false;
    });
  }

  List<Question> get _filteredQuestions {
    return _questions.where((q) {
      if (_onlyFavorites && !_favorites.contains(q.uniqueKey)) return false;
      if (_filterSubject != null && q.subject != _filterSubject) return false;
      if (_filterType != null && q.type != _filterType) return false;
      if (_searchKeyword.isNotEmpty) {
        final kw = _searchKeyword.toLowerCase();
        if (!q.title.toLowerCase().contains(kw) &&
            !q.prompt.toLowerCase().contains(kw)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _importQuestions() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      _showSnack('无法读取文件内容');
      return;
    }

    try {
      final jsonContent = String.fromCharCodes(file.bytes!);
      final Map<String, dynamic> data = jsonDecode(jsonContent) as Map<String, dynamic>;
      final List<dynamic> questionsJson = data['questions'] as List<dynamic>;
      final newQuestions = questionsJson
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList();

      final count = await QuestionService.importQuestions(newQuestions);
      await _loadData();
      _showSnack('成功导入 $count 道题目');
    } catch (e) {
      _showSnack('导入失败，请检查文件格式');
    }
  }

  Future<void> _toggleFavorite(Question question) async {
    await StorageService.toggleFavorite(question.uniqueKey);
    await _loadData();
  }

  Future<void> _deleteQuestion(Question question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除题目'),
        content: Text('确定要删除「${question.title}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed == true) {
      await QuestionService.deleteImported(question.uniqueKey);
      await _loadData();
      _showSnack('已删除');
    }
  }

  Future<void> _clearImported() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清空导入题库'),
        content: const Text('将删除所有导入的题目，默认题库不受影响。确定继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清空')),
        ],
      ),
    );
    if (confirmed == true) {
      await QuestionService.clearImported();
      await _loadData();
      _showSnack('已清空导入的题库');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredQuestions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('题库'),
        actions: [
          IconButton(
            onPressed: _importQuestions,
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: '导入题库',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'clear') _clearImported();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'clear', child: Text('清空导入题库')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 搜索框
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: '搜索题目关键词...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) => setState(() => _searchKeyword = value),
                  ),
                ),
                // 筛选器
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSubjectFilter(),
                      ...QuestionSubject.values.map((s) => _buildFilterChip(
                            label: s.label,
                            selected: _filterSubject == s,
                            onTap: () => setState(() {
                              _filterSubject = _filterSubject == s ? null : s;
                            }),
                          )),
                      const SizedBox(width: 8),
                      ...QuestionType.values.map((t) => _buildFilterChip(
                            label: t.label,
                            selected: _filterType == t,
                            onTap: () => setState(() {
                              _filterType = _filterType == t ? null : t;
                            }),
                          )),
                      _buildFilterChip(
                        label: '收藏',
                        selected: _onlyFavorites,
                        onTap: () => setState(() => _onlyFavorites = !_onlyFavorites),
                        icon: Icons.star_rounded,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text('共 ${filtered.length} 题', style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: filtered.isEmpty
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PracticePage(
                                      config: PracticeConfig(
                                        subject: _filterSubject,
                                        type: _filterType,
                                        shuffleQuestions: true,
                                      ),
                                      onCompleted: (result) async {
                                        await StorageService.addHistory(result);
                                      },
                                    ),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('开始练习'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text('未找到匹配题目',
                                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final q = filtered[index];
                            final isFavorite = _favorites.contains(q.uniqueKey);
                            return _QuestionCard(
                              question: q,
                              isFavorite: isFavorite,
                              onToggleFavorite: () => _toggleFavorite(q),
                              onDelete: () => _deleteQuestion(q),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PracticePage(
                                      config: PracticeConfig(
                                        subject: q.subject,
                                        type: q.type,
                                      ),
                                      onCompleted: (result) async {
                                        await StorageService.addHistory(result);
                                      },
                                    ),
                                  ),
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

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: icon != null ? Icon(icon, size: 16) : null,
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onDelete,
    required this.onTap,
  });

  final Question question;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: question.subject.color.withOpacity(0.1),
          child: Text(
            question.subject.label,
            style: TextStyle(
              color: question.subject.color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        title: Text(
          question.prompt,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            children: [
              _buildTag(question.type.label, theme.colorScheme.primaryContainer, theme.colorScheme.onPrimaryContainer),
              _buildTag(question.difficulty.label,
                  question.difficulty.color.withOpacity(0.1),
                  question.difficulty.color),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'favorite') onToggleFavorite();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'favorite',
              child: Row(children: [
                Icon(isFavorite ? Icons.star_rounded : Icons.star_border_rounded, size: 20),
                const SizedBox(width: 8),
                Text(isFavorite ? '取消收藏' : '收藏'),
              ]),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                SizedBox(width: 8),
                Text('删除', style: TextStyle(color: Colors.red)),
              ]),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildTag(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}
