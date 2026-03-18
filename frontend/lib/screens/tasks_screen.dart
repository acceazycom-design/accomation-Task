import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List _tasks = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tasks = await ApiService.getTasks(status: _filter == 'all' ? null : _filter);
      setState(() { _tasks = tasks; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _showCreateTask() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'medium';
    List members = [];
    String? assignedTo;
    try { members = await ApiService.getTeam(); } catch (_) {}

    if (!mounted) return;
    await showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('New task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Task title *', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()), maxLines: 2),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: priority,
            decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
            items: ['low','medium','high'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setS(() => priority = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Assign to', border: OutlineInputBorder()),
            items: members.map<DropdownMenuItem<String>>((m) => DropdownMenuItem(value: m['id'], child: Text(m['name']))).toList(),
            onChanged: (v) => setS(() => assignedTo = v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF534AB7)),
            onPressed: () async {
              if (titleCtrl.text.isEmpty) return;
              try {
                await ApiService.createTask({'title': titleCtrl.text, 'description': descCtrl.text, 'priority': priority, 'assigned_to': assignedTo});
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
            },
            child: const Text('Create task'),
          ),
        ]),
      )),
    );
  }

  Color _priorityColor(String? p) {
    switch (p) { case 'high': return Colors.red; case 'medium': return Colors.orange; default: return Colors.green; }
  }

  Color _statusColor(String? s) {
    switch (s) { case 'done': return Colors.green; case 'in_progress': return Colors.blue; default: return Colors.grey; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['all','todo','in_progress','done','overdue'].map((f) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f.replaceAll('_',' ')),
                    selected: _filter == f,
                    onSelected: (_) { setState(() => _filter = f); _load(); },
                    selectedColor: const Color(0xFFEEEDFE),
                    checkmarkColor: const Color(0xFF534AB7),
                  ),
                )).toList(),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                    ? const Center(child: Text('No tasks found', style: TextStyle(color: Colors.grey)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _tasks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final t = _tasks[i];
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12, width: 0.5)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                leading: Checkbox(
                                  value: t['status'] == 'done',
                                  activeColor: const Color(0xFF534AB7),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (v) async {
                                    await ApiService.updateTask(t['id'], {'status': v! ? 'done' : 'todo'});
                                    _load();
                                  },
                                ),
                                title: Text(t['title'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                                    decoration: t['status'] == 'done' ? TextDecoration.lineThrough : null)),
                                subtitle: Row(children: [
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: _priorityColor(t['priority']).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6)),
                                      child: Text(t['priority'] ?? '', style: TextStyle(fontSize: 10, color: _priorityColor(t['priority'])))),
                                  const SizedBox(width: 6),
                                  if (t['due_date'] != null) Text(t['due_date'].toString().substring(0, 10), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ]),
                                trailing: t['assigned_avatar'] != null ? CircleAvatar(radius: 14,
                                    backgroundColor: const Color(0xFFEEEDFE),
                                    child: Text(t['assigned_avatar'], style: const TextStyle(fontSize: 10, color: Color(0xFF3C3489)))) : null,
                                onTap: () => context.push('/tasks/${t['id']}'),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTask,
        backgroundColor: const Color(0xFF534AB7),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New task', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
