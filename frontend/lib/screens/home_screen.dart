import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class HomeScreen extends StatelessWidget {
  final Widget child;
  const HomeScreen({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/tasks')) return 1;
    if (loc.startsWith('/timesheets')) return 2;
    if (loc.startsWith('/sprint')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final idx = _selectedIndex(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accomation.io', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              child: Text(
                (auth.user?['avatar'] ?? 'U'),
                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF534AB7)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white24,
                    child: Text(auth.user?['avatar'] ?? 'U',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Text(auth.user?['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(auth.user?['email'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            ListTile(leading: const Icon(Icons.dashboard_outlined), title: const Text('Dashboard'), onTap: () { context.go('/'); Navigator.pop(context); }),
            ListTile(leading: const Icon(Icons.task_outlined), title: const Text('Tasks'), onTap: () { context.go('/tasks'); Navigator.pop(context); }),
            ListTile(leading: const Icon(Icons.access_time_outlined), title: const Text('Timesheets'), onTap: () { context.go('/timesheets'); Navigator.pop(context); }),
            ListTile(leading: const Icon(Icons.view_kanban_outlined), title: const Text('Sprint Board'), onTap: () { context.go('/sprint'); Navigator.pop(context); }),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign out', style: TextStyle(color: Colors.red)),
              onTap: () async { await auth.logout(); if (context.mounted) context.go('/login'); },
            ),
          ],
        ),
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) {
          const paths = ['/', '/tasks', '/timesheets', '/sprint'];
          context.go(paths[i]);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.task_outlined), selectedIcon: Icon(Icons.task), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.access_time_outlined), selectedIcon: Icon(Icons.access_time), label: 'Timesheets'),
          NavigationDestination(icon: Icon(Icons.view_kanban_outlined), selectedIcon: Icon(Icons.view_kanban), label: 'Sprint'),
        ],
      ),
    );
  }
}
