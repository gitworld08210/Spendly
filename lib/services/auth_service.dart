import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown for auth failures with a user-friendly [message].
class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Handles Spendly authentication.
///
/// Flow (matches the agreed design):
///   • Signup: [startSignup] emails a 6-digit code via the send-email-otp Edge
///     Function. [verifySignup] confirms the code — the verify-email-otp Edge
///     Function creates the auth user WITH the password (email pre-confirmed) —
///     then we sign the user in with email+password.
///   • Login: [signIn] is a plain email+password sign-in (never uses OTP).
///
/// Exposes [authChanges] so the UI can gate screens on session state.
class AuthService extends ChangeNotifier {
  AuthService._() {
    _client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  String get displayName {
    final meta = currentUser?.userMetadata;
    final name = meta?['full_name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final email = currentUser?.email ?? '';
    return email.isNotEmpty ? email.split('@').first : 'there';
  }

  // --- Signup (email OTP verification) --------------------------------------

  /// Step 1 of signup: request an email OTP. Throws [AuthException] on failure.
  Future<void> startSignup(String email) async {
    try {
      final res = await _client.functions.invoke(
        'send-email-otp',
        body: {'email': email.trim().toLowerCase()},
      );
      _throwIfFunctionError(res);
    } on FunctionException catch (e) {
      throw AuthException(_functionErrorMessage(e));
    } catch (e) {
      debugPrint('startSignup error: $e');
      throw AuthException('Could not send the verification code. Try again.');
    }
  }

  /// Step 2 of signup: verify the code (which creates the account) and sign in.
  Future<void> verifySignup({
    required String email,
    required String code,
    required String password,
    required String name,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final res = await _client.functions.invoke(
        'verify-email-otp',
        body: {
          'email': cleanEmail,
          'code': code.trim(),
          'password': password,
          'name': name.trim(),
        },
      );
      _throwIfFunctionError(res);
    } on FunctionException catch (e) {
      throw AuthException(_functionErrorMessage(e));
    }

    // Account created & email confirmed by the Edge Function → log in.
    await signIn(email: cleanEmail, password: password);
  }

  // --- Login / logout -------------------------------------------------------

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on AuthApiException catch (e) {
      throw AuthException(_prettyAuthError(e.message));
    } catch (e) {
      debugPrint('signIn error: $e');
      throw AuthException('Could not sign in. Please try again.');
    }
  }

  Future<void> signOut() => _client.auth.signOut();

  // --- Password reset -------------------------------------------------------

  /// Sends a password-reset email. Supabase emails a link/OTP the user can use
  /// to set a new password. Deep-link redirect is handled by the app scheme.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: 'com.paisatrack.paisatrack://reset-password',
      );
    } on AuthApiException catch (e) {
      throw AuthException(_prettyAuthError(e.message));
    } catch (e) {
      debugPrint('sendPasswordReset error: $e');
      throw AuthException('Could not send the reset email. Try again.');
    }
  }

  /// Verifies a recovery OTP (the 6-digit code from the reset email) and, on
  /// success, the session is elevated so [updatePassword] can be called.
  Future<void> verifyRecoveryOtp({
    required String email,
    required String code,
  }) async {
    try {
      await _client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: code.trim(),
        type: OtpType.recovery,
      );
    } on AuthApiException catch (e) {
      throw AuthException(_prettyAuthError(e.message));
    } catch (e) {
      debugPrint('verifyRecoveryOtp error: $e');
      throw AuthException('Invalid or expired code.');
    }
  }

  /// Sets a new password for the currently-recovering session.
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthApiException catch (e) {
      throw AuthException(_prettyAuthError(e.message));
    } catch (e) {
      debugPrint('updatePassword error: $e');
      throw AuthException('Could not update password. Try again.');
    }
  }

  // --- Helpers --------------------------------------------------------------

  void _throwIfFunctionError(FunctionResponse res) {
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw AuthException(data['error'].toString());
    }
    if (res.status >= 400) {
      throw AuthException('Request failed (${res.status}). Please try again.');
    }
  }

  String _functionErrorMessage(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] != null) {
      return details['error'].toString();
    }
    return 'Something went wrong. Please try again.';
  }

  String _prettyAuthError(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('invalid login')) {
      return 'Incorrect email or password.';
    }
    if (m.contains('email not confirmed')) {
      return 'Please verify your email first.';
    }
    return raw;
  }
}
