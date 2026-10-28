import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Wetter von Open-Meteo (kostenlos, ohne Schlüssel).
final httpClientProvider = Provider<http.Client>((ref) => http.Client());

class Place {
  const Place({required this.name, required this.lat, required this.lng});

  final String name;
  final double lat;
  final double lng;

  Map<String, Object> toMap() => {'name': name, 'lat': lat, 'lng': lng};

  static Place? fromMap(Object? m) {
    if (m is! Map) return null;
    final lat = (m['lat'] as num?)?.toDouble(),
        lng = (m['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return Place(name: m['name'] as String? ?? '', lat: lat, lng: lng);
  }
}

class DayForecast {
  const DayForecast({
    required this.date,
    required this.min,
    required this.max,
    required this.code,
    required this.rainChance,
    this.rainSum,
    this.sunrise,
    this.sunset,
    this.uvMax,
    this.windMax,
  });

  final DateTime date;
  final double min;
  final double max;
  final int code;
  final int rainChance;
  final double? rainSum;
  final DateTime? sunrise;
  final DateTime? sunset;
  final double? uvMax;
  final double? windMax;
}

class HourForecast {
  const HourForecast({
    required this.time,
    required this.temperature,
    required this.code,
    required this.rainChance,
    this.rain,
  });

  final DateTime time;
  final double temperature;
  final int code;
  final int rainChance;
  final double? rain;
}

class Weather {
  const Weather({
    required this.temperature,
    required this.code,
    required this.days,
    this.feelsLike,
    this.humidity,
    this.wind,
    this.windDirection,
    this.gusts,
    this.pressure,
    this.cloudCover,
    this.uv,
    this.hours = const [],
  });

  final double temperature;
  final int code;
  final List<DayForecast> days;
  final double? feelsLike;
  final int? humidity;
  final double? wind;
  final int? windDirection;
  final double? gusts;
  final double? pressure;
  final int? cloudCover;
  final double? uv;

  /// Stündliche Vorhersage ab jetzt.
  final List<HourForecast> hours;
}

/// Windrichtung in Grad → Himmelsrichtung.
String compass(int degrees) => const [
  'N',
  'NO',
  'O',
  'SO',
  'S',
  'SW',
  'W',
  'NW',
][((degrees % 360) / 45).round() % 8];

/// WMO-Wettercode → Beschreibung und Symbol.
(String, IconData) describeWeather(int code) => switch (code) {
  0 => ('Klar', Icons.wb_sunny_outlined),
  1 || 2 => ('Leicht bewölkt', Icons.wb_cloudy_outlined),
  3 => ('Bedeckt', Icons.cloud_outlined),
  45 || 48 => ('Nebel', Icons.foggy),
  51 || 53 || 55 || 56 || 57 => ('Nieselregen', Icons.grain),
  61 ||
  63 ||
  65 ||
  66 ||
  67 ||
  80 ||
  81 ||
  82 => ('Regen', Icons.umbrella_outlined),
  71 || 73 || 75 || 77 || 85 || 86 => ('Schnee', Icons.ac_unit),
  95 || 96 || 99 => ('Gewitter', Icons.thunderstorm_outlined),
  _ => ('Unbekannt', Icons.help_outline),
};

double? _d(Object? v) => (v as num?)?.toDouble();
int? _i(Object? v) => (v as num?)?.toInt();
Object? _at(Map<String, dynamic> m, String key, int i) {
  final list = m[key];
  return list is List && i < list.length ? list[i] : null;
}

Weather parseWeather(Map<String, dynamic> json, {DateTime? now}) {
  final current = json['current'] as Map<String, dynamic>;
  final daily = json['daily'] as Map<String, dynamic>;
  final hourly = json['hourly'] as Map<String, dynamic>? ?? const {};
  final dates = (daily['time'] as List).cast<String>();
  final hourTimes = (hourly['time'] as List?)?.cast<String>() ?? const [];
  // Die volle Stunde, in der wir gerade sind, zählt noch mit.
  final from = (now ?? DateTime.now()).subtract(const Duration(hours: 1));
  String? text(Object? v) => v is String ? v : null;
  return Weather(
    temperature: (current['temperature_2m'] as num).toDouble(),
    code: (current['weather_code'] as num).toInt(),
    feelsLike: _d(current['apparent_temperature']),
    humidity: _i(current['relative_humidity_2m']),
    wind: _d(current['wind_speed_10m']),
    windDirection: _i(current['wind_direction_10m']),
    gusts: _d(current['wind_gusts_10m']),
    pressure: _d(current['pressure_msl']),
    cloudCover: _i(current['cloud_cover']),
    uv: _d(current['uv_index']),
    days: [
      for (var i = 0; i < dates.length; i++)
        DayForecast(
          date: DateTime.parse(dates[i]),
          min: (daily['temperature_2m_min'][i] as num).toDouble(),
          max: (daily['temperature_2m_max'][i] as num).toDouble(),
          code: (daily['weather_code'][i] as num).toInt(),
          rainChance: _i(_at(daily, 'precipitation_probability_max', i)) ?? 0,
          rainSum: _d(_at(daily, 'precipitation_sum', i)),
          sunrise: DateTime.tryParse(text(_at(daily, 'sunrise', i)) ?? ''),
          sunset: DateTime.tryParse(text(_at(daily, 'sunset', i)) ?? ''),
          uvMax: _d(_at(daily, 'uv_index_max', i)),
          windMax: _d(_at(daily, 'wind_speed_10m_max', i)),
        ),
    ],
    hours: [
      for (var i = 0; i < hourTimes.length; i++)
        if (DateTime.parse(hourTimes[i]).isAfter(from))
          HourForecast(
            time: DateTime.parse(hourTimes[i]),
            temperature: _d(_at(hourly, 'temperature_2m', i)) ?? 0,
            code: _i(_at(hourly, 'weather_code', i)) ?? 0,
            rainChance: _i(_at(hourly, 'precipitation_probability', i)) ?? 0,
            rain: _d(_at(hourly, 'precipitation', i)),
          ),
    ].take(24).toList(),
  );
}

final weatherProvider =
    FutureProvider.family<Weather, ({double lat, double lng})>((ref, p) async {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '${p.lat}',
        'longitude': '${p.lng}',
        'current':
            'temperature_2m,apparent_temperature,relative_humidity_2m,'
            'weather_code,cloud_cover,pressure_msl,wind_speed_10m,'
            'wind_direction_10m,wind_gusts_10m,uv_index',
        'hourly': 'temperature_2m,precipitation_probability,precipitation,weather_code',
        'daily':
            'temperature_2m_max,temperature_2m_min,weather_code,'
            'precipitation_probability_max,precipitation_sum,sunrise,sunset,'
            'uv_index_max,wind_speed_10m_max',
        'timezone': 'auto',
        'forecast_days': '7',
      });
      final res = await ref.watch(httpClientProvider).get(uri);
      if (res.statusCode != 200) {
        throw Exception('Wetter nicht erreichbar (${res.statusCode})');
      }
      return parseWeather(jsonDecode(res.body) as Map<String, dynamic>);
    });

