import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/weather_config.dart';
import '../services/weather_service.dart';

/// Provider pour la météo intelligente côté étudiant.
/// Exploite le profil étudiant (timezone, geo_latitude, geo_longitude)
/// et une API météo externe via WeatherService.
class StudentWeatherProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  final WeatherService _weatherService;

  static const String _cacheDataKey = 'weather_cache_data';
  static const String _cacheTimestampKey = 'weather_cache_timestamp';
  static const String _cacheLatKey = 'weather_cache_latitude';
  static const String _cacheLonKey = 'weather_cache_longitude';

  StudentWeatherProvider({WeatherService? weatherService})
      : _weatherService = weatherService ?? WeatherService();

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _weather;
  Map<String, dynamic>? _location;

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get weather => _weather == null
      ? null
      : Map<String, dynamic>.unmodifiable(_weather!);
  Map<String, dynamic>? get location => _location == null
      ? null
      : Map<String, dynamic>.unmodifiable(_location!);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  /// Charge la météo en utilisant directement le profil étudiant
  /// (RPC app_get_student_profile).
  Future<void> loadWeatherFromStudentProfile() async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic result = await _client.rpc('app_get_student_profile');
      if (result is! Map) {
        _setError('Profil étudiant introuvable pour la météo.');
        _weather = null;
        _location = null;
        return;
      }

      final Map<String, dynamic> profile =
          Map<String, dynamic>.from(result as Map<dynamic, dynamic>);

      final dynamic rawLat = profile['geo_latitude'];
      final dynamic rawLon = profile['geo_longitude'];
      final String? timezone = profile['timezone']?.toString();
      final String? country = profile['country']?.toString();
      final String? city = profile['city']?.toString();

      final double? latFromProfile = _toDouble(rawLat);
      final double? lonFromProfile = _toDouble(rawLon);

      final double lat = latFromProfile ?? WeatherConfig.defaultLatitude;
      final double lon = lonFromProfile ?? WeatherConfig.defaultLongitude;

      final String tz =
          (timezone != null && timezone.isNotEmpty)
              ? timezone
              : WeatherConfig.defaultTimezone;
      final String effectiveCity =
          (city != null && city.isNotEmpty) ? city : WeatherConfig.defaultCity;
      final String effectiveCountry = (country != null && country.isNotEmpty)
          ? country
          : WeatherConfig.defaultCountry;

      _location = <String, dynamic>{
        'latitude': lat,
        'longitude': lon,
        'timezone': tz,
        'country': effectiveCountry,
        'city': effectiveCity,
        'is_default_location': latFromProfile == null || lonFromProfile == null,
      };
      // 1) Tenter de charger une météo récente depuis le cache (TTL 3h)
      final Map<String, dynamic>? cached =
          await _loadCachedWeather(lat: lat, lon: lon, ignoreExpiry: false);
      if (cached != null) {
        _weather = cached;
        notifyListeners();
        return;
      }

      // 2) Appel réseau Open-Meteo
      final WeatherEntity? entity =
          await _weatherService.getCurrentWeatherByCoordinates(
        latitude: lat,
        longitude: lon,
      );

      if (entity == null) {
        // 3) Fallback offline : essayer une dernière météo sans contrainte de TTL
        final Map<String, dynamic>? stale =
            await _loadCachedWeather(lat: lat, lon: lon, ignoreExpiry: true);
        if (stale != null) {
          _weather = stale;
          notifyListeners();
          return;
        }

        _setError('Connexion requise pour charger la météo.');
        _weather = null;
        return;
      }

      final Map<String, dynamic> serialized = entity.toJson();
      await _saveWeatherCache(lat: lat, lon: lon, entity: entity);

      _weather = serialized;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _weather = null;
      _location = null;
    } finally {
      _setLoading(false);
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.'));
    }
    return null;
  }

  Future<Map<String, dynamic>?> _loadCachedWeather({
    required double lat,
    required double lon,
    required bool ignoreExpiry,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final double? cachedLat = prefs.getDouble(_cacheLatKey);
    final double? cachedLon = prefs.getDouble(_cacheLonKey);
    final String? tsString = prefs.getString(_cacheTimestampKey);
    final String? dataString = prefs.getString(_cacheDataKey);

    if (cachedLat == null ||
        cachedLon == null ||
        tsString == null ||
        dataString == null) {
      return null;
    }

    if ((cachedLat - lat).abs() > 0.0001 ||
        (cachedLon - lon).abs() > 0.0001) {
      // Les coordonnées ont changé, le cache ne correspond plus.
      return null;
    }

    final DateTime? ts = DateTime.tryParse(tsString);
    if (!ignoreExpiry) {
      if (ts == null) return null;
      final Duration delta = DateTime.now().difference(ts);
      if (delta > const Duration(hours: 3)) {
        return null;
      }
    }

    try {
      final dynamic decoded = jsonDecode(dataString);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final WeatherEntity? entity = WeatherEntity.fromCacheJson(decoded);
      if (entity == null) {
        return null;
      }
      return entity.toJson();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveWeatherCache({
    required double lat,
    required double lon,
    required WeatherEntity entity,
  }) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheDataKey,
        jsonEncode(entity.toJson()),
      );
      await prefs.setString(
        _cacheTimestampKey,
        DateTime.now().toIso8601String(),
      );
      await prefs.setDouble(_cacheLatKey, lat);
      await prefs.setDouble(_cacheLonKey, lon);
    } catch (_) {
      // En cas d'erreur de cache, on n'empêche pas l'affichage de la météo.
    }
  }
}
