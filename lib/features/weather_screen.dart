import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/store.dart';
import '../services/weather.dart';
import '../util/dates.dart';
import '../widgets/common.dart';
import 'location.dart';

/// Haushaltsfeld weatherAuto: Wetter für den Ort, an dem das Handy gerade ist.
final weatherAutoProvider = Provider.family<bool, String>(
  (ref, householdId) =>
      ref.watch(householdDataProvider(householdId)).value?['weatherAuto'] ==
      true,
);

/// Aktueller Ort dieses Handys, mit Ortsnamen.
final devicePlaceProvider = FutureProvider<Place>((ref) async {
  final error = await ensureLocationPermission();
  if (error != null) throw Exception(error);
  final position =
      await Geolocator.getLastKnownPosition() ??
      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
  final name = await placeName(
    ref.watch(httpClientProvider),
    position.latitude,
    position.longitude,
  ).catchError((_) => null);
  return Place(
    name: name ?? 'Hier',
    lat: position.latitude,
    lng: position.longitude,
  );
});

/// Ort fürs Wetter: automatisch erkannt oder fest eingestellt.
final weatherLocationProvider = Provider.family<AsyncValue<Place?>, String>((
  ref,
  householdId,
) {
  if (ref.watch(weatherAutoProvider(householdId))) {
    return ref.watch(devicePlaceProvider);
  }
  return AsyncData(
    Place.fromMap(
      ref.watch(householdDataProvider(householdId)).value?['weatherPlace'],
    ),
  );
});

String _time(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _num(double v, [int digits = 0]) =>
    v.toStringAsFixed(digits).replaceAll('.', ',');

class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key, required this.place, this.onSettings});

  final Place place;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(
      weatherProvider((lat: place.lat, lng: place.lng)),
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Wetter in ${place.name.split(',').first}'),
        actions: [
          if (onSettings != null)
            IconButton(
              tooltip: 'Ort ändern',
              icon: const Icon(Icons.edit_location_alt_outlined),
              onPressed: onSettings,
            ),
        ],
      ),
      body: weather.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: TextButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Wetter gerade nicht erreichbar. Nochmal?'),
            onPressed: () => ref.invalidate(weatherProvider),
          ),
        ),
        data: (w) {
          final (text, icon) = describeWeather(w.code);
          final today = w.days.isEmpty ? null : w.days.first;
          final details = <(IconData, String, String)>[
            if (w.feelsLike != null)
              (Icons.thermostat, 'Gefühlt', '${w.feelsLike!.round()}°'),
            if (w.humidity != null)
              (Icons.water_drop_outlined, 'Luftfeuchte', '${w.humidity} %'),
            if (w.wind != null)
              (
                Icons.air,
                'Wind',
                '${w.wind!.round()} km/h'
                    '${w.windDirection != null ? ' ${compass(w.windDirection!)}' : ''}',
              ),
            if (w.gusts != null)
              (Icons.storm_outlined, 'Böen', '${w.gusts!.round()} km/h'),
            if (today != null)
              (Icons.umbrella_outlined, 'Regen heute', '${today.rainChance} %'),
            if (today?.rainSum != null)
              (Icons.grain, 'Menge heute', '${_num(today!.rainSum!, 1)} mm'),
            if (w.uv != null || today?.uvMax != null)
              (
                Icons.wb_sunny_outlined,
                'UV-Index',
                _num(w.uv ?? today!.uvMax!),
              ),
            if (w.cloudCover != null)
              (Icons.cloud_outlined, 'Bewölkung', '${w.cloudCover} %'),
            if (w.pressure != null)
              (Icons.speed, 'Luftdruck', '${w.pressure!.round()} hPa'),
            if (today?.sunrise != null)
              (Icons.wb_twilight, 'Sonnenaufgang', _time(today!.sunrise!)),
            if (today?.sunset != null)
              (
                Icons.nights_stay_outlined,
                'Sonnenuntergang',
                _time(today!.sunset!),
              ),
          ];

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(weatherProvider),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Icon(icon, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${w.temperature.round()}°',
                              style: theme.textTheme.displayMedium,
                            ),
                            Text(text, style: theme.textTheme.titleMedium),
                            if (today != null)
                              Text(
                                'Heute ${today.min.round()}° bis ${today.max.round()}°',
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    children: [
                      for (final (i, label, value) in details)
                        SizedBox(
                          width: (MediaQuery.sizeOf(context).width - 24) / 2,
                          child: ListTile(
                            dense: true,
                            leading: Icon(i),
                            title: Text(label),
                            subtitle: Text(
                              value,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (w.hours.isNotEmpty) ...[
                  const SectionHeader('Nächste Stunden'),
                  SizedBox(
                    height: 116,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final h in w.hours)
                          SizedBox(
                            width: 64,
                            child: Column(
                              children: [
                                Text('${h.time.hour} Uhr'),
                                const SizedBox(height: 4),
                                Icon(describeWeather(h.code).$2),
                                const SizedBox(height: 4),
                                Text('${h.temperature.round()}°'),
                                Text(
                                  '${h.rainChance} %',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SectionHeader('Die nächsten Tage'),
                for (final d in w.days)
                  ListTile(
                    leading: Icon(describeWeather(d.code).$2),
                    title: Text(relativeDay(d.date)),
                    subtitle: Text(
                      [
                        describeWeather(d.code).$1,
                        '${d.rainChance} % Regen',
                        if (d.rainSum != null && d.rainSum! > 0)
                          '${_num(d.rainSum!, 1)} mm',
                        if (d.windMax != null)
                          'Wind bis ${d.windMax!.round()} km/h',
                      ].join(' · '),
                    ),
                    trailing: Text(
                      '${d.min.round()}° / ${d.max.round()}°',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Daten: Open-Meteo',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
