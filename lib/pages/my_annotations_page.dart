import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../data/textbooks.dart';
import '../models/question.dart';
import '../services/annotation_store.dart';
import 'textbook_page.dart';

/// "我的批注"汇总页。
///
/// 把本地全部用户批注按"科目 → 章节 → 小节"分组展示，支持关键字搜索、
/// 一键导出/导入备份（防止重装或换机丢失）、点击跳转到对应章节考点知识、
/// 以及切换"全局/当前字段"范围或删除。
class MyAnnotationsPage extends StatefulWidget {
  const MyAnnotationsPage({super.key});

  @override
  State<MyAnnotationsPage> createState() => _MyAnnotationsPageState();
}

class _MyAnnotationsPageState extends State<MyAnnotationsPage> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    AnnotationStore.ensureLoaded();
  }

  /// 把批注按"所属教材"分组，组内按章节/小节顺序排序，便于阅读。
  List<_SubjectGroup> _buildGroups() {
    final q = _query.trim().toLowerCase();
    final bySubject = <String, List<UserAnnotation>>{};
    for (final a in AnnotationStore.all) {
      if (q.isNotEmpty &&
          !a.term.toLowerCase().contains(q) &&
          !a.note.toLowerCase().contains(q)) {
        continue;
      }
      (bySubject[a.subject] ??= []).add(a);
    }

    final groups = <_SubjectGroup>[];
    for (final book in Textbooks.all) {
      final items = bySubject[book.subject.name];
      if (items == null || items.isEmpty) continue;
      items.sort((x, y) {
        final cx = _chapterOrder(book, x.chapterNumber);
        final cy = _chapterOrder(book, y.chapterNumber);
        if (cx != cy) return cx.compareTo(cy);
        final sp = _numCompare(x.sectionNumber, y.sectionNumber);
        if (sp != 0) return sp;
        return x.term.compareTo(y.term);
      });
      groups.add(_SubjectGroup(book, items));
    }
    return groups;
  }

  int _chapterOrder(Textbook book, String number) {
    final idx = book.chapters.indexWhere((c) => c.number == number);
    return idx < 0 ? 9999 : idx;
  }

  /// 形如 "2" / "2.1" / "10.3" 的自然序比较。
  int _numCompare(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final n = pa.length > pb.length ? pb.length : pa.length;
    for (var i = 0; i < n; i++) {
      if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
    }
    return pa.length.compareTo(pb.length);
  }

  void _openChapter(_SubjectGroup group, UserAnnotation a) {
    final book = group.book;
    final chapter = book.chapters.firstWhere(
      (c) => c.number == a.chapterNumber,
      orElse: () => TextbookChapter(number: a.chapterNumber, title: '', page: 0),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterKnowledgePage(
          subject: book.subject,
          chapterNumber: a.chapterNumber,
          chapterTitle: chapter.title,
          bookColor: book.color,
          bookTitle: book.title,
        ),
      ),
    );
  }

  Future<void> _toggleScope(UserAnnotation a) async {
    final next = a.scope == AnnotationScope.global
        ? AnnotationScope.field
        : AnnotationScope.global;
    await AnnotationStore.upsert(a.copyWith(scope: next));
    if (mounted) setState(() {});
  }

  Future<void> _delete(UserAnnotation a) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除批注'),
            content: Text('确定删除「${a.term}」的批注吗？此操作不可撤销。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    await AnnotationStore.removeAnnotation(a);
    if (mounted) setState(() {});
  }

  Future<void> _export() async {
    final json = AnnotationStore.exportJson();
    Directory? dir = await getExternalStorageDirectory();
    dir ??= await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final ts =
        '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}';
    final file = File('${dir.path}/annotations_backup_$ts.json');
    try {
      await file.writeAsString(json);
    } catch (e) {
      if (mounted) _toast('导出失败：$e');
      return;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('已导出备份'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('共 ${AnnotationStore.count} 条批注已保存到：'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                file.path,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '可通过 USB / 文件管理器取出该文件，或在下方复制 JSON 文本。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (mounted) _toast('已复制 JSON 到剪贴板');
            },
            child: const Text('复制 JSON'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final content = await File(path).readAsString();
    try {
      final count = await AnnotationStore.importJson(content, merge: true);
      if (mounted) {
        setState(() {});
        _toast('已导入 $count 条批注（与本地合并）');
      }
    } catch (e) {
      if (mounted) _toast('导入失败：文件格式不正确');
    }
  }

  String _pad(int n) => n < 10 ? '0$n' : '$n';

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = _buildGroups();

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的批注'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_rounded),
            tooltip: '导入备份',
            onPressed: _import,
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: '导出备份',
            onPressed: _export,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: '搜索批注关键词或内容...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () => setState(() => _query = ''),
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: groups.isEmpty
                ? _EmptyState(query: _query)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: groups.length,
                    itemBuilder: (context, i) => _SubjectSection(
                      group: groups[i],
                      onOpen: _openChapter,
                      onToggleScope: _toggleScope,
                      onDelete: _delete,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SubjectGroup {
  _SubjectGroup(this.book, this.items);
  final Textbook book;
  final List<UserAnnotation> items;
}

class _SubjectSection extends StatelessWidget {
  const _SubjectSection({
    required this.group,
    required this.onOpen,
    required this.onToggleScope,
    required this.onDelete,
  });

  final _SubjectGroup group;
  final void Function(_SubjectGroup, UserAnnotation) onOpen;
  final Future<void> Function(UserAnnotation) onToggleScope;
  final Future<void> Function(UserAnnotation) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(group.book.color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              group.book.title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              '${group.items.length} 条',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...group.items.map(
          (a) => _AnnotationCard(
            annotation: a,
            color: color,
            onOpen: () => onOpen(group, a),
            onToggleScope: onToggleScope,
            onDelete: onDelete,
          ),
        ),
      ],
    );
  }
}

class _AnnotationCard extends StatelessWidget {
  const _AnnotationCard({
    required this.annotation,
    required this.color,
    required this.onOpen,
    required this.onToggleScope,
    required this.onDelete,
  });

  final UserAnnotation annotation;
  final Color color;
  final VoidCallback onOpen;
  final Future<void> Function(UserAnnotation) onToggleScope;
  final Future<void> Function(UserAnnotation) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGlobal = annotation.scope == AnnotationScope.global;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      annotation.term,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: annotation.category.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      annotation.category.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: annotation.category.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isGlobal
                          ? Colors.purple.withValues(alpha: 0.12)
                          : Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isGlobal ? '全局生效' : '仅当前字段',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isGlobal ? Colors.purple : Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                annotation.note,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black87,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '第${annotation.chapterNumber}章 · ${annotation.sectionNumber} 小节',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    onSelected: (v) {
                      if (v == 'scope') {
                        onToggleScope(annotation);
                      } else if (v == 'delete') {
                        onDelete(annotation);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'scope',
                        child: Text(isGlobal ? '改为仅当前字段' : '改为全局生效'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('删除', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.query = ''});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_alt_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              query.isEmpty ? '还没有任何批注' : '没有匹配「$query」的批注',
              style: const TextStyle(color: Colors.grey),
            ),
            if (query.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                '在阅读考点时长按选中文字即可"加注释"',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
