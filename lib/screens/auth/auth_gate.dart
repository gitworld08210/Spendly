import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../app_shell.dart';
import 'login_screen.dart';

/// Decides what to show based on auth state: the app when logged in, the login
/// screen otherwise. Rebuilds automatically on sign-in / sign-out.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthService.instance.authChanges,
      builder: (context, _) {
        final loggedIn = AuthService.instance.isLoggedIn;
        return loggedIn ? const AppShell() : const LoginScreen();
      },
    );
  }
}
