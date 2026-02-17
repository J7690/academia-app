import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/weather_config.dart';

class WeatherEntity {
  final double temperature;
  final int weatherCode;
  final DateTime sunrise;
  final DateTime sunset;
  final double uvIndex;

  const WeatherEntity({
    required this.temperature,
    required this.weatherCode,
    required this.sunrise,
    required this.sunset,
    required this.uvIndex,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'temperature': temperature,
        'weatherCode': weatherCode,
        'sunrise': sunrise.toIso8601String(),
        'sunset': sunset.toIso8601String(),
        'uvIndex': uvIndex,
      };

  static WeatherEntity? fromOpenMeteoJson(Map<String, dynamic> json) {
    final dynamic currentRaw = json['current_weather'];
    if (currentRaw is! Map<String, dynamic>) {
      return null;
    }

    final dynamic tempRaw = currentRaw['temperature'];
    final dynamic codeRaw = currentRaw['weathercode'];

    if (tempRaw == null || codeRaw == null) {
      return null;
    }

    final double? temperature =
        tempRaw is num ? tempRaw.toDouble() : double.tryParse('$tempRaw');
    final int? weatherCode =
        codeRaw is num ? codeRaw.toInt() : int.tryParse('$codeRaw');

    if (temperature == null || weatherCode == null) {
      return null;
    }

    final dynamic dailyRaw = json['daily'];
    if (dailyRaw is! Map<String, dynamic>) {
      return null;
    }

    final List<dynamic>? sunriseList =
        dailyRaw['sunrise'] as List<dynamic>?;
    final List<dynamic>? sunsetList =
        dailyRaw['sunset'] as List<dynamic>?;
    final List<dynamic>? uvList =
        dailyRaw['uv_index_max'] as List<dynamic>?;

    if (sunriseList == null ||
        sunriseList.isEmpty ||
        sunsetList == null ||
        sunsetList.isEmpty ||
        uvList == null ||
        uvList.isEmpty) {
      return null;
    }

    final String sunriseStr = sunriseList.first.toString();
    final String sunsetStr = sunsetList.first.toString();
    final dynamic uvRaw = uvList.first;

    final DateTime? sunrise = DateTime.tryParse(sunriseStr);
    final DateTime? sunset = DateTime.tryParse(sunsetStr);
    final double? uvIndex =
        uvRaw is num ? uvRaw.toDouble() : double.tryParse('$uvRaw');

    if (sunrise == null || sunset == null || uvIndex == null) {
      return null;
    }

    return WeatherEntity(
      temperature: temperature,
      weatherCode: weatherCode,
      sunrise: sunrise,
      sunset: sunset,
      uvIndex: uvIndex,
    );
  }

  static WeatherEntity? fromCacheJson(Map<String, dynamic> json) {
    final dynamic tempRaw = json['temperature'];
    final dynamic codeRaw = json['weatherCode'];
    final dynamic sunriseRaw = json['sunrise'];
    final dynamic sunsetRaw = json['sunset'];
    final dynamic uvRaw = json['uvIndex'];

    final double? temperature =
        tempRaw is num ? tempRaw.toDouble() : double.tryParse('$tempRaw');
    final int? weatherCode =
        codeRaw is num ? codeRaw.toInt() : int.tryParse('$codeRaw');
    final DateTime? sunrise =
        DateTime.tryParse(sunriseRaw?.toString() ?? '');
    final DateTime? sunset =
        DateTime.tryParse(sunsetRaw?.toString() ?? '');
    final double? uvIndex =
        uvRaw is num ? uvRaw.toDouble() : double.tryParse('$uvRaw');

    if (temperature == null ||
        weatherCode == null ||
        sunrise == null ||
        sunset == null ||
        uvIndex == null) {
      return null;
    }

    return WeatherEntity(
      temperature: temperature,
      weatherCode: weatherCode,
      sunrise: sunrise,
      sunset: sunset,
      uvIndex: uvIndex,
    );
  }
}

/// Service bas niveau pour interroger l'API météo Open-Meteo.
class WeatherService {
  final http.Client _client;

  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  /// Récupère la météo courante à partir de coordonnées (Open-Meteo).
  /// Retourne un WeatherEntity typé ou null en cas d'erreur.
  Future<WeatherEntity?> getCurrentWeatherByCoordinates({
    required double latitude,
    required double longitude,
    String? language,
    String units = WeatherConfig.defaultUnits,
  }) async {
    final uri = Uri.parse(WeatherConfig.baseUrl).replace(
      queryParameters: <String, String>{
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current_weather': 'true',
        'daily': 'sunrise,sunset,uv_index_max',
        'timezone': 'auto',
        'forecast_days': '1',
      },
    );

    try {
      final http.Response response =
          await _client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return WeatherEntity.fromOpenMeteoJson(decoded);
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
