/// Supabase connection config.
///
/// These are placeholders until the real project credentials are provided.
/// The anon key is safe to ship in the client; row-level security in the
/// database is what actually protects user data.
///
/// To wire up a real backend, replace [url] and [anonKey] (or pass them via
/// --dart-define at build time).
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// When false, the app runs entirely on local mock data (no network).
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
