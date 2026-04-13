/// Configuration for environment variables.
/// Use --dart-define-from-file=.env during flutter build/run.
///
/// IMPORTANT: Do NOT hardcode production secrets as default values here.
class EnvConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String cloudflareWorkerUrl = String.fromEnvironment(
    'CLOUDFLARE_WORKER_URL',
    defaultValue: '',
  );

  static const String webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://moimoi-green.vercel.app',
  );
}
