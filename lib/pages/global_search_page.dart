import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/question.dart';
import '../models/history_item.dart';
import '../models/note.dart';
import '../providers/app_provider.dart';
import '../services/annotation_store.dart';
import 'note_page.dart';
import 'my_annotations_page.dart';
import 'practice_page.dart';

/// 全局搜索：跨"题库题目 / 我的批注 / 学习笔记"检索，点按直达。
class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.watch<AppProvider>();
    final q = _query.trim().toLowerCase();

    final questionHits = <Question>[];
    final annotationHits = <UserAnnotation>[];
    final noteHits = <Note>[];
    if (q.isNotEmpty) {
      for (final question in app.allQuestions) {
        if (question.prompt.toLowerCase().contains(q) ||
            question.knowledgePoints.any((k) => k.toLowerCase().contains(q))) {
          questionHits.add(question);
          if (questionHits.length >= 50) break;
        }
      }
      for (final a in AnnotationStore.all) {
        if (a.term.toLowerCase().contains(q) || a.note.toLowerCase().contains(q)) {
          annotationHits.add(a);
        }
      }
      for (final n in app.notes) {
        if (n.title.toLowerCase().contains(q) ||
            n.content.toLowerCase().contains(q) ||
            n.tags.any((t) => t.toLowerCase().contains(q))) {
          noteHits.add(n);
        }
      }
    }

    final hasResults =
        questionHits.isNotEmpty || annotationHits.isNotEmpty || noteHits.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('全局搜索'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: '搜索题目、批注、笔记…',
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
            child: q.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_rounded, size: 56, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('输入关键词，跨题目/批注/笔记检索',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : !hasResults
                    ? const Center(child: Text('没有匹配结果', style: TextStyle(color: Colors.grey)))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          if (questionHits.isNotEmpty) ...[
                            _groupTitle(theme, '题目', questionHits.length,
                                Icons.quiz_rounded, Colors.blue),
                            ...questionHits.map((qt) => _QuestionHit(qt)),
                          ],
                          if (annotationHits.isNotEmpty) ...[
                            _groupTitle(theme, '批注', annotationHits.length,
                                Icons.note_alt_outlined, Colors.orange),
                            ...annotationHits.map((a) => _AnnotationHit(a)),
                          ],
                          if (noteHits.isNotEmpty) ...[
                            _groupTitle(theme, '笔记', noteHits.length,
                                Icons.sticky_note_2_rounded, Colors.amber),
                            ...noteHits.map((n) => _NoteHit(n)),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _groupTitle(ThemeData theme, String label, int count, IconData icon,
      Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 8),
          Text('$count',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

class _QuestionHit extends StatelessWidget {
  const _QuestionHit(this.question);
  final Question question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          final provider = context.read<AppProvider>();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PracticePage(
                config: PracticeConfig(
                  subject: question.subject,
                  keyword: question.prompt,
                  mode: PracticeMode.practice,
                ),
                onCompleted: (result) async {
                  await provider.addHistory(result);
                },
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(question.prompt,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(question.subject.label,
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white54
                          : Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnotationHit extends StatelessWidget {
  const _AnnotationHit(this.annotation);
  final UserAnnotation annotation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MyAnnotationsPage()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(annotation.term,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(annotation.note,
                  style: TextStyle(
                      fontSize: 13,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteHit extends StatelessWidget {
  const _NoteHit(this.note);
  final Note note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = note.title;
    final content = note.content;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NotePage()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(content,
                  style: TextStyle(
                      fontSize: 13,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
