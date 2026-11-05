import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/weather.dart';
import '../util/dates.dart';
import '../widgets/mascots.dart';
import 'us.dart';
import 'weather_screen.dart';

/// Tageszeit für den Himmel oben auf der Startseite.
enum SkyPhase { morning, day, evening, night }

SkyPhase skyPhaseFor(DateTime t) => switch (t.hour) {
  < 6 || >= 21 => SkyPhase.night,
  < 10 => SkyPhase.morning,
  < 17 => SkyPhase.day,
  _ => SkyPhase.evening,
};

/// Der Kopf der Startseite: "Unsere Wiese". Himmel, Sonne oder Mond,
/// grüne Hügel und Bubu und Dudu mittendrin. Darüber Begrüßung und Wetter.
class MeadowHeader extends ConsumerWidget {
  const MeadowHeader({
    super.key,
    required this.householdId,
    required this.title,
    required this.now,
    required this.showWeather,
    required this.onSettings,
  });

  final String householdId;

  /// Begrüßung, z. B. "Guten Morgen,\nDudu!".
  final String title;
  final DateTime now;
  final bool showWeather;
  final VoidCallback onSettings;

  static const _sheetRadius = 28.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top;
    final sheet = Theme.of(context).scaffoldBackgroundColor;
    final since = ref.watch(togetherSinceProvider(householdId));
    final phase = skyPhaseFor(now);
    const white = Colors.white;

    return SizedBox(
      height: top + 320,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: MeadowPainter(phase)),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 26,
            child: Center(
              child: Mascots(mood: moodForTime(now), height: 120),
            ),
          ),
          // Oberkante des hellen Bereichs mit den Kacheln.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _sheetRadius,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: sheet,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(_sheetRadius),
                ),
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 64,
            top: top + 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${weekdayLong(now)}, ${now.day}. ${monthNames[now.month - 1]}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: white,
                    fontSize: 30,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (showWeather) ...[
                  const SizedBox(height: 10),
                  _WeatherLine(householdId: householdId),
                ],
              ],
            ),
          ),
          Positioned(
            right: 8,
            top: top + 8,
            child: IconButton(
              tooltip: 'Startseite einrichten',
              color: white,
              icon: const Icon(Icons.tune),
              onPressed: onSettings,
            ),
          ),
          if (since != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Center(
                child: _TogetherPill(days: daysBetween(since, today())),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeatherLine extends ConsumerWidget {
  const _WeatherLine({required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(weatherLocationProvider(householdId)).value;
    if (place == null) return const SizedBox.shrink();
    final w = ref
        .watch(weatherProvider((lat: place.lat, lng: place.lng)))
        .value;
    if (w == null) return const SizedBox.shrink();
    final (text, icon) = describeWeather(w.code);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '${w.temperature.round()}° · $text',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TogetherPill extends StatelessWidget {
  const _TogetherPill({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(99),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33003310),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, size: 16, color: scheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Seit ${_thousands(days)} ${days == 1 ? 'Tag' : 'Tagen'} zusammen',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _thousands(int n) {
  final s = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write('.');
    out.write(s[i]);
  }
  return out.toString();
}

/// Malt Himmel, Sonne oder Mond mit Sternen, Wolken und zwei Hügel.
class MeadowPainter extends CustomPainter {
  MeadowPainter(this.phase);

  final SkyPhase phase;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final night = phase == SkyPhase.night;

    final sky = switch (phase) {
      SkyPhase.morning => const [
        Color(0xFF2F7A52),
        Color(0xFF7DB886),
        Color(0xFFF1D9A6),
      ],
      SkyPhase.day => const [
        Color(0xFF2E7D4F),
        Color(0xFF5AA36F),
        Color(0xFF9FD09A),
      ],
      SkyPhase.evening => const [
        Color(0xFF1E5536),
        Color(0xFF7E9858),
        Color(0xFFEFAF73),
      ],
      SkyPhase.night => const [
        Color(0xFF0A2013),
        Color(0xFF14361E),
        Color(0xFF285C35),
      ],
    };
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: sky,
        ).createShader(rect),
    );

    if (night) {
      final star = Paint()..color = const Color(0xCCFFFFFF);
      const stars = [
        (0.08, 0.40, 1.4),
        (0.22, 0.55, 1.0),
        (0.35, 0.46, 1.6),
        (0.52, 0.36, 1.1),
        (0.62, 0.52, 1.5),
        (0.70, 0.30, 1.0),
        (0.93, 0.48, 1.3),
        (0.46, 0.60, 0.9),
        (0.15, 0.66, 1.2),
        (0.88, 0.64, 1.0),
      ];
      for (final (x, y, r) in stars) {
        canvas.drawCircle(Offset(w * x, h * y), r, star);
      }
      final c = Offset(w * 0.8, h * 0.4);
      canvas.drawCircle(c, 40, Paint()..color = const Color(0x14FFF4CC));
      final moon = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: c, radius: 24)),
        Path()
          ..addOval(
            Rect.fromCircle(center: c + const Offset(10, -8), radius: 21),
          ),
      );
      canvas.drawPath(moon, Paint()..color = const Color(0xFFFFF1C2));
    } else {
      final low = phase != SkyPhase.day;
      final c = Offset(w * 0.8, h * (low ? 0.56 : 0.44));
      final sun = switch (phase) {
        SkyPhase.evening => const Color(0xFFFFC27A),
        SkyPhase.morning => const Color(0xFFFFD98A),
        _ => const Color(0xFFFFE08A),
      };
      canvas.drawCircle(c, 58, Paint()..color = sun.withValues(alpha: 0.12));
      canvas.drawCircle(c, 44, Paint()..color = sun.withValues(alpha: 0.25));
      canvas.drawCircle(c, 30, Paint()..color = sun);
    }

    final cloud = Paint()
      ..color = Colors.white.withValues(alpha: night ? 0.10 : 0.85);
    _cloud(canvas, Offset(w * 0.10, h * 0.64), 1.0, cloud);
    _cloud(canvas, Offset(w * 0.60, h * 0.60), 0.7, cloud);

    final backHill = night ? const Color(0xFF1E4A27) : const Color(0xFF3F8F4F);
    final frontHill = night ? const Color(0xFF123519) : const Color(0xFF1B5E20);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.18, h * 1.0),
        width: w * 1.35,
        height: h * 0.62,
      ),
      Paint()..color = backHill,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.88, h * 1.04),
        width: w * 1.45,
        height: h * 0.6,
      ),
      Paint()..color = frontHill,
    );
  }

  void _cloud(Canvas canvas, Offset at, double s, Paint p) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(at.dx, at.dy, 92 * s, 26 * s),
        Radius.circular(13 * s),
      ),
      p,
    );
    canvas.drawCircle(at + Offset(30 * s, 4 * s), 17 * s, p);
    canvas.drawCircle(at + Offset(56 * s, 2 * s), 13 * s, p);
  }

  @override
  bool shouldRepaint(MeadowPainter old) => old.phase != phase;
}
