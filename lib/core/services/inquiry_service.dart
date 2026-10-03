import 'api_client.dart';
import 'dart:typed_data';

/// Inquiries and quotations in the shared backend database.
///
/// An inquiry is owned by both participants and resolved from the caller's
/// Firebase ID token: the buyer sees the ones they sent, the artisan the ones
/// addressed to them. The conversation, the capacity answer and every quotation
/// version live on the same row, so the two accounts read one record instead of
/// separate device copies.
class InquiryService {
  final ApiClient _api;

  InquiryService({ApiClient? api}) : _api = api ?? apiClient;

  static Map<String, dynamic> _asMap(dynamic data) =>
      (data as Map).cast<String, dynamic>();

  static List<Map<String, dynamic>> _asList(dynamic data) => (data as List)
      .map((row) => (row as Map).cast<String, dynamic>())
      .toList();

  /// Inquiries this account participates in, newest first.
  Future<List<Map<String, dynamic>>> mine() async =>
      _asList(await _api.get('/inquiries/'));

  Future<Map<String, dynamic>> create(Map<String, dynamic> draft) async =>
      _asMap(await _api.post('/inquiries/', data: draft));

  Future<Map<String, dynamic>> get(String id) async =>
      _asMap(await _api.get('/inquiries/$id'));

  Future<Map<String, dynamic>> preview(String text,
          {String? inquiryId, String? productId}) async =>
      _asMap(await _api.post(
          inquiryId == null
              ? '/inquiries/preview'
              : '/inquiries/$inquiryId/bridge',
          data: {
            'text': text,
            if (productId != null) 'product_id': productId
          }));

  Future<Map<String, dynamic>> voice(String id, String path,
          {int seconds = 0}) async =>
      _asMap(await _api.uploadFile('/inquiries/$id/voice', path,
          fields: {'duration': '$seconds'}));

  Future<Uint8List> voiceBytes(String id, String name) =>
      _api.getBytes('/inquiries/$id/voice/${Uri.encodeComponent(name)}');

  /// Apply a lifecycle action: `messages`, `capacity`, `quote`, `accept`,
  /// `reject` or `sample`.
  Future<Map<String, dynamic>> act(
          String id, String action, Map<String, dynamic> data) async =>
      _asMap(await _api.post('/inquiries/$id/$action', data: data));
}

/// Orders the shared backend owns. The artisan's fulfilment steps are applied
/// through the account PATCH endpoints, so they reach the buyer's copy too.
class OrderService {
  final ApiClient _api;

  OrderService({ApiClient? api}) : _api = api ?? apiClient;

  static Map<String, dynamic> _asMap(dynamic data) =>
      (data as Map).cast<String, dynamic>();

  static List<Map<String, dynamic>> _asList(dynamic data) => (data as List)
      .map((row) => (row as Map).cast<String, dynamic>())
      .toList();

  Future<List<Map<String, dynamic>>> mine() async =>
      _asList(await _api.get('/orders/'));

  Future<Map<String, dynamic>> get(String id) async =>
      _asMap(await _api.get('/orders/$id'));

  /// Apply one fulfilment step at `/orders/{id}/{segment}`, e.g. `accept`,
  /// `production-plan`, `production-progress`, `production-complete`,
  /// `packaging`, `dispatch` or `delivery-status`.
  Future<Map<String, dynamic>> act(
          String id, String segment, Map<String, dynamic> data) async =>
      _asMap(await _api.patch('/orders/$id/$segment', data: data));
}
