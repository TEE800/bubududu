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
  });

  final DateTime date;
  final double min;
  final double max;
  final int code;
  final int rainChance;
}

class Weather {
  const Weather({
    required this.temperature,
    required this.code,
    required this.days,
  });

  final double temperature;
  final int code;
  final List<DayForecast> days;
}

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

Weather parseWeather(Map<String, dynamic> json) {
  final current = json['current'] as Map<String, dynamic>;
  final daily = json['daily'] as Map<String, dynamic>;
  final dates = (daily['time'] as List).cast<String>();
  return Weather(
    temperature: (current['temperature_2m'] as num).toDouble(),
    code: (current['weather_code'] as num).toInt(),
    days: [
      for (var i = 0; i < dates.length; i++)
        DayForecast(
          date: DateTime.parse(dates[i]),
          min: (daily['temperature_2m_min'][i] as num).toDouble(),
          max: (daily['temperature_2m_max'][i] as num).toDouble(),
          code: (daily['weather_code'][i] as num).toInt(),
          rainChance: ((daily['precipitation_probability_max'][i] as num?) ?? 0)
              .toInt(),
        ),
    ],
  );
}

final weatherProvider =
    FutureProvider.family<Weather, ({double lat, double lng})>((ref, p) async {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '${p.lat}',
        'longitude': '${p.lng}',
        'current': 'temperature_2m,weather_code',
        'daily': 'temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max',
        'timezone': 'auto',
        'forecast_days': '3',
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
