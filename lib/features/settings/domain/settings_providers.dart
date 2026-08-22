/// Settings state: theme mode and the local account.
///
/// Both are persisted in SharedPreferences so the choice survives a restart.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../identity/domain/identity_providers.dart';
import '../data/auth_repository.dart';

// ── Theme mode ────────────────────────────────────────────────────

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.dark) {
    _load();
  }

  static const _key = 'settings_theme_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = _decode(prefs.getString(_key));
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _encode(mode));
  }

  static ThemeMode _decode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.dark:
        return 'dark';
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(),
);

// ── Account ───────────────────────────────────────────────────────

class AuthState {
  const AuthState({this.account, this.hasAccount = false, this.loading = true});

  final Account? account;
  final bool hasAccount;
  final bool loading;

  bool get signedIn => account != null;

  AuthState copyWith({Account? account, bool? hasAccount, bool? loading, bool clear = false}) =>
      AuthState(
        account: clear ? null : (account ?? this.account),
        hasAccount: hasAccount ?? this.hasAccount,
        loading: loading ?? this.loading,
      );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo, this._ref) : super(const AuthState()) {
    refresh();
    // Keeps state in sync with session events we didn't trigger ourselves
    // (token refresh failure, sign-out elsewhere, restored session).
    _authSub = supa.Supabase.instance.client.auth.onAuthStateChange
        .listen((_) => refresh());
  }

  final AuthRepository _repo;
  final Ref _ref;
  late final StreamSubscription<supa.AuthState> _authSub;

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  /// Keeps the shared local identity (used by Halaqa & Al-Minbar for
  /// attribution) in step with the account name — one name across the app.
  Future<void> _syncIdentityName(String name) {
    if (name.trim().isEmpty) return Future.value();
    return _ref.read(currentUserProvider.notifier).updateName(name);
  }

  Future<void> refresh() async {
    final account = await _repo.session();
    final has = await _repo.hasAccount();
    state = AuthState(account: account, hasAccount: has, loading: false);
  }

  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final error = await _repo.signUp(name: name, email: email, password: password);
    if (error == null) {
      await refresh();
      await _syncIdentityName(name);
    }
    return error;
  }

  Future<String?> logIn({required String email, required String password}) async {
    final error = await _repo.logIn(email: email, password: password);
    if (error == null) {
      await refresh();
      final name = state.account?.name;
      if (name != null) await _syncIdentityName(name);
    }
    return error;
  }

  Future<String?> rename(String name) async {
    final error = await _repo.rename(name);
    if (error == null) {
      await refresh();
      await _syncIdentityName(name);
    }
    return error;
  }

  Future<void> logOut() async {
    await _repo.logOut();
    await refresh();
  }

  Future<void> deleteAccount() async {
    await _repo.deleteAccount();
    await refresh();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(authRepositoryProvider), ref),
);
