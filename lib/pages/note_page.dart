import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/storage_service.dart';

class NotePage extends StatefulWidget {
  const NotePage({super.key});

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  List<Note> _notes = [];
  String _searchQuery = '';
  NoteCategory? _selectedCategory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      _notes = await StorageService.loadNotes();
    } catch (e) {
      debugPrint('Error loading notes: $e');
    }
    setState(() => _isLoading = false);
  }

  void _navigateToEditNote([Note? note]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditPage(note: note),
      ),
    ).then((_) => _loadNotes());
  }

  void _deleteNote(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除笔记'),
        content: const Text('确定要删除这条笔记吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.deleteNote(id);
      await _loadNotes();
    }
  }

  List<Note> _getFilteredNotes() {
    var filtered = _notes;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((note) =>
          note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          note.content.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    if (_selectedCategory != null) {
      filtered = filtered.where((note) => note.category == _selectedCategory).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredNotes = _getFilteredNotes();

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习笔记'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: '搜索笔记...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('全部'),
                          selected: _selectedCategory == null,
                          onSelected: (_) => setState(() => _selectedCategory = null),
                        ),
                      ),
                      ...NoteCategory.values.map((category) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(category.label),
                              selected: _selectedCategory == category,
                              selectedColor: category.color.withOpacity(0.2),
                              onSelected: (_) => setState(() => _selectedCategory = _selectedCategory == category ? null : category),
                            ),
                          )),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredNotes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.note_add, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              const Text('暂无笔记'),
                              const SizedBox(height: 8),
                              const Text('点击右下角按钮创建新笔记'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredNotes.length,
                          itemBuilder: (context, index) {
                            final note = filteredNotes[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                child: InkWell(
                                  onTap: () => _navigateToEditNote(note),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 4,
                                              height: 20,
                                              color: note.category.color,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(note.title, style: theme.textTheme.titleMedium)),
                                            PopupMenuButton<String>(
                                              itemBuilder: (_) => [
                                                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                                                const PopupMenuItem(value: 'delete', child: Text('删除')),
                                              ],
                                              onSelected: (value) {
                                                if (value == 'edit') {
                                                  _navigateToEditNote(note);
                                                } else if (value == 'delete') {
                                                  _deleteNote(note.id);
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          note.content.length > 100
                                              ? '${note.content.substring(0, 100)}...'
                                              : note.content,
                                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Text(
                                              note.category.label,
                                              style: theme.textTheme.labelSmall?.copyWith(color: note.category.color),
                                            ),
                                            if (note.tags.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              ...note.tags.take(3).map((tag) => Padding(
                                                    padding: const EdgeInsets.only(right: 4),
                                                    child: Chip(label: Text(tag, style: theme.textTheme.labelSmall)),
                                                  )),
                                            ],
                                            const Spacer(),
                                            Text(
                                              note.updatedAt != null
                                                  ? '${note.updatedAt!.month}/${note.updatedAt!.day}'
                                                  : '${note.createdAt?.month}/${note.createdAt?.day}',
                                              style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditNote(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class NoteEditPage extends StatefulWidget {
  final Note? note;

  const NoteEditPage({super.key, this.note});

  @override
  State<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends State<NoteEditPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  NoteCategory _category = NoteCategory.custom;
  final _tagsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _category = widget.note!.category;
      _tagsController.text = widget.note!.tags.join(',');
    }
  }

  void _saveNote() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入标题')));
      return;
    }

    final tags = _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

    final note = Note(
      id: widget.note?.id ?? DateTime.now().toIso8601String(),
      title: _titleController.text,
      content: _contentController.text,
      category: _category,
      tags: tags,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await StorageService.saveNote(note);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note != null ? '编辑笔记' : '新建笔记'),
        centerTitle: true,
        actions: [
          TextButton(onPressed: _saveNote, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: '标题', border: OutlineInputBorder()),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('分类:', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 8),
              ...NoteCategory.values.map((category) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category.label),
                      selected: _category == category,
                      selectedColor: category.color.withOpacity(0.2),
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tagsController,
            decoration: const InputDecoration(labelText: '标签（逗号分隔）', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            decoration: const InputDecoration(labelText: '内容', border: OutlineInputBorder()),
            maxLines: 20,
            keyboardType: TextInputType.multiline,
          ),
        ],
      ),
    );
  }
}