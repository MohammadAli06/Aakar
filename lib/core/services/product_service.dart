import 'dart:io';

import 'api_client.dart';

/// The product catalogue in the shared backend database.
///
/// Every call is authenticated with the caller's Firebase ID token by
/// [ApiClient], and the backend resolves the owning artisan from that identity —
/// there is no separate workspace or demo token. The returned maps are the flat
/// record shape the commerce screens already render.
class ProductService {
  final ApiClient _api;

  ProductService({ApiClient? api}) : _api = api ?? apiClient;

  static Map<String, dynamic> _asMap(dynamic data) =>
      (data as Map).cast<String, dynamic>();

  static List<Map<String, dynamic>> _asList(dynamic data) => (data as List)
      .map((row) => (row as Map).cast<String, dynamic>())
      .toList();

  /// Products owned by the authenticated artisan.
  Future<List<Map<String, dynamic>>> mine() async =>
      _asList(await _api.get('/products/'));

  /// Published products any signed-in account may browse.
  Future<List<Map<String, dynamic>>> published() async =>
      _asList(await _api.get('/catalog/published'));

  Future<Map<String, dynamic>> create(Map<String, dynamic> draft) async =>
      _asMap(await _api.post('/products/', data: draft));

  Future<Map<String, dynamic>> update(
          String id, Map<String, dynamic> draft) async =>
      _asMap(await _api.put('/products/$id', data: draft));

  Future<void> publish(String id) async =>
      await _api.post('/products/$id/publish');

  Future<Map<String, dynamic>> setAvailability(
          String id, bool available) async =>
      _asMap(await _api.post('/products/$id/availability',
          data: {'available': available}));

  /// Upload a catalogue photo and return the stored path to save with the product.
  Future<String> uploadImage(String path) async {
    final data = _asMap(await _api.uploadFile('/products/images', path));
    final stored = '${data['path'] ?? ''}';
    if (stored.isEmpty) throw ApiError(0, 'Upload returned no image path', null);
    return stored;
  }

  /// Upload [value] when it is a photo captured on this device. An already
  /// stored path is kept as-is, and anything else (a sample illustration name)
  /// is passed through untouched.
  Future<String?> resolveImage(String? value) async {
    final source = value?.trim() ?? '';
    if (source.isEmpty) return null;
    if (source.startsWith('http') || source.startsWith('/api/')) return source;
    if (await File(source).exists()) return await uploadImage(source);
    return source;
  }
}
