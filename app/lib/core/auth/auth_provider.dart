import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user.dart';
import 'auth_service.dart';

enum AuthStatus { loading, loggedOut, loggedIn }

class AuthState {
  final AuthStatus status;
  final User? user;

  const AuthState(this.status, {this.user});
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final user = await AuthService.restoreSession();
    if (user != null) return AuthState(AuthStatus.loggedIn, user: user);
    return const AuthState(AuthStatus.loggedOut);
  }

  Future<bool> login(String username, String password) async {
    final user = await AuthService.login(username: username, password: password);
    if (user != null) {
      state = AsyncData(AuthState(AuthStatus.loggedIn, user: user));
    }
    return user != null;
  }

  Future<void> logout() async {
    await AuthService.logout();
    state = const AsyncData(AuthState(AuthStatus.loggedOut));
  }
}
