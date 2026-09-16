import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../../commerce/domain/commerce_engine.dart';

final biddingProvider = ChangeNotifierProvider.autoDispose
    .family<BiddingRepository, String>(
        (ref, account) => BiddingRepository()..refresh());

/// Account scoped server records; never caches other buyers' sealed prices.
class BiddingRepository extends ChangeNotifier {
  BiddingRepository({ApiClient? api}) : api = api ?? ApiClient();
  final ApiClient api;
  List<Record> sessions = [];
  bool loading = false, busy = false, disposed = false;
  String? error;
  Duration serverOffset = Duration.zero;
  DateTime get serverNow => DateTime.now().toUtc().add(serverOffset);
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }

  void changed() {
    if (!disposed) notifyListeners();
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    changed();
    try {
      sessions = records(await api.get('/bidding'));
      if (sessions.isNotEmpty) {
        serverOffset = DateTime.parse(sessions.first['server_now'])
            .difference(DateTime.now().toUtc());
      }
      error = null;
    } catch (e) {
      error = '$e';
    }
    loading = false;
    changed();
  }

  Future<Record> matches(String product, {String? sessionId}) async =>
      Map<String, dynamic>.from(await api.get('/bidding/matches/$product',
              queryParameters: {if (sessionId != null) 'session_id': sessionId})
          as Map);
  Future<Record> save(Record data, {String? id}) async {
    if (busy) throw WorkflowError('Please wait for the current request');
    busy = true;
    changed();
    try {
      final result = Map<String, dynamic>.from((id == null
          ? await api.post('/bidding', data: data)
          : await api.put('/bidding/$id', data: data)) as Map);
      adopt(result);
      return result;
    } finally {
      busy = false;
      changed();
    }
  }

  Future<Record> act(Record session, String action,
      [Record fields = const {}]) async {
    if (busy) throw WorkflowError('Please wait for the current request');
    busy = true;
    changed();
    try {
      final result = Map<String, dynamic>.from(await api
          .post('/bidding/${session['id']}/actions', data: {
        'revision': session['revision'],
        'action': action,
        ...fields
      }) as Map);
      adopt(result);
      return result;
    } finally {
      busy = false;
      changed();
    }
  }

  void adopt(Record session) {
    sessions = [session, ...sessions.where((s) => s['id'] != session['id'])];
    error = null;
    changed();
  }
}
