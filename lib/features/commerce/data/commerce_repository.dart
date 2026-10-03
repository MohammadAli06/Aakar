import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/api_client.dart';
import '../../../core/services/inquiry_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/requirement_service.dart';
import '../../../shared/models/account.dart';
import '../domain/commerce_engine.dart';

final commerceProvider =
    ChangeNotifierProvider<CommerceRepository>((ref) => CommerceRepository());

/// Owns the commerce workspace.
///
/// The artisan catalogue, the buyer's requirements and the buyer↔artisan
/// inquiry/quotation exchange live in the shared backend database and belong to
/// the signed-in account, so `product`, `availability`, `publish`,
/// `requirement`, `inquiry`, `capacity`, `quote`, `accept` and the conversation
/// go through [ProductService]/[RequirementService]/[InquiryService]. Orders an
/// accepted quotation creates are read from the backend; their production,
/// payment, shipping and inspection steps still run on the local demo engine and
/// are labelled as such in the UI.
class CommerceRepository extends ChangeNotifier {
  CommerceRepository(
      {ProductService? catalogue,
      RequirementService? requirements,
      InquiryService? inquiries,
      OrderService? orders,
      NotificationService? notifications})
      : _catalogue = catalogue ?? ProductService(),
        _requirements = requirements ?? RequirementService(),
        _inquiries = inquiries ?? InquiryService(),
        _orders = orders ?? OrderService(),
        _notifications = notifications ?? NotificationService() {
    load();
  }

  final ProductService _catalogue;
  final RequirementService _requirements;
  final InquiryService _inquiries;
  final OrderService _orders;
  final NotificationService _notifications;

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

  String get actor => role == 'buyer' ? (_accountId ?? 'buyer') : artisanId;
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

  /// The account's own notifications.
  ///
  /// A signed-in account reads only server rows for its user id; an offline
  /// demo keeps its device-local rows. The two are never mixed, so the bell's
  /// unread count cannot include a demo row the backend cannot mark read.
  List<Record> get notifications => table('notifications')
      .where((r) => signedIn
          ? r['server'] == true &&
              r['role'] == role &&
              r['account_id'] == _accountId
          : r['role'] == role && r['actor_id'] == actor)
      .toList();
  List<Record> get products => table('products')
      .where((r) => role == 'artisan'
          ? r['artisan_id'] == actor
          : r['status'] == 'published')
      .toList();

