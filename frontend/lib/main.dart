import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/task_detail_screen.dart';
import 'screens/timesheets_screen.dart';
import 'screens/sprint_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const AccomationApp());
}

class AuthState extends ChangeNotifier {
  Map? _user;
  bool _loading = true;

  Map? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _loading;
  bool get isAdmin => _user?['role'] == 'admin';

  Future<void> init() async {
    try {
      _user = await ApiService.getMe();
    } catch (_) {
      _user = null;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final data = await ApiService.login(email, password);
    _user = data['user'];
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiService.logout();
    _user = null;
    notifyListeners();
  }
}

class AccomationApp extends StatelessWidget {
  const AccomationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthState()..init(),
      child: Consumer<AuthState>(
        builder: (context, auth, _) {
          final router = GoRouter(
            redirect: (ctx, state) {
              if (auth.isLoading) return null;
              if (!auth.isLoggedIn && state.matchedLocation != '/login') return '/login';
              if (auth.isLoggedIn && state.matchedLocation == '/login') return '/';
              return null;
            },
            routes: [
              GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
              ShellRoute(
                builder: (_, __, child) => HomeScreen(child: child),
                routes: [
                  GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
                  GoRoute(path: '/tasks', builder: (_, __) => const TasksScreen()),
                  GoRoute(path: '/tasks/:id', builder: (_, s) => TaskDetailScreen(taskId: s.pathParameters['id']!)),
                  GoRoute(path: '/timesheets', builder: (_, __) => const TimesheetsScreen()),
                  GoRoute(path: '/sprint', builder: (_, __) => const SprintScreen()),
                ],
              ),
            ],
          );
          return MaterialApp.router(
            title: 'Accomation.io',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF534AB7)),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF534AB7),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
            routerConfig: router,
          );
        },
      ),
    );
  }
}
