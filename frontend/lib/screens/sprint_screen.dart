import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SprintScreen extends StatefulWidget {
  const SprintScreen({super.key});
  @override
  State<SprintScreen> createState() => _SprintScreenState();
}

class _SprintScreenState extends State<SprintScreen> {
  List _projects = [];
  List _tasks = [];
  String? _selectedProject;
  String? _selectedSprint;
  List _sprints = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadProjects(); }

  Future<void> _loadProjects() async {
    try {
      final p = await ApiService.getProjects();
      setState(() { _projects = p; if (p.isNotEmpty) _selectedProject = p[0]['id']; });
      if (_selectedProject != null) await _loadSprints(_selectedProject!);
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _loadSprints(String projectId) async {
    try {
      final s = await ApiService.getSprints(projectId);
      setState(() { _sprints = s; if (s.isNotEmpty) _selectedSprint = s[0]['id']; });
      if (_selectedSprint != null) await _loadTasks();
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    try {
      final t = await ApiService.getTasks(projectId: _selectedProject);
      setState(() { _tasks = t; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  List _tasksByStatus(String status) => _tasks.where((t) => t['status'] == status).toList();

  Future<void> _moveTask(String taskId, String newStatus) async {
    await ApiService.updateTask(taskId, {'status': newStatus});
    await _loadTasks();
  }

  Color _priorityColor(String? p) {
    switch (p) { case 'high': return Colors.red; case 'medium': return Colors.orange; default: return Colors.green; }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Project + sprint selector
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedProject,
                isDense: true,
                decoration: const InputDecoration(labelText: 'Project', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                items: _projects.map<DropdownMenuItem<String>>((p) =>
                    DropdownMenuItem(value: p['id'], child: Text(p['name'] ?? '', overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) async { setState(() { _selectedProject = v; _selectedSprint = null; }); await _loadSprints(v!); },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedSprint,
                isDense: true,
                decoration: const InputDecoration(labelText: 'Sprint', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                items: _sprints.map<DropdownMenuItem<String>>((s) =>
                    DropdownMenuItem(value: s['id'], child: Text(s['name'] ?? '', overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) { setState(() => _selectedSprint = v); _loadTasks(); },
              ),
            ),
          ]),
        ),
        // Sprint stats
        Container(
          color: const Color(0xFFF5F5F7),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            _statPill('Total', '${_tasks.length}', const Color(0xFF534AB7)),
            const SizedBox(width: 8),
            _statPill('Done', '${_tasksByStatus('done').length}', Colors.green),
            const SizedBox(width: 8),
            _statPill('In progress', '${_tasksByStatus('in_progress').length}', Colors.blue),
          ]),
        ),
        // Kanban board
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kanbanColumn('To Do', 'todo', const Color(0xFF888780)),
                      const SizedBox(width: 12),
                      _kanbanColumn('In Progress', 'in_progress', Colors.blue),
                      const SizedBox(width: 12),
                      _kanbanColumn('Done', 'done', Colors.green),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _statPill(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: Text('$label: $value', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
  );

  Widget _kanbanColumn(String title, String status, Color color) {
    final tasks = _tasksByStatus(status);
    return SizedBox(
      width: 240,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: Text('${tasks.length}', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          ...tasks.map((t) => _taskCard(t, status)),
        ],
      ),
    );
  }

  Widget _taskCard(Map t, String currentStatus) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: currentStatus == 'in_progress' ? Colors.blue.shade200 : Colors.black12, width: currentStatus == 'in_progress' ? 1 : 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t['title'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
              decoration: currentStatus == 'done' ? TextDecoration.lineThrough : null,
              color: currentStatus == 'done' ? Colors.grey : Colors.black87)),
          const SizedBox(height: 8),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _priorityColor(t['priority']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(t['priority'] ?? 'low', style: TextStyle(fontSize: 10, color: _priorityColor(t['priority']))),
            ),
            const Spacer(),
            if (t['assigned_avatar'] != null)
              CircleAvatar(radius: 12, backgroundColor: const Color(0xFFEEEDFE),
                  child: Text(t['assigned_avatar'], style: const TextStyle(fontSize: 9, color: Color(0xFF3C3489)))),
          ]),
          const SizedBox(height: 8),
          // Move buttons
          Row(children: [
            if (currentStatus != 'todo')
              _moveBtn('← Back', currentStatus == 'done' ? 'in_progress' : 'todo', t['id']),
            const Spacer(),
            if (currentStatus != 'done')
              _moveBtn(currentStatus == 'todo' ? 'Start →' : 'Done ✓', currentStatus == 'todo' ? 'in_progress' : 'done', t['id']),
          ]),
        ]),
      ),
    );
  }

  Widget _moveBtn(String label, String toStatus, String taskId) => GestureDetector(
    onTap: () => _moveTask(taskId, toStatus),
    child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF534AB7), fontWeight: FontWeight.w500)),
  );
}
