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
            mood: moodForTime(now),
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

/// Runde Karte mit weißem Rand und den beiden Figuren.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.left,
    required this.right,
    required this.mood,
    required this.days,
  });

  final String left;
  final String right;
  final MascotMood mood;
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
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [const Color(0xFF1F3A25), const Color(0xFF14281A)]
              : const [Color(0xFFE9F6E3), Color(0xFFD3ECCB)],
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
            // Heller Kreis hinter den beiden und ein Boden-Schatten.
            Positioned(
              left: 30,
              right: 30,
              top: 26,
              bottom: -60,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: dark ? 0.05 : 0.45),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 36,
              child: Center(child: Mascots(mood: mood, height: 196)),
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
