import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/app_prefs.dart';
import '../../services/auth_service.dart';
import '../app_shell.dart';
import '../onboarding_screen.dart';
import 'login_screen.dart';

/// Root gate. Flow:
///   1. One-time onboarding (until the user has seen it).
///   2. Login screen when logged out.
///   3. The app when logged in.
/// Rebuilds automatically on sign-in / sign-out.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _onboardingSeen;

  @override
  void initState() {
    super.initState();
    AppPrefs.onboardingSeen().then((seen) {
      if (mounted) setState(() => _onboardingSeen = seen);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Still loading the flag.
    if (_onboardingSeen == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_onboardingSeen == false) {
      return OnboardingScreen(
        onDone: () => setState(() => _onboardingSeen = true),
      );
    }

    return StreamBuilder<AuthState>(
      stream: AuthService.instance.authChanges,
      builder: (context, _) {
        final loggedIn = AuthService.instance.isLoggedIn;
        return loggedIn ? const AppShell() : const LoginScreen();
      },
    );
  }
}
