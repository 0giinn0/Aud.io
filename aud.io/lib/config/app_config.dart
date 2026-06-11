class AppConfig {
  AppConfig._();

  static const String supabaseUrl = 'https://eybaqgjkueadhojgkzib.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV5YmFxZ2prdWVhZGhvamdremliIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODExNjIzNzMsImV4cCI6MjA5NjczODM3M30.A4-8XBFp-Ey09CdzHJoLUUtqW7IriCV-ai46BQuIK0c';

  static const String webRedirectUrl = 'http://localhost:8082';

  // Listen Notes Podcast API key
  // Get yours at: https://listennotes.com/api/pricing/
  // Set environment variable: LISTEN_API_KEY=your_key_here
  // Or paste your key below (not recommended for production)
  static const String listenApiKey = String.fromEnvironment(
    'LISTEN_API_KEY',
    defaultValue: '',
  );
}
