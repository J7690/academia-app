class WeatherConfig {
  /// URL de base de l'API météo Open-Meteo (pas de clé API nécessaire).
  static const String baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Langue par défaut pour les descriptions.
  static const String defaultLang = 'fr';

  /// Unités par défaut (metric = °C).
  static const String defaultUnits = 'metric';

  static const double defaultLatitude = 12.3714;
  static const double defaultLongitude = -1.5197;
  static const String defaultTimezone = 'Africa/Ouagadougou';
  static const String defaultCity = 'Ouagadougou';
  static const String defaultCountry = 'Burkina Faso';
}
