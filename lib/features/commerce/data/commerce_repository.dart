import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/commerce_engine.dart';

final commerceProvider =
    ChangeNotifierProvider<CommerceRepository>((ref) => CommerceRepository());

class CommerceRepository extends ChangeNotifier {
  Record state = CommerceEngine.seed();
  String role = 'artisan';
  String artisanId = 'ramesh';
  String endpoint = '';
  String token = '';
  bool ready = false;
  bool busy = false;
  String? error;
  Future<void> _writes = Future.value();
  final Dio _http = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 20)));
  CommerceRepository() {
    load();
  }
  String get actor => role == 'buyer' ? 'buyer' : artisanId;
  bool get connected => endpoint.isNotEmpty;
  String get modeLabel =>
      connected ? 'Shared demo workspace' : 'On-device demo';
  List<Record> table(String name) => records(state[name]);
  Record get profile => table('profiles').firstWhere((p) => p['id'] == actor);
  Record? lookup(String name, String? id) {
    for (final r in table(name)) {
      if (r['id'] == id) return r;
    }
    return null;
  }

  List<Record> get inquiries =>
      table('inquiries').where((r) => r['${role}_id'] == actor).toList();
  List<Record> get orders =>
      table('orders').where((r) => r['${role}_id'] == actor).toList();
  List<Record> get notifications => table('notifications')
      .where((r) => r['actor_id'] == actor && r['role'] == role)
      .toList();
  List<Record> get products => table('products')
      .where((r) => role == 'artisan'
          ? r['artisan_id'] == actor
          : r['status'] == 'published')
      .toList();
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('commerce_state_v1');
      if (raw != null)
        state = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      role = prefs.getString('commerce_role') ?? 'artisan';
      artisanId = prefs.getString('commerce_artisan') ?? 'ramesh';
      endpoint = prefs.getString('commerce_endpoint') ?? '';
      token = prefs.getString('commerce_token') ?? '';
    } catch (_) {
      error =
          'Saved workspace could not be read. A demo workspace is available; reconnect to recover server data.';
    }
    ready = true;
    notifyListeners();
    if (connected) {
      try {
        await refresh();
      } catch (_) {}
    }
  }

  Future<void> _persist() {
    final snapshot = jsonEncode(state);
    final selectedRole = role;
    final selectedArtisan = artisanId;
    _writes = _writes.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('commerce_state_v1', snapshot);
      await prefs.setString('commerce_role', selectedRole);
      await prefs.setString('commerce_artisan', selectedArtisan);
      await prefs.setString('commerce_endpoint', endpoint);
      await prefs.setString('commerce_token', token);
    });
    return _writes;
  }

  Future<void> switchRole(String value) async {
    role = value;
    await _persist();
    notifyListeners();
  }

  Future<void> switchArtisan(String value) async {
    artisanId = value;
    await _persist();
    notifyListeners();
  }

  Options get _options => Options(headers: {'Authorization': 'Bearer $token'});
  Future<void> connect(String url, String key) async {
    final parsed = Uri.tryParse(url);
    if (parsed == null ||
        !['http', 'https'].contains(parsed.scheme) ||
        parsed.host.isEmpty) throw WorkflowError('Enter a valid backend URL');
    final normalized = url.replaceAll(RegExp(r'/$'), '');
    final response = await _http.get('$normalized/api/v1/workspace',
        options: Options(headers: {'Authorization': 'Bearer $key'}));
    state = Map<String, dynamic>.from(response.data as Map);
    endpoint = normalized;
    token = key;
    error = null;
    await _persist();
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!connected) return;
    try {
      final response =
          await _http.get('$endpoint/api/v1/workspace', options: _options);
      state = Map<String, dynamic>.from(response.data as Map);
      error = null;
      await _persist();
      notifyListeners();
    } on DioException catch (_) {
      error =
          'Cannot reach the shared workspace. Reconnect before making changes.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> localDemo() async {
    endpoint = '';
    token = '';
    state = CommerceEngine.seed();
    role = 'artisan';
    artisanId = 'ramesh';
    error = null;
    await _persist();
    notifyListeners();
  }

  Future<void> act(String action, Record input) async {
    if (busy || !ready) throw WorkflowError('Please wait for the workspace');
    busy = true;
    notifyListeners();
    try {
      if (connected) {
        input = Map.of(input);
        final documents = await getApplicationDocumentsDirectory();
        for (final key in [
          'image',
          'original_image',
          'evidence',
          'attachment',
          'document',
          'reference_image'
        ]) {
          final path = '${input[key] ?? ''}';
          if (path.startsWith('${documents.path}${Platform.pathSeparator}') &&
              await File(path).exists()) {
            final upload = await _http.post('$endpoint/api/v1/workspace/media',
                options: _options,
                data: FormData.fromMap(
                    {'file': await MultipartFile.fromFile(path)}));
            input[key] = '$endpoint${upload.data['path']}';
          }
        }
        final response = await _http.post('$endpoint/api/v1/workspace/actions',
            options: _options,
            data: {
              'action': action,
              'input': input,
              'role': role,
              'actor': actor,
              'version': state['version']
            });
        state = Map<String, dynamic>.from(response.data as Map);
      } else {
        state = CommerceEngine.apply(state, action, input, role, actor);
      }
      await _persist();
      error = null;
    } on DioException catch (e) {
      final detail = e.response?.data;
      error = detail is Map
          ? '${detail['detail']}'
          : 'Connection unavailable. Your change was not saved; retry after reconnecting.';
      if (e.response?.statusCode == 409) {
        try {
          await refresh();
        } catch (_) {}
      }
      throw WorkflowError(error ?? 'Please retry');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<Record> assist(String task, String text, String language) async {
    if (connected) {
      try {
        final response = await _http.post('$endpoint/api/v1/workspace/assist',
            options: _options,
            data: {'task': task, 'text': text, 'language': language});
        return Map<String, dynamic>.from(response.data as Map);
      } catch (_) {
        throw WorkflowError(
            'Assistant unavailable. You can still enter and review the details manually.');
      }
    }
    final fields = <String, dynamic>{};
    if (task == 'requirement') {
      fields['product'] = text;
      final quantity = RegExp(
              r'(\d+)\s*(?:(?:handmade|bamboo|cotton|clay|custom|हस्तनिर्मित|बाँस)\s+)*(?:units|pieces|baskets|पीस|टोकरी)',
              caseSensitive: false)
          .firstMatch(text)
          ?.group(1);
      final days = RegExp(r'(\d+)\s*(days|दिन)', caseSensitive: false)
          .firstMatch(text)
          ?.group(1);
      if (quantity != null) fields['quantity'] = number(quantity);
      if (days != null) fields['lead_days'] = number(days);
    } else if (task == 'catalog') {
      fields['description'] = text;
      for (final entry in {
        'bamboo': 'Bamboo',
        'clay': 'Clay',
        'cotton': 'Cotton',
        'बाँस': 'Bamboo',
        'मिट्टी': 'Clay',
        'कपास': 'Cotton'
      }.entries) {
        if (text.toLowerCase().contains(entry.key))
          fields['material'] = entry.value;
      }
    }
    return {
      'fields': fields,
      'ai': false,
      'provenance': task == 'translate'
          ? 'Translation unavailable offline · enter reviewed wording'
          : 'Basic extraction · review required'
    };
  }
}
