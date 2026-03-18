import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'https://api.accomation.io/api';
  static const _storage = FlutterSecureStorage();

  static Future<String?> getToken() => _storage.read(key: 'token');
  static Future<void> saveToken(String token) => _storage.write(key: 'token', value: token);
  static Future<void> clearToken() => _storage.delete(key: 'token');

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> get(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: await _headers());
    return _handle(res);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse('$baseUrl$path'),
        headers: await _headers(), body: jsonEncode(body));
    return _handle(res);
  }

  static Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(Uri.parse('$baseUrl$path'),
        headers: await _headers(), body: jsonEncode(body));
    return _handle(res);
  }

  static Future<dynamic> delete(String path) async {
    final res = await http.delete(Uri.parse('$baseUrl$path'), headers: await _headers());
    return _handle(res);
  }

  static dynamic _handle(http.Response res) {
    final data = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw Exception(data['error'] ?? 'Request failed (${res.statusCode})');
  }

  // AUTH
  static Future<Map> login(String email, String password) async {
    final data = await post('/auth/login', {'email': email, 'password': password});
    await saveToken(data['token']);
    return data;
  }
  static Future<void> logout() => clearToken();
  static Future<dynamic> getMe() => get('/auth/me');
  static Future<dynamic> getTeam() => get('/auth/team');
  static Future<dynamic> inviteMember(String name, String email, String role) =>
      post('/auth/invite', {'name': name, 'email': email, 'role': role});

  // TASKS
  static Future<List> getTasks({String? status, String? assignedTo, String? projectId}) async {
    String q = '/tasks?';
    if (status != null) q += 'status=$status&';
    if (assignedTo != null) q += 'assigned_to=$assignedTo&';
    if (projectId != null) q += 'project_id=$projectId&';
    final data = await get(q);
    return data as List;
  }
  static Future<List> getMyTasks() async => (await get('/tasks/my')) as List;
  static Future<dynamic> getTask(String id) => get('/tasks/$id');
  static Future<dynamic> createTask(Map<String, dynamic> task) => post('/tasks', task);
  static Future<dynamic> updateTask(String id, Map<String, dynamic> updates) => patch('/tasks/$id', updates);
  static Future<dynamic> addComment(String taskId, String content) =>
      post('/tasks/$taskId/comments', {'content': content});

  // TIMESHEETS
  static Future<List> getMyTimesheets({String? from, String? to}) async {
    String q = '/timesheets/my?';
    if (from != null) q += 'from=$from&';
    if (to != null) q += 'to=$to&';
    return (await get(q)) as List;
  }
  static Future<List> getTeamTimesheets({String? from, String? to}) async {
    String q = '/timesheets/team?';
    if (from != null) q += 'from=$from&';
    if (to != null) q += 'to=$to&';
    return (await get(q)) as List;
  }
  static Future<dynamic> logHours(String taskId, double hours, String date, String desc) =>
      post('/timesheets', {'task_id': taskId, 'hours': hours, 'date': date, 'description': desc});
  static Future<dynamic> startTimer(String taskId) => post('/timesheets/start', {'task_id': taskId});
  static Future<dynamic> stopTimer(String timesheetId) => patch('/timesheets/$timesheetId/stop', {});
  static Future<List> getTeamSummary() async => (await get('/timesheets/summary')) as List;

  // DASHBOARD
  static Future<dynamic> getDashboardStats() => get('/dashboard/stats');
  static Future<List> getWorkload() async => (await get('/dashboard/workload')) as List;
  static Future<List> getActivity() async => (await get('/dashboard/activity')) as List;
  static Future<List> getNotifications() async => (await get('/dashboard/notifications')) as List;

  // PROJECTS
  static Future<List> getProjects() async => (await get('/projects')) as List;
  static Future<dynamic> createProject(String name, String desc) =>
      post('/projects', {'name': name, 'description': desc});
  static Future<List> getSprints(String projectId) async =>
      (await get('/projects/$projectId/sprints')) as List;
  static Future<dynamic> createSprint(String projectId, String name, String start, String end) =>
      post('/projects/$projectId/sprints', {'name': name, 'start_date': start, 'end_date': end});
}
