import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../shared/models/account.dart';
import 'account_service.dart';
import 'auth_service.dart';

enum SessionStatus {
  /// Still resolving the stored Firebase session / backend account.
  loading,

  /// No Firebase identity.
  signedOut,

  /// Firebase identity exists but signup was never completed on the backend.
  unregistered,

  /// Authenticated, with a server-selected account role.
  signedIn,
  unavailable,
}

/// Owns the authentication session: whether a Firebase identity is present, and
/// which backend account it maps to. The router guard reads [status].
class SessionController extends ChangeNotifier {
  SessionController({AccountService? accounts, Stream<bool>? identityChanges})
      : _accounts = accounts ?? AccountService() {
    _ready = Completer<void>();
    _subscription =
        (identityChanges ?? _firebaseIdentity()).listen(_onIdentityChanged);
  }

  /// Pre-authenticated session, for tests and previews. No Firebase involved.
  SessionController.signedIn(Account account, {AccountService? accounts})
      : _accounts = accounts ?? AccountService(),
        _account = account,
        _hasIdentity = true,
        _loading = false {
    _ready = Completer<void>()..complete();
    _subscription = const Stream<bool>.empty().listen((_) {});
  }

  /// Explicitly signed-out session, for tests and previews. No Firebase involved.
  SessionController.signedOut({AccountService? accounts})
      : _accounts = accounts ?? AccountService(),
        _hasIdentity = false,
        _loading = false {
    _ready = Completer<void>()..complete();
    _subscription = const Stream<bool>.empty().listen((_) {});
  }

  final AccountService _accounts;
  late final StreamSubscription<bool> _subscription;
  late final Completer<void> _ready;

  Account? _account;
  bool _hasIdentity = false;
  bool _loading = true;
  bool _registering = false;
  bool _disposed = false;
  bool _unavailable = false;
  int _generation = 0;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static Stream<bool> _firebaseIdentity() =>
      AuthService.authStateChanges().map((user) => user != null);

  Account? get account => _account;
  AccountRole? get role => _account?.role;
  bool get loading => _loading;
  bool get registering => _registering;
  bool get signedIn => status == SessionStatus.signedIn;

  /// Completes after the first session resolution attempt.
  Future<void> get ready => _ready.future;

  SessionStatus get status {
    if (_loading) return SessionStatus.loading;
    if (!_hasIdentity) return SessionStatus.signedOut;
    if (_unavailable) return SessionStatus.unavailable;
    if (_account == null) return SessionStatus.unregistered;
    return SessionStatus.signedIn;
  }

  /// Whether the account has the minimum profile its role requires.
  bool get profileComplete {
    final account = _account;
    if (account == null) return false;
    final name = account.name?.trim() ?? '';
    if (account.state?.trim().isEmpty ?? true) return false;
    if (account.role == AccountRole.artisan) return name.isNotEmpty;
    final business = account.businessName?.trim() ?? '';
    return name.isNotEmpty && business.isNotEmpty;
  }

  Future<void> _onIdentityChanged(bool hasIdentity) async {
    if (_disposed) return;
    final generation = ++_generation;
    _hasIdentity = hasIdentity;
    _unavailable = false;

    if (!hasIdentity) {
      _account = null;
      _loading = false;
      _completeReady();
      _notify();
      return;
    }

    _loading = true;
    _notify();
    try {
      final account = await _accounts.me();
      if (generation != _generation || _disposed) return;
      _account = account;
    } catch (_) {
      if (generation != _generation || _disposed) return;
      _account = null;
      _unavailable = true;
    }
    if (_disposed) return;
    _loading = false;
    _completeReady();
    _notify();
  }

  Future<void> resolveIdentity() => _onIdentityChanged(true);

  void _completeReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Creates the account with an initial role for the current Firebase identity.
  Future<Account> register(AccountRole role) async {
    final generation = _generation;
    _registering = true;
    _notify();
    try {
      final account = await _accounts.register(role);
      if (_disposed || generation != _generation) return account;
      _generation++;
      _account = account;
      _hasIdentity = true;
      _loading = false;
      _unavailable = false;
      _completeReady();
      return account;
    } finally {
      _registering = false;
      _notify();
    }
  }

  /// Re-reads the account from the backend (e.g. after a profile update).
  Future<Account?> refresh() async {
    if (!_hasIdentity) return null;
    final generation = _generation;
    final account = await _accounts.me();
    if (_disposed || generation != _generation) return null;
    _account = account;
    _notify();
    return _account;
  }

  Future<void> signOut() async {
    await AuthService.signOut();
    await _onIdentityChanged(false);
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    super.dispose();
  }
}
