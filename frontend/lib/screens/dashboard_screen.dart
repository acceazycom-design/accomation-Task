import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map? _stats;
  List _workload = [];
  List _activity = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.getDashboardStats(),
        ApiService.getWorkload(),
        ApiService.getActivity(),
      ]);
      setState(() { _stats = results[0]; _workload = results[1] as List; _activity = results[2] as List; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statsRow(),
          const SizedBox(height: 16),
          _sectionTitle('Team workload'),
          _workloadCard(),
          const SizedBox(height: 16),
          _sectionTitle('Recent activity'),
          _activityCard(),
        ],
      ),
    );
  }

  Widget _statsRow() {
    final t = _stats?['tasks'] ?? {};
    final stats = [
      {'label': 'Total tasks', 'value': t['total'] ?? 0, 'color': const Color(0xFF534AB7)},
      {'label': 'In progress', 'value': t['in_progress'] ?? 0, 'color': Colors.blue},
      {'label': 'Completed', 'value': t['done'] ?? 0, 'color': Colors.green},
      {'label': 'Overdue', 'value': t['overdue'] ?? 0, 'color': Colors.red},
    ];
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.8,
      children: stats.map((s) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${s['value']}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: s['color'] as Color)),
            Text('${s['label']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
  );

  Widget _workloadCard() => Card(
    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12, width: 0.5)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: _workload.take(6).map((m) {
          final total = (m['total_tasks'] ?? 1) as int;
          final open = (m['open_tasks'] ?? 0) as int;
          final pct = total > 0 ? open / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              CircleAvatar(radius: 14, backgroundColor: const Color(0xFFEEEDFE),
                  child: Text(m['avatar'] ?? '?', style: const TextStyle(fontSize: 10, color: Color(0xFF3C3489), fontWeight: FontWeight.w600))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: pct.clamp(0.0, 1.0), backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF534AB7)), minHeight: 5,
                    borderRadius: BorderRadius.circular(4)),
              ])),
              const SizedBox(width: 10),
              Text('$open tasks', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
          );
        }).toList(),
      ),
    ),
  );

  Widget _activityCard() => Card(
    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12, width: 0.5)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: _activity.isEmpty
          ? const Text('No recent activity', style: TextStyle(color: Colors.grey))
          : Column(
              children: _activity.take(8).map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  CircleAvatar(radius: 14, backgroundColor: const Color(0xFFEEEDFE),
                      child: Text(a['avatar'] ?? '?', style: const TextStyle(fontSize: 10, color: Color(0xFF3C3489)))),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${a['name']} — ${a['title'] ?? ''}',
                      style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                  Text(a['type'] == 'hours_logged' ? '${a['status']}h' : a['status'] ?? '',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              )).toList(),
            ),
    ),
  );
}