  /// Bring a persisted bidding handoff into the existing quotation workspace.
  /// Never overwrite a quote already edited on this device or auto-accept it.
  Future<void> importBiddingInquiry(Record inquiry, Record product) async {
    if (!signedIn ||
        ![inquiry['artisan_id'], inquiry['buyer_id']].contains(actor)) {
      throw WorkflowError('Only a participant can open this quotation');
    }
    if (connected) {
      throw WorkflowError(
          'Disconnect the separate demo workspace before opening an account quotation');
    }
    final inqCopy = copyRecord(inquiry);
    if (inqCopy['capacity_status'] == 'pending' ||
        inqCopy['capacity_status'] == null) {
      inqCopy['capacity_status'] = 'confirmed';
    }
    inqCopy['confirmed_quantity'] ??= inqCopy['quantity'];
    inqCopy['offered_lead_days'] ??= inqCopy['lead_days'];

    for (final entry in {'products': product, 'inquiries': inqCopy}.entries) {
      final rows = table(entry.key);
      final idx = rows.indexWhere((row) => row['id'] == entry.value['id']);
      if (idx < 0) {
        rows.add(copyRecord(entry.value));
      } else {
        final existing = rows[idx];
        final exQuotes = records(existing['quotes']);
        final newQuotes = records(entry.value['quotes']);
        rows[idx] = {
          ...entry.value,
          ...existing,
          'quotes': newQuotes.length >= exQuotes.length ? newQuotes : exQuotes,
          'capacity_status': (existing['capacity_status'] == 'confirmed' ||
                  existing['capacity_status'] == 'partial')
              ? existing['capacity_status']
              : entry.value['capacity_status'],
          'confirmed_quantity': existing['confirmed_quantity'] ??
              entry.value['confirmed_quantity'],
          'offered_lead_days':
              existing['offered_lead_days'] ?? entry.value['offered_lead_days'],
        };
      }
      state[entry.key] = rows;
    }
    final profiles = table('profiles');
    for (final entry in {
      inquiry['buyer_id']: inquiry['buyer_name'],
      inquiry['artisan_id']: 'Artisan'
    }.entries) {
      if (!profiles.any((p) => p['id'] == entry.key)) {
        profiles.add({
          'id': entry.key,
          'name': entry.value,
          'verification': 'not_submitted'
        });
      }
    }
    state['profiles'] = profiles;
    await _persist();
    notifyListeners();
  }

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
    final sameAccount = _accountId == account.id && role == name;
    if (sameAccount && _storedLanguage(actor) == account.languagePref) return;
    _accountId = account.id;
    role = name;
    final profileId = '${account.profile['id'] ?? ''}';
    if (profileId.isNotEmpty) artisanId = profileId;
    _rememberProfile(account);
    await _persist();
    notifyListeners();
    // A language change only rewrites the local profile row the offline demo
    // bridge reads; the shared records do not need fetching again for it.
    if (!sameAccount) await hydrate();
  }

  String _storedLanguage(String id) {
    for (final p in table('profiles')) {
      if (p['id'] == id) return '${p['language_pref'] ?? ''}';
    }
    return '';
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
      'location':
          location.isEmpty ? '${existing?['location'] ?? ''}' : location,
      'craft': '${existing?['craft'] ?? account.craftCategory ?? ''}',
      'experience': existing?['experience'] ?? 0,
      'story': '${existing?['story'] ?? ''}',
      'verification': account.isVerified
          ? 'verified'
          : '${existing?['verification'] ?? 'not_submitted'}',
      'phone': account.phone ?? '',
      'language_pref': account.languagePref,
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
    } on ApiError catch (e) {
      error = e.detail ??
          'The shared records could not be loaded. Check that the backend is reachable.';
      notifyListeners();
      return false;
    } catch (_) {
      error = 'The shared records could not be loaded.';
      notifyListeners();
      return false;
    }
    // Requirements, inquiries and orders are separate endpoints. Loading them
    // one by one keeps a single failing endpoint from blanking the records the
    // others already returned (e.g. an older backend with no orders table).
    var complete = true;
    if (role == 'buyer') {
      if (!await _adoptSafely(_requirements.mine, _adoptRequirements))
        complete = false;
    }
    if (!await _adoptSafely(_inquiries.mine, _adoptInquiries)) complete = false;
    if (!await _adoptSafely(_orders.mine, _adoptOrders)) complete = false;
    if (!await _adoptSafely(_notifications.mine, _adoptNotifications)) {
      complete = false;
    }
    error = complete ? null : 'Some shared records could not be refreshed.';
    notifyListeners();
    return complete;
  }

  /// Adopts one collection on its own; a failure leaves the current rows alone.
  Future<bool> _adoptSafely(Future<List<Map<String, dynamic>>> Function() fetch,
      void Function(List<Map<String, dynamic>>) adopt) async {
    try {
      adopt(await fetch());
      return true;
    } catch (_) {
      return false;
    }
  }

  void _adoptRequirements(List<Map<String, dynamic>> rows) {
    state['requirements'] = rows
        .map((row) => Map<String, dynamic>.from(row)..['server'] = true)
        .toList();
  }

  /// The signed-in account's inquiries. Server rows from the DB are authoritative.
  /// Device-local inquiries are filtered out to prevent deleted DB records from persisting.
  /// Only real bidding session handoffs (id starts with 'bid-') are preserved.
  void _adoptInquiries(List<Map<String, dynamic>> rows) {
    final shared = rows
        .map((row) => Map<String, dynamic>.from(row)..['server'] = true)
        .toList();
    final sharedIds = shared.map((r) => '${r['id']}').toSet();
    final localBidding = table('inquiries')
        .where((row) =>
            !sharedIds.contains('${row['id']}') &&
            '${row['id']}'.startsWith('bid-'))
        .toList();
    state['inquiries'] = [...shared, ...localBidding];
  }

  /// Orders created by accepting a shared quotation, plus any active bidding order.
  void _adoptOrders(List<Map<String, dynamic>> rows) {
    final shared = rows
        .map((row) => Map<String, dynamic>.from(row)..['server'] = true)
        .toList();
    final sharedIds = shared.map((r) => '${r['id']}').toSet();
    final localBidding = table('orders')
        .where((row) =>
            !sharedIds.contains('${row['id']}') &&
            '${row['id']}'.startsWith('bid-'))
        .toList();
    state['orders'] = [...shared, ...localBidding];
  }

  /// The account's notifications. Server rows are authoritative; a signed-in
  /// account has no device-local demo notifications to merge in.
  void _adoptNotifications(List<Map<String, dynamic>> rows) {
    state['notifications'] = rows
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

  /// Product, requirement and inquiry actions the shared backend owns.
  static const _catalogueActions = {'product', 'availability', 'publish'};
  static const _requirementActions = {'requirement'};

  /// Order lifecycle actions — artisan-side mutations route to PATCH /orders/{id}/*
  static const _orderActions = {
    'order_accept',
    'order_decline',
    'production_plan',
    'production_progress',
    'production_complete',
    'packaging',
    'dispatch_order',
    'delivery_status',
    // Settlement and closure belong to the shared order too, so a recorded
    // payment or an accepted inspection survives a refresh.
    'pay',
    'inspection',
    'complete',
  };
  static const _inquiryActions = {
    'inquiry',
    'message',
    'capacity',
    'quote',
    'accept',
    'reject_quote',
    'request_change',
    'sample'
  };

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
      } else if (signedIn &&
          _inquiryActions.contains(action) &&
          (action == 'inquiry' || _serverOwned('inquiries', input))) {
        // A buyer's inquiry and everything the two participants do on it belong
        // to the shared record, so the artisan sees the same conversation.
        await _inquiryAct(action, input);
        await hydrate();
      } else if (signedIn &&
          _orderActions.contains(action) &&
          _serverOwned('orders', input)) {
        // Artisan order lifecycle mutations route to dedicated PATCH endpoints.
        await _orderAct(action, input);
        await hydrate();
      } else if (signedIn && action == 'read_notifications') {
        // The bell's "mark all as read" belongs to the account, not the device.
        _adoptNotifications(await _notifications.markAllRead());
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

  /// Inquiry, capacity, message and quotation actions the shared backend owns.
  /// The on-device demo workspace keeps its own copy while nobody is signed in.
  Future<void> _inquiryAct(String action, Record input) async {
    final id = '${input['id'] ?? ''}';
    switch (action) {
      case 'inquiry':
        final draft = Map<String, dynamic>.from(input)..remove('id');
        draft['reference_image'] = await _requirements
            .resolveImage('${input['reference_image'] ?? ''}');
        await _inquiries.create(draft);
      case 'message':
        await _inquiries.act(id, 'messages', {
          'text': input['text'],
          'translation': input['translation'],
          'attachment': input['attachment'],
          'provenance': input['provenance'],
          'target_language': input['target_language'],
        });
      case 'capacity':
        await _inquiries.act(id, 'capacity', {
          'status': input['status'],
          'quantity': input['quantity'],
          'lead_days': input['lead_days'],
        });
      case 'quote':
        await _inquiries.act(
            id, 'quote', Map<String, dynamic>.from(input)..remove('id'));
      case 'accept':
        await _inquiries.act(id, 'accept', {'quote_id': input['quote_id']});
      case 'reject_quote':
        await _inquiries.act(id, 'reject', {});
      case 'request_change':
        await _inquiries.act(id, 'request-change',
            Map<String, dynamic>.from(input)..remove('id'));
      case 'sample':
        await _inquiries.act(id, 'sample', {
          'status': input['status'],
          'evidence': input['evidence'],
          'terms': input['terms'],
          'note': input['note'],
        });
    }
  }

  /// Routes artisan order lifecycle actions to the PATCH /orders/{id}/* endpoints.
  Future<void> _orderAct(String action, Record input) async {
    final id = '${input['id'] ?? ''}';
    if (id.isEmpty) throw WorkflowError('Order id is required');
    // These go through the account client (Firebase token + API base URL), not
    // the demo workspace client: `endpoint`/`token` are only set when a demo
    // workspace is connected, so a signed-in artisan would otherwise call a
    // relative URL with no host.
    switch (action) {
      case 'order_accept':
        await _orders.act(id, 'accept', {'accepted': true});
      case 'order_decline':
        await _orders.act(id, 'accept', {'accepted': false});
      case 'production_plan':
        await _orders.act(id, 'production-plan', {
          'prod_start_date': input['prod_start_date'],
          'prod_completion_date': input['prod_completion_date'],
          if (input['daily_target'] != null)
            'daily_target': '${input['daily_target']}',
        });
      case 'production_progress':
        await _orders.act(id, 'production-progress', {
          'milestone': input['milestone'],
          'completed_units': input['completed_units'] ?? 0,
          if (input['note'] != null) 'note': input['note'],
          if (input['photo_url'] != null) 'photo_url': input['photo_url'],
        });
      case 'production_complete':
        await _orders.act(id, 'production-complete',
            {'completed_units': input['completed_units'] ?? 0});
      case 'packaging':
        await _orders.act(id, 'packaging', {
          'packaging_type': input['packaging_type'],
          'num_boxes': input['num_boxes'] ?? 1,
          if (input['total_weight'] != null)
            'total_weight': '${input['total_weight']}',
          if (input['packaging_photo'] != null)
            'packaging_photo': input['packaging_photo'],
        });
      case 'dispatch_order':
        await _orders.act(id, 'dispatch', {
          'courier': input['courier'],
          'awb_number': input['awb_number'],
          'dispatch_date': input['dispatch_date'],
          'estimated_delivery': input['estimated_delivery'],
        });
      case 'delivery_status':
        await _orders.act(id, 'delivery-status', {'status': input['status']});
      case 'pay':
        await _orders.act(id, 'pay', {
          'milestone_id': input['milestone_id'],
          if (input['reference'] != null) 'reference': '${input['reference']}',
        });
      case 'inspection':
        await _orders.act(id, 'inspection', {
          'quantity': input['quantity'] ?? 0,
          if (input['note'] != null) 'note': '${input['note']}',
        });
      case 'complete':
        await _orders.act(id, 'complete', {});
    }
  }

  Future<Record> previewMessage(String text,
      {Record? inquiry, String? productId}) async {
    if (signedIn && (inquiry == null || inquiry['server'] == true)) {
      return _inquiries.preview(text,
          inquiryId: inquiry?['id'] as String?, productId: productId);
    }
    final otherRole = role == 'buyer' ? 'artisan' : 'buyer';
    final source = profile['language_pref'];
    final target = lookup('profiles',
            '${inquiry?['${otherRole}_id'] ?? lookup('products', productId)?['artisan_id']}')?[
        'language_pref'];
    if (source == target && source != null) {
      return {'text': text, 'translation': '', 'status': 'same_language'};
    }
    if (!['en', 'hi'].contains(source) || !['en', 'hi'].contains(target)) {
      return {'text': text, 'translation': '', 'status': 'unavailable'};
    }
    final result = await assist('translate', text, '$target');
    final translation = '${result['fields']?['translation'] ?? ''}';
    return {
      'text': text,
      'translation': translation,
      'target_language': target,
      'status': translation.isEmpty ? 'unavailable' : 'review_required'
    };
  }

  Future<void> sendVoice(Record inquiry, String path, {int seconds = 0}) async {
    if (busy) throw WorkflowError('Please wait for the workspace');
    if (inquiry['server'] != true || !signedIn) {
      throw WorkflowError('Voice notes require a shared account inquiry.');
    }
    busy = true;
    notifyListeners();
    try {
      final row =
          await _inquiries.voice('${inquiry['id']}', path, seconds: seconds);
      state['inquiries'] = table('inquiries')
          .map((r) => r['id'] == row['id'] ? row : r)
          .toList();
      await _persist();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<Uint8List> voiceBytes(String id, String name) =>
      _inquiries.voiceBytes(id, name);

  Future<void> refreshInquiry(String id) async {
    if (busy || !signedIn || lookup('inquiries', id)?['server'] != true) return;
    final row = await _inquiries.get(id);
    if (busy) return;
    state['inquiries'] =
        table('inquiries').map((r) => r['id'] == id ? row : r).toList();
    notifyListeners();
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
