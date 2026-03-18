import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});
  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Map? _task;
  bool _loading = true;
  final _commentCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final t = await ApiService.getTask(widget.taskId);
      setState(() { _task = t; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _updateStatus(String status) async {
    await ApiService.updateTask(widget.taskId, {'status': status});
    _load();
  }

  Future<void> _addComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    await ApiService.addComment(widget.taskId, _commentCtrl.text.trim());
    _commentCtrl.clear();
    _load();
  }

  Color _priorityColor(String? p) {
    switch (p) { case 'high': return Colors.red; case 'medium': return Colors.orange; default: return Colors.green; }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_task == null) return const Scaffold(body: Center(child: Text('Task not found')));

    final comments = (_task!['comments'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Task detail'), actions: [
        PopupMenuButton<String>(
          onSelected: _updateStatus,
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'todo', child: Text('Mark as to do')),
            const PopupMenuItem(value: 'in_progress', child: Text('Mark in progress')),
            const PopupMenuItem(value: 'done', child: Text('Mark as done')),
          ],
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Title
          Text(_task!['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          // Status + priority row
          Row(children: [
            _badge(_task!['status']?.toString().replaceAll('_', ' ') ?? 'todo',
                _task!['status'] == 'done' ? Colors.green : _task!['status'] == 'in_progress' ? Colors.blue : Colors.grey),
            const SizedBox(width: 8),
            _badge(_task!['priority'] ?? 'medium', _priorityColor(_task!['priority'])),
            if (_task!['story_points'] != null && _task!['story_points'] != 0) ...[
              const SizedBox(width: 8),
              _badge('${_task!['story_points']} pts', const Color(0xFF534AB7)),
            ],
          ]),
          const SizedBox(height: 16),
          // Details card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12, width: 0.5)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                _detailRow('Assigned to', _task!['assigned_name'] ?? 'Unassigned'),
                _detailRow('Project', _task!['project_name'] ?? '—'),
                _detailRow('Due date', _task!['due_date']?.toString().substring(0, 10) ?? 'No due date'),
                _detailRow('Created by', _task!['created_name'] ?? '—'),
              ]),
            ),
          ),
          // Description
          if (_task!['description'] != null && _task!['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(_task!['description'], style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.6)),
          ],
          // Comments
          const SizedBox(height: 20),
          Text('Comments (${comments.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...comments.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 14, backgroundColor: const Color(0xFFEEEDFE),
                  child: Text(c['avatar'] ?? '?', style: const TextStyle(fontSize: 10, color: Color(0xFF3C3489)))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(c['content'] ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
              ])),
            ]),
          )),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 12, top: 8),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _commentCtrl,
            decoration: const InputDecoration(hintText: 'Add a comment...', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          )),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _addComment,
            icon: const Icon(Icons.send),
            style: IconButton.styleFrom(backgroundColor: const Color(0xFF534AB7)),
          ),
        ]),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    ]),
  );
}
