import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/question.dart';
import '../providers/app_provider.dart';
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
  List<Question> _allQuestions = [];
  List<Question> _filteredQuestions = [];
  Set<String> _favorites = {};
  bool _isLoading = true;
  String _searchKeyword = '';
  QuestionSubject? _filterSubject;
  QuestionType? _filterType;
  bool _onlyFavorites = false;

  // 搜索防抖
  Timer? _debounceTimer;
  // 显示分页（滚动加载更多）
  final ScrollController _scrollController = ScrollController();
  int _displayCount = 50;
  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_displayCount < _filteredQuestions.length) {
        setState(() {
          _displayCount =
              (_displayCount + _pageSize).clamp(0, _filteredQuestions.length);
        });
      }
    }
  }

  Future<void> _loadData() async {
    final questions = await QuestionService.getAllQuestions();
    final favorites = await StorageService.loadFavorites();
    setState(() {
      _allQuestions = questions;
      _favorites = favorites;
      _isLoading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filteredQuestions = _allQuestions.where((q) {
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
      _displayCount = _pageSize;
    });
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchKeyword = value;
      _applyFilters();
    });
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
                    onChanged: _onSearchChanged,
                  ),
                ),
                // 筛选器
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...QuestionSubject.values.map((s) => _buildFilterChip(
                            label: s.label,
                            selected: _filterSubject == s,
                            onTap: () {
                              _filterSubject = _filterSubject == s ? null : s;
                              _applyFilters();
                            },
                          )),
                      const SizedBox(width: 8),
                      ...QuestionType.values.map((t) => _buildFilterChip(
                            label: t.label,
                            selected: _filterType == t,
                            onTap: () {
                              _filterType = _filterType == t ? null : t;
                              _applyFilters();
                            },
                          )),
                      _buildFilterChip(
                        label: '收藏',
                        selected: _onlyFavorites,
                        onTap: () {
                          _onlyFavorites = !_onlyFavorites;
                          _applyFilters();
                        },
                        icon: Icons.star_rounded,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text('共 ${_filteredQuestions.length} 题', style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _filteredQuestions.isEmpty
                            ? null
                            : () {
                                final provider = context.read<AppProvider>();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PracticePage(
                                      config: PracticeConfig(
                                        subject: _filterSubject,
                                        type: _filterType,
                                        shuffleQuestions: true,
                                      ),
                                      onCompleted: (result) async {
                                        await provider.addHistory(result);
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
                  child: _filteredQuestions.isEmpty
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
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _displayCount < _filteredQuestions.length
                              ? _displayCount + 1
                              : _displayCount,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            if (index >= _displayCount) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final q = _filteredQuestions[index];
                            final isFavorite = _favorites.contains(q.uniqueKey);
                            return _QuestionCard(
                              question: q,
                              isFavorite: isFavorite,
                              onToggleFavorite: () => _toggleFavorite(q),
                              onDelete: () => _deleteQuestion(q),
                              onTap: () {
                                final provider = context.read<AppProvider>();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PracticePage(
                                      config: PracticeConfig(
                                        subject: q.subject,
                                        type: q.type,
                                      ),
                                      onCompleted: (result) async {
                                        await provider.addHistory(result);
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
          backgroundColor: question.subject.color.withValues(alpha: 0.1),
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
                  question.difficulty.color.withValues(alpha: 0.1),
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
