import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/api_client.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/requirement_service.dart';
import '../../../shared/models/account.dart';
import '../domain/commerce_engine.dart';

final commerceProvider =
    ChangeNotifierProvider<CommerceRepository>((ref) => CommerceRepository());

/// Owns the commerce workspace.
///
/// The artisan catalogue and the buyer's requirements live in the shared backend
/// database and belong to the signed-in account, so `product`, `availability`,
/// `publish` and `requirement` go through [ProductService] and
/// [RequirementService]. The remaining flows (inquiries, quotes, orders,
/// payments, shipping) still run on the local demo engine and are labelled as
/// such in the UI; they are the next thing to move.
class CommerceRepository extends ChangeNotifier {
  CommerceRepository({ProductService? catalogue, RequirementService? requirements})
      : _catalogue = catalogue ?? ProductService(),
        _requirements = requirements ?? RequirementService() {
    load();
  }

  final ProductService _catalogue;
  final RequirementService _requirements;

  Record state = CommerceEngine.seed();
  String role = 'artisan';
  String artisanId = 'ramesh';
  String endpoint = '';
  String token = '';
  bool ready = false;
  bool busy = false;
  String? error;
  String? _accountId;
  Future<void> _writes = Future.value();
  final Dio _http = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 20)));

  String get actor =>
      role == 'buyer' ? (_accountId ?? 'buyer') : artisanId;
  bool get signedIn => _accountId != null;
  bool get connected => endpoint.isNotEmpty;
  String get modeLabel => signedIn
      ? 'Aakar account'
      : connected
          ? 'Shared demo workspace'
          : 'On-device demo';
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

  /// Follows the signed-in account. Role is fixed at signup, the artisan
  /// identity is the server's, and the catalogue is loaded from the backend.
  Future<void> applyAccount(Account account) async {
    final name = account.role.name;
    if (_accountId == account.id && role == name) return;
    _accountId = account.id;
    role = name;
    final profileId = '${account.profile['id'] ?? ''}';
    if (profileId.isNotEmpty) artisanId = profileId;
    _rememberProfile(account);
    await _persist();
    notifyListeners();
    await hydrate();
  }

  /// Keeps a displayable profile row for the signed-in account so the commerce
  /// screens can show a name, location and craft.
  void _rememberProfile(Account account) {
    final id = actor;
    final location = [account.district, account.state]
        .where((part) => (part ?? '').trim().isNotEmpty)
        .join(', ');
    final profiles = records(state['profiles']);
    final index = profiles.indexWhere((p) => p['id'] == id);
    final existing = index < 0 ? null : profiles[index];
    final record = <String, dynamic>{
      'id': id,
      'role': account.role.name,
      'name': '${existing?['name'] ?? account.displayName}',
      'location': location.isEmpty ? '${existing?['location'] ?? ''}' : location,
      'craft': '${existing?['craft'] ?? account.craftCategory ?? ''}',
      'experience': existing?['experience'] ?? 0,
      'story': '${existing?['story'] ?? ''}',
      'verification': account.isVerified
          ? 'verified'
          : '${existing?['verification'] ?? 'not_submitted'}',
      'phone': account.phone ?? '',
      'document': '${existing?['document'] ?? ''}',
    };
    if (index < 0) {
      profiles.insert(0, record);
    } else {
      profiles[index] = record;
    }
    state['profiles'] = profiles;
  }

  Future<void> switchArtisan(String value) async {
    artisanId = value;
    await _persist();
    notifyListeners();
  }

  Options get _options => Options(headers: {'Authorization': 'Bearer $token'});

  /// Loads the signed-in account's shared records. Returns false when the
  /// backend could not be reached, leaving the last known records intact.
  Future<bool> hydrate() async {
    if (!signedIn) return false;
    try {
      _adopt(role == 'buyer'
          ? await _catalogue.published()
          : await _catalogue.mine());
      if (role == 'buyer') _adoptRequirements(await _requirements.mine());
      error = null;
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      error = e.detail ??
          'The shared records could not be loaded. Check that the backend is reachable.';
    } catch (_) {
      error = 'The shared records could not be loaded.';
    }
    notifyListeners();
    return false;
  }

  void _adoptRequirements(List<Map<String, dynamic>> rows) {
    state['requirements'] = rows
        .map((row) => Map<String, dynamic>.from(row)..['server'] = true)
        .toList();
  }

  void _adopt(List<Map<String, dynamic>> rows) {
    state['products'] = rows
        .map((row) => Map<String, dynamic>.from(row)..['server'] = true)
        .toList();
    final profiles = records(state['profiles']);
    for (final row in rows) {
      final id = '${row['artisan_id']}';
      if (profiles.any((p) => p['id'] == id)) continue;
      profiles.add({
        'id': id,
        'role': 'artisan',
        'name': '${row['artisan_name'] ?? 'Artisan'}',
        'location': '${row['artisan_location'] ?? ''}',
        'craft': '${row['craft'] ?? ''}',
        'experience': 0,
        'story': '',
        'verification':
            row['artisan_verified'] == true ? 'verified' : 'not_submitted',
        'phone': '',
        'document': '',
      });
    }
    state['profiles'] = profiles;
    // Demo inquiries and orders point at products that only ever existed on this
    // device. Keep the ones the shared catalogue still recognises.
    final ids = {for (final p in records(state['products'])) '${p['id']}'};
    for (final name in ['inquiries', 'orders']) {
      state[name] = records(state[name])
          .where((row) => ids.contains('${row['product_id']}'))
          .toList();
    }
  }

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
    if (signedIn) {
      await hydrate();
      return;
    }
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

  /// Product and requirement actions the shared backend owns.
  static const _catalogueActions = {'product', 'availability', 'publish'};
  static const _requirementActions = {'requirement'};

  /// Only records that came from the backend (or a brand new one) are handled
  /// there; the on-device demo records stay on the local engine until the shared
  /// records replace them.
  bool _serverOwned(String table, Record input) {
    if (!signedIn) return false;
    final id = '${input['id'] ?? ''}';
    if (id.isEmpty) return true;
    return lookup(table, id)?['server'] == true;
  }

  Future<void> act(String action, Record input) async {
    if (busy || !ready) throw WorkflowError('Please wait for the workspace');
    busy = true;
    notifyListeners();
    try {
      if (_catalogueActions.contains(action) &&
          _serverOwned('products', input)) {
        await _catalogueAct(action, input);
        await hydrate();
      } else if (role == 'buyer' &&
          _requirementActions.contains(action) &&
          _serverOwned('requirements', input)) {
        await _requirementAct(input);
        await hydrate();
      } else if (connected) {
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
        error = null;
      } else {
        state = CommerceEngine.apply(state, action, input, role, actor);
        error = null;
      }
      await _persist();
    } on ApiError catch (e) {
      error = e.detail ?? 'The backend refused the change.';
      throw WorkflowError(error!);
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

  Future<void> _catalogueAct(String action, Record input) async {
    switch (action) {
      case 'product':
        final draft = Map<String, dynamic>.from(input)..remove('id');
        final original = await _catalogue
            .resolveImage('${input['original_image'] ?? input['image'] ?? ''}');
        final enhanced =
            await _catalogue.resolveImage('${input['image'] ?? ''}');
        if (original != null) draft['original_image'] = original;
        if (enhanced != null) draft['image'] = enhanced;
        final id = '${input['id'] ?? ''}';
        if (id.isEmpty) {
          await _catalogue.create(draft);
        } else {
          await _catalogue.update(id, draft);
        }
      case 'availability':
        await _catalogue.setAvailability(
            '${input['id']}', input['available'] == true);
      case 'publish':
        await _catalogue.publish('${input['id']}');
    }
  }

  Future<void> _requirementAct(Record input) async {
    final draft = Map<String, dynamic>.from(input)..remove('id');
    draft['reference_image'] =
        await _requirements.resolveImage('${input['reference_image'] ?? ''}');
    await _requirements.create(draft);
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
