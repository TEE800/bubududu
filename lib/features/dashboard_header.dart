import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/weather.dart';
import '../theme.dart';
import '../util/dates.dart';
import '../widgets/mascots.dart';
import 'us.dart';
import 'weather_screen.dart';

/// Kleine Liebesbotschaften für die Sprechblasen, jeden Tag ein anderes Paar.
/// Links spricht Dudu, rechts Bubu.
const loveLines = [
  ('Hab dich lieb! 🥰', 'Ich dich mehr 💕'),
  ('Du bist toll! ✨', 'Du noch toller 💚'),
  ('Kuscheln? 🧸', 'Immer! 💞'),
  ('Mein Lieblingsmensch 💚', 'Für immer 🥰'),
  ('Schön, dass es dich gibt 🌸', 'Ohne dich wär nix los 💕'),
  ('Heute wird schön ☀️', 'Mit dir sowieso 💞'),
  ('Kaffee für dich? ☕', 'Und ein Küsschen 😘'),
];

(String, String) loveLineFor(DateTime day) =>
    loveLines[DateTime(
          day.year,
          day.month,
          day.day,
        ).difference(DateTime(2020)).inDays %
        loveLines.length];

/// Hintergrund der Startseite: Minze oben, Rosa unten, mit kleinen Pünktchen.
class CuteBackdrop extends StatelessWidget {
  const CuteBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) return child;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Cute.mint, Color(0xFFF7F6EE), Color(0xFFFDF0F3)],
        ),
      ),
      child: CustomPaint(painter: _DotsPainter(), child: child),
    );
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.85);
    const step = 22.0;
    for (var y = step / 2; y < size.height; y += step) {
      for (var x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.6, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => false;
}

/// Der Kopf der Startseite im Cute-Look: Begrüßung mit Glitzer, darunter
/// eine runde Bildkarte mit Bubu und Dudu, Herzchen, Sprechblasen und
/// "Seit … Tagen zusammen".
class CuteHeader extends ConsumerWidget {
  const CuteHeader({
    super.key,
    required this.householdId,
    required this.title,
    required this.now,
    required this.showWeather,
    required this.onSettings,
  });

  final String householdId;

  /// Begrüßung, z. B. "Guten Morgen, Dudu!".
  final String title;
  final DateTime now;
  final bool showWeather;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final since = ref.watch(togetherSinceProvider(householdId));
    final (left, right) = loveLineFor(now);
    final headline = dark ? scheme.primary : darkGreen;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, top + 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 48, child: _Sparkle('✨', top: 14)),
              Expanded(
                child: Column(
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: headline,
                        fontSize: 28,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _DateWeatherLine(
                      householdId: householdId,
                      now: now,
                      showWeather: showWeather,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 48,
                child: IconButton(
                  tooltip: 'Startseite einrichten',
                  color: headline,
                  icon: const Icon(Icons.tune),
                  onPressed: onSettings,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _HeroCard(
            left: left,
            right: right,
            now: now,
            days: since == null ? null : daysBetween(since, today()),
          ),
        ],
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle(this.emoji, {this.top = 0});

  final String emoji;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top),
    child: Text(emoji, style: const TextStyle(fontSize: 22)),
  );
}

class _DateWeatherLine extends ConsumerWidget {
  const _DateWeatherLine({
    required this.householdId,
    required this.now,
    required this.showWeather,
  });

  final String householdId;
  final DateTime now;
  final bool showWeather;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date =
        '${weekdayLong(now)}, ${now.day}. ${monthNames[now.month - 1]}';
    String? weather;
    if (showWeather) {
      final place = ref.watch(weatherLocationProvider(householdId)).value;
      final w = place == null
          ? null
          : ref.watch(weatherProvider((lat: place.lat, lng: place.lng))).value;
      if (w != null) {
        weather = '${w.temperature.round()}° ${describeWeather(w.code).$1}';
      }
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      weather == null ? date : '$date · $weather',
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: dark ? null : const Color(0xFF5D8A63),
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Runde Karte mit weißem Rand: die Wiese mit den beiden Figuren.
/// Auf der Startseite sind die zwei immer fröhlich, nie hungrig oder müde.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.left,
    required this.right,
    required this.now,
    required this.days,
  });

  final String left;
  final String right;
  final DateTime now;
  final int? days;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 270,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: dark ? scheme.surfaceContainerHighest : Colors.white,
          width: 4,
        ),
        boxShadow: dark
            ? null
            : const [
                BoxShadow(color: Cute.mintDeep, offset: Offset(0, 7)),
                BoxShadow(
                  color: Color(0x221B5E20),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: Stack(
          children: [
            // Unsere Wiese: Himmel je nach Tageszeit, Sonne oder Mond, Hügel.
            Positioned.fill(
              child: CustomPaint(painter: MeadowPainter(skyPhaseFor(now))),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 36,
              child: Center(
                child: Mascots(mood: MascotMood.happy, height: 196),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              top: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Heart(size: 16, opacity: 0.7, dy: 14),
                  SizedBox(width: 8),
                  _Heart(size: 26, opacity: 1, dy: 0),
                ],
              ),
            ),
            Positioned(
              left: 10,
              top: 142,
              child: _Bubble(text: left, tailLeft: true),
            ),
            Positioned(
              right: 10,
              top: 14,
              child: _Bubble(text: right, tailLeft: true, pink: true),
            ),
            if (days != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Center(child: _TogetherPill(days: days!)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Heart extends StatelessWidget {
  const _Heart({required this.size, required this.opacity, required this.dy});

  final double size;
  final double opacity;
  final double dy;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: dy),
    child: Icon(
      Icons.favorite,
      size: size,
      color: const Color(0xFFE8505B).withValues(alpha: opacity),
    ),
  );
}

/// Sprechblase mit kleinem Zipfel unten.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, this.tailLeft = true, this.pink = false});

  final String text;
  final bool tailLeft;
  final bool pink;

  @override
  Widget build(BuildContext context) {
    final color = pink ? Cute.pink : Colors.white;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 170),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: tailLeft ? 22 : null,
            right: tailLeft ? null : 22,
            bottom: -6,
            child: Transform.rotate(
              angle: 0.785,
              child: Container(width: 14, height: 14, color: color),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Cute.pinkDeep, offset: Offset(0, 3)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                text,
                maxLines: 2,
                style: const TextStyle(
                  color: Cute.leaf,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TogetherPill extends StatelessWidget {
  const _TogetherPill({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: darkGreen,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Text(
          '💞 Seit ${_thousands(days)} ${days == 1 ? 'Tag' : 'Tagen'} zusammen',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
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

/// Tageszeit für den Himmel auf der Wiese.
enum SkyPhase { morning, day, evening, night }

SkyPhase skyPhaseFor(DateTime t) => switch (t.hour) {
  < 6 || >= 21 => SkyPhase.night,
  < 10 => SkyPhase.morning,
  < 17 => SkyPhase.day,
  _ => SkyPhase.evening,
};

/// Malt Himmel, Sonne oder Mond mit Sternen, Wolken und zwei grüne Hügel.
/// Sonne und Mond stehen oben links, rechts oben ist Platz für die
/// Sprechblase.
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
        Color(0xFF8CCB9B),
        Color(0xFFCFE8C4),
        Color(0xFFFBE3B8),
      ],
      SkyPhase.day => const [
        Color(0xFF9ED6B0),
        Color(0xFFCDEBCF),
        Color(0xFFE9F6E3),
      ],
      SkyPhase.evening => const [
        Color(0xFF7FB58F),
        Color(0xFFF2C9A0),
        Color(0xFFF6B7A8),
      ],
      SkyPhase.night => const [
        Color(0xFF0E2A18),
        Color(0xFF17391F),
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

    final c = Offset(w * 0.14, h * 0.2);
    if (night) {
      final star = Paint()..color = const Color(0xCCFFFFFF);
      const stars = [
        (0.30, 0.10, 1.4),
        (0.42, 0.24, 1.0),
        (0.58, 0.08, 1.6),
        (0.66, 0.30, 1.1),
        (0.08, 0.46, 1.2),
        (0.90, 0.40, 1.3),
        (0.24, 0.36, 0.9),
        (0.80, 0.56, 1.0),
      ];
      for (final (x, y, r) in stars) {
        canvas.drawCircle(Offset(w * x, h * y), r, star);
      }
      canvas.drawCircle(c, 30, Paint()..color = const Color(0x14FFF4CC));
      final moon = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: c, radius: 18)),
        Path()..addOval(
          Rect.fromCircle(center: c + const Offset(8, -6), radius: 16),
        ),
      );
      canvas.drawPath(moon, Paint()..color = const Color(0xFFFFF1C2));
    } else {
      final sun = switch (phase) {
        SkyPhase.evening => const Color(0xFFFFB877),
        SkyPhase.morning => const Color(0xFFFFD98A),
        _ => const Color(0xFFFFE08A),
      };
      canvas.drawCircle(c, 40, Paint()..color = sun.withValues(alpha: 0.18));
      canvas.drawCircle(c, 30, Paint()..color = sun.withValues(alpha: 0.35));
      canvas.drawCircle(c, 21, Paint()..color = sun);
    }

    final cloud = Paint()
      ..color = Colors.white.withValues(alpha: night ? 0.08 : 0.9);
    _cloud(canvas, Offset(w * 0.02, h * 0.44), 0.7, cloud);
    _cloud(canvas, Offset(w * 0.74, h * 0.5), 0.6, cloud);

    final backHill = night ? const Color(0xFF1E4A27) : const Color(0xFF8BC98A);
    final frontHill = night ? const Color(0xFF123519) : const Color(0xFF5FAE6A);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.15, h * 1.02),
        width: w * 1.4,
        height: h * 0.5,
      ),
      Paint()..color = backHill,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.9, h * 1.06),
        width: w * 1.5,
        height: h * 0.5,
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
