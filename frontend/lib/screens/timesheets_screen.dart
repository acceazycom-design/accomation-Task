import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class TimesheetsScreen extends StatefulWidget {
  const TimesheetsScreen({super.key});
  @override
  State<TimesheetsScreen> createState() => _TimesheetsScreenState();
}

class _TimesheetsScreenState extends State<TimesheetsScreen> {
  List _entries = [];
  List _tasks = [];
  bool _loading = true;
  String? _runningId;
  String? _selectedTask;
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final from = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 7)));
      final to = DateFormat('yyyy-MM-dd').format(now);
      final results = await Future.wait([
        ApiService.getMyTimesheets(from: from, to: to),
        ApiService.getMyTasks(),
      ]);
      setState(() { _entries = results[0] as List; _tasks = results[1] as List; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  void _startTimer() { _timer = Timer.periodic(const Duration(seconds: 1), (_) { setState(() => _seconds++); }); }
  void _stopTimerLocal() { _timer?.cancel(); setState(() => _seconds = 0); }

  String get _timerDisplay {
    final h = (_seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((_seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _onStartStop() async {
    if (_runningId == null) {
      if (_selectedTask == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a task first')));
        return;
      }
      try {
        final res = await ApiService.startTimer(_selectedTask!);
        setState(() => _runningId = res['id']);
        _startTimer();
      } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    } else {
      try {
        await ApiService.stopTimer(_runningId!);
        _stopTimerLocal();
        setState(() => _runningId = null);
        _load();
      } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    }
  }

  double _weekTotal() => _entries.fold(0.0, (s, e) => s + (double.tryParse('${e['hours']}') ?? 0));

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Timer card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.black12, width: 0.5)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      Text(_timerDisplay, style: TextStyle(
                          fontSize: 48, fontWeight: FontWeight.w300, letterSpacing: 4,
                          color: _runningId != null ? const Color(0xFF534AB7) : Colors.black87)),
                      const SizedBox(height: 4),
                      Text(_runningId != null ? 'Timer running...' : 'Ready to track',
                          style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedTask,
                        decoration: const InputDecoration(labelText: 'Select task', border: OutlineInputBorder(), isDense: true),
                        items: _tasks.map<DropdownMenuItem<String>>((t) =>
                            DropdownMenuItem(value: t['id'], child: Text(t['title'] ?? '', overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: _runningId == null ? (v) => setState(() => _selectedTask = v) : null,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _onStartStop,
                          icon: Icon(_runningId != null ? Icons.stop : Icons.play_arrow),
                          label: Text(_runningId != null ? 'Stop & save' : 'Start timer'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _runningId != null ? Colors.red : const Color(0xFF534AB7),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('This week', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('${_weekTotal().toStringAsFixed(1)} hrs total',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF534AB7), fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 10),
                ..._entries.map((e) => Card(
                  elevation: 0, margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.black12, width: 0.5)),
                  child: ListTile(
                    title: Text(e['task_title'] ?? 'Manual entry', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    subtitle: Text(e['date']?.toString().substring(0, 10) ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFEEEDFE), borderRadius: BorderRadius.circular(8)),
                      child: Text('${double.tryParse('${e['hours']}'.toString())?.toStringAsFixed(1)}h',
                          style: const TextStyle(color: Color(0xFF3C3489), fontWeight: FontWeight.w600)),
                    ),
                  ),
                )),
              ],
            ),
          );
  }
}
