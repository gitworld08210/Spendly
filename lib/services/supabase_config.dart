/// Supabase connection config for Spendly.
///
/// The live project's URL + anon key are baked in as defaults so the app
/// connects to the cloud out of the box. They can still be overridden at build
/// time via --dart-define (useful for staging).
///
/// The anon key is safe to ship in the client; row-level security in the
/// database is what actually protects user data.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kpkrcphebhtoagakfflc.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtwa3JjcGhlYmh0b2FnYWtmZmxjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAwODg4MTAsImV4cCI6MjEwNTY2NDgxMH0.IIYEo81QDGtv8lzRQn8QY-7o5e9RxM3hvxmA0kh66UM',
  );

  /// Always true now that real credentials ship by default.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