Future<List<Place>> searchPlaces(http.Client client, String query) async {
  final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
    'name': query,
    'count': '6',
    'language': 'de',
  });
  final res = await client.get(uri);
  if (res.statusCode != 200) return const [];
  final results =
      (jsonDecode(res.body) as Map<String, dynamic>)['results'] as List? ??
      const [];
  return [
    for (final r in results.cast<Map<String, dynamic>>())
      Place(
        name: [
          r['name'],
          r['admin1'],
          r['country'],
        ].whereType<String>().toSet().join(', '),
        lat: (r['latitude'] as num).toDouble(),
        lng: (r['longitude'] as num).toDouble(),
      ),
  ];
}

/// Ortsname zu Koordinaten (OpenStreetMap Nominatim, ohne Schlüssel).
Future<String?> placeName(http.Client client, double lat, double lng) async {
  final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
    'format': 'jsonv2',
    'lat': '$lat',
    'lon': '$lng',
    'zoom': '10',
    'accept-language': 'de',
  });
  final res = await client.get(
    uri,
    headers: {'User-Agent': 'bubududu/1.0 (de.bubududu.bubududu)'},
  );
  if (res.statusCode != 200) return null;
  final address =
      (jsonDecode(res.body) as Map<String, dynamic>)['address'] as Map? ??
      const {};
  for (final key in ['city', 'town', 'village', 'municipality', 'county']) {
    if (address[key] is String) return address[key] as String;
  }
  return null;
}
