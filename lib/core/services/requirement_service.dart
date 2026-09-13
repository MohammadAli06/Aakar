import 'dart:io';

import 'api_client.dart';

/// Buyer requirements in the shared backend database.
///
/// A requirement is owned by the buying account and resolved from its Firebase
/// ID token, like the artisan catalogue. Posting one is not an order: it records
/// what the buyer needs so matching and quoting can follow.
class RequirementService {
  final ApiClient _api;

  RequirementService({ApiClient? api}) : _api = api ?? apiClient;

  static Map<String, dynamic> _asMap(dynamic data) =>
      (data as Map).cast<String, dynamic>();

  static List<Map<String, dynamic>> _asList(dynamic data) => (data as List)
      .map((row) => (row as Map).cast<String, dynamic>())
      .toList();

  /// Requirements posted by the authenticated buyer, newest first.
  Future<List<Map<String, dynamic>>> mine() async =>
      _asList(await _api.get('/requirements/'));

  Future<Map<String, dynamic>> create(Map<String, dynamic> draft) async =>
      _asMap(await _api.post('/requirements/', data: draft));

  /// Upload a reference image and return the stored path.
  Future<String> uploadImage(String path) async {
    final data = _asMap(await _api.uploadFile('/requirements/images', path));
    final stored = '${data['path'] ?? ''}';
    if (stored.isEmpty) throw ApiError(0, 'Upload returned no image path', null);
    return stored;
  }

  /// Upload [value] when it is a photo captured on this device. An already
  /// stored path is kept; anything else is dropped rather than storing a device
  /// path the backend could never read.
  Future<String?> resolveImage(String? value) async {
    final source = value?.trim() ?? '';
    if (source.isEmpty) return null;
    if (source.startsWith('http') || source.startsWith('/api/')) return source;
    if (await File(source).exists()) return await uploadImage(source);
    return null;
  }
}
