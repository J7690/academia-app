/// Configuration Supabase validée via système automatisé
/// Utilise les méthodes validées du dossier .windsurf
class SupabaseConfig {
  // URL de ton projet Supabase
  static const String url = 'https://thevdfcwlcqzdoybfvgs.supabase.co';

  // Clé ANON PUBLIC (clé publique, utilisée côté Flutter)
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0.8Zm6i6UaOrEOUvOafHOXOf0UiPOdp7on-aajYASOdk8';

  // Clé SERVICE ROLE (secrète, réservée au backend et à certaines opérations admin)
  static const String serviceKey = '';

  static const String frontendBaseUrl = 'https://dulcet-snickerdoodle-915a6b.netlify.app';
  static const String authCallbackUrl = '${frontendBaseUrl}/auth/callback';
}
