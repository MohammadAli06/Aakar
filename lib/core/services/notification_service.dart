import 'api_client.dart';

/// Account-scoped notifications.
///
/// Each row belongs to one recipient and is created by the other participant
/// acting on something shared (currently an inquiry message), so the alerts bell
/// keeps working after a refresh instead of losing a device-local list.
class NotificationService {
  final ApiClient _api;

  NotificationService({ApiClient? api}) : _api = api ?? apiClient;

  static List<Map<String, dynamic>> _asList(dynamic data) => (data as List)
      .map((row) => (row as Map).cast<String, dynamic>())
      .toList();

  Future<List<Map<String, dynamic>>> mine() async =>
      _asList(await _api.get('/notifications/'));

  /// Marks this account's notifications read and returns the updated list.
  Future<List<Map<String, dynamic>>> markAllRead() async =>
      _asList(await _api.post('/notifications/read'));
}
