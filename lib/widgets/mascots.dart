import 'dart:math';

import 'package:flutter/material.dart';

/// Wie Bubu und Dudu gerade drauf sind. Jeder Bereich hat seine eigene Stimmung.
enum MascotMood {
  /// Fröhlich, Standard.
  happy,

  /// Herzchen-Augen, für "Wir" und Jahrestage.
  love,

  /// Verschlafen, morgens früh und spät abends.
  sleepy,

  /// Hungrig mit Sabber, für Rezepte und Essensplan.
  hungry,

  /// Mit Einkaufstüte.
  shopping,

  /// Mit Putz-Glitzer, für den Haushalt.
  cleaning,

  /// Mit Münze, für Finanzen und Verträge.
  money,

  /// Mit Kalenderblatt.
  calendar,

  /// Mit Koffer, für Reisen.
  travel,

  /// Mit Pflaster und Gießkanne, für Tiere & Pflanzen.
  care,

  /// Nachdenklich, für Notizen und Vorräte.
  thinking,

  /// Traurig, z. B. wenn etwas schiefgeht.
  sad,
}

/// Stimmung für die Startseite: morgens früh und nachts verschlafen,
/// mittags und abends hungrig, sonst fröhlich.
MascotMood moodForTime(DateTime t) => switch (t.hour) {
  < 7 || >= 22 => MascotMood.sleepy,
  12 || 18 => MascotMood.hungry,
  _ => MascotMood.happy,
};

/// Dudu (brauner Bär) und Bubu (weißer Panda), selbst gezeichnet.
///
/// Wippt beim Erscheinen kurz und bleibt dann ruhig stehen, damit Tests und
/// Akku nicht unter einer Endlos-Animation leiden.
class Mascots extends StatefulWidget {
  const Mascots({
    super.key,
    this.mood = MascotMood.happy,
    this.height = 120,
    this.only,
  });

  final MascotMood mood;
  final double height;

  /// Nur eine Figur zeigen: 'dudu' oder 'bubu'.
  final String? only;

  @override
  State<Mascots> createState() => _MascotsState();
}

class _MascotsState extends State<Mascots> with SingleTickerProviderStateMixin {
  late final _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  @override
  void didUpdateWidget(Mascots old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) _wiggle.forward(from: 0);
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspect = widget.only == null
        ? MascotPainter.width / MascotPainter.height
        : 0.62;
    return Semantics(
      label: 'Bubu und Dudu',
      child: SizedBox(
        height: widget.height,
        width: widget.height * aspect,
        child: AnimatedBuilder(
          animation: _wiggle,
          builder: (context, _) => CustomPaint(
            painter: MascotPainter(
              mood: widget.mood,
              // Zwei sanfte Hüpfer, die ausklingen.
              bounce: sin(_wiggle.value * 4 * pi) * (1 - _wiggle.value),
              only: widget.only,
            ),
          ),
        ),
      ),
    );
  }
}

/// Zeichnet die beiden im Raster 200 × 130 und skaliert auf die Fläche.
class MascotPainter extends CustomPainter {
  MascotPainter({required this.mood, this.bounce = 0, this.only});

  static const width = 200.0;
  static const height = 130.0;

  final MascotMood mood;
  final double bounce;
  final String? only;

  static const outline = Color(0xFF3B2418);
  static const duduFur = Color(0xFFD29A6A);
  static const duduEar = Color(0xFF8B5A3C);
  static const bubuFur = Color(0xFFFFFFFF);
  static const bubuEar = Color(0xFF2E2A28);
  static const green = Color(0xFF1B5E20);
  static const lightGreen = Color(0xFF66BB6A);

  @override
  void paint(Canvas canvas, Size size) {
    if (only != null) {
      // Eine Figur, mittig in einer schmaleren Fläche.
      const w = 124.0;
      final scale = min(size.width / w, size.height / height);
      canvas
        ..save()
        ..translate((size.width - w * scale) / 2, size.height - height * scale)
        ..scale(scale);
      final dudu = only == 'dudu';
      _character(canvas, 62, dudu: dudu, phase: 1);
      canvas.restore();
      return;
    }
    final scale = min(size.width / width, size.height / height);
    canvas
      ..save()
      ..translate(
        (size.width - width * scale) / 2,
        size.height - height * scale,
      )
      ..scale(scale);

    _behind(canvas);
    _character(canvas, 62, dudu: true, phase: 1);
    _character(canvas, 138, dudu: false, phase: -1);
    _inFront(canvas);
    canvas.restore();
  }

  Paint _fill(Color c) => Paint()..color = c;

  Paint get _stroke => Paint()
    ..color = outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _shape(Canvas canvas, Path path, Color fill) {
    canvas
      ..drawPath(path, _fill(fill))
      ..drawPath(path, _stroke);
  }

  void _character(
    Canvas canvas,
    double cx, {
    required bool dudu,
    required double phase,
  }) {
    final fur = dudu ? duduFur : bubuFur;
    final ear = dudu ? duduEar : bubuEar;
    final dy = -bounce * 4 * phase;
    canvas
      ..save()
      ..translate(0, dy);

    // Füße und Körper
    for (final s in [-1, 1]) {
      _shape(
        canvas,
        Path()..addOval(
          Rect.fromCenter(
            center: Offset(cx + s * 13, 122),
            width: 18,
            height: 10,
          ),
        ),
        dudu ? fur : bubuEar,
      );
    }
    _shape(
      canvas,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, 100), width: 52, height: 46),
          const Radius.circular(22),
        ),
      ),
      fur,
    );

    // Ohren
    for (final s in [-1, 1]) {
      final c = Offset(cx + s * 27, 23);
      _shape(
        canvas,
        Path()..addOval(Rect.fromCircle(center: c, radius: 11)),
        ear,
      );
      if (dudu) {
        canvas.drawCircle(c, 5.5, _fill(const Color(0xFF6B4029)));
      }
    }

    // Kopf
    _shape(
      canvas,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, 54), width: 80, height: 66),
          const Radius.circular(32),
        ),
      ),
      fur,
    );

    // Bubu trägt ein dunkelgrünes Halstuch, Dudu nicht.
    if (!dudu) {
      final scarf = Path()
        ..moveTo(cx - 22, 84)
        ..quadraticBezierTo(cx, 92, cx + 22, 84)
        ..lineTo(cx + 18, 90)
        ..quadraticBezierTo(cx, 97, cx - 18, 90)
        ..close();
      _shape(canvas, scarf, green);
    }

    // Bäckchen
    final blush = _fill(
      (dudu ? const Color(0xFFFFB74D) : const Color(0xFFF8A5B5)).withValues(
        alpha: 0.85,
      ),
    );
    for (final s in [-1, 1]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + s * 25, 63), width: 13, height: 9),
        blush,
      );
    }

    _face(canvas, cx, dudu: dudu);
    _arms(canvas, cx, dudu: dudu, fur: fur);
    canvas.restore();
  }

  void _face(Canvas canvas, double cx, {required bool dudu}) {
    final ink = _fill(outline);
    final line = _stroke..strokeWidth = 2.4;
    final eyes = [Offset(cx - 14, 55), Offset(cx + 14, 55)];

    switch (mood) {
      case MascotMood.love:
        for (final e in eyes) {
          _heart(canvas, e, 9, const Color(0xFFE53950));
        }
      case MascotMood.sleepy:
        for (final e in eyes) {
          canvas.drawArc(
            Rect.fromCenter(center: e, width: 10, height: 7),
            0,
            pi,
            false,
            line,
          );
        }
      case MascotMood.sad:
        for (final e in eyes) {
          canvas.drawCircle(e, 3.6, ink);
        }
        // Hochgezogene Augenbrauen
        canvas
          ..drawLine(Offset(cx - 19, 45), Offset(cx - 9, 42), line)
          ..drawLine(Offset(cx + 19, 45), Offset(cx + 9, 42), line);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx - 15, 63), width: 4, height: 7),
          _fill(const Color(0xFF64B5F6)),
        );
      case MascotMood.happy || MascotMood.shopping || MascotMood.travel:
        // Fröhlich zugekniffene Augen ^^
        for (final e in eyes) {
          canvas.drawArc(
            Rect.fromCenter(center: e.translate(0, 2), width: 10, height: 8),
            pi,
            pi,
            false,
            line,
          );
        }
      default:
        for (final e in eyes) {
          canvas
            ..drawCircle(e, 3.8, ink)
            ..drawCircle(e.translate(1.2, -1.2), 1.1, _fill(Colors.white));
        }
    }

    // Mund: kleines ω, beim Hunger offen mit Sabber.
    if (mood == MascotMood.hungry) {
      final mouth = Path()
        ..addOval(
          Rect.fromCenter(center: Offset(cx, 66), width: 10, height: 8),
        );
      _shape(canvas, mouth, const Color(0xFFE57373));
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 6, 74), width: 4, height: 7),
        _fill(const Color(0xFF90CAF9)),
      );
    } else if (mood == MascotMood.sad) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, 68), width: 9, height: 6),
        pi,
        pi,
        false,
        line,
      );
    } else {
      for (final s in [-1, 1]) {
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx + s * 3, 63), width: 6, height: 6),
          0,
          pi,
          false,
          line,
        );
      }
    }

    if (mood == MascotMood.care && !dudu) {
      // Pflaster auf Bubus Stirn
      canvas
        ..save()
        ..translate(cx + 16, 37)
        ..rotate(-0.5);
      final plaster = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 20, height: 8),
            const Radius.circular(4),
          ),
        );
      _shape(canvas, plaster, const Color(0xFFF5D7B5));
      canvas
        ..drawCircle(const Offset(-2, 0), 0.9, ink)
        ..drawCircle(const Offset(2, 0), 0.9, ink)
        ..restore();
    }
  }

  void _arms(
    Canvas canvas,
    double cx, {
    required bool dudu,
    required Color fur,
  }) {
    // Die inneren Arme halten Händchen in der Mitte.
    final inner = dudu ? 1 : -1;
    final hand = Offset(cx + inner * 27, 101);
    _shape(
      canvas,
      Path()..addOval(Rect.fromCenter(center: hand, width: 14, height: 12)),
      dudu ? fur : bubuEar,
    );
    // Äußerer Arm: winkt bei Freude, sonst hängt er.
    final wave = mood == MascotMood.happy || mood == MascotMood.love;
    final outer = Offset(cx - inner * 27, wave ? 84 : 101);
    _shape(
      canvas,
      Path()..addOval(Rect.fromCenter(center: outer, width: 14, height: 12)),
      dudu ? fur : bubuEar,
    );
  }

  /// Was hinter den Figuren steht.
  void _behind(Canvas canvas) {
    switch (mood) {
      case MascotMood.travel:
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(2, 84, 30, 38),
          const Radius.circular(5),
        );
        _shape(canvas, Path()..addRRect(r), const Color(0xFF8D6E63));
        canvas.drawLine(const Offset(2, 100), const Offset(32, 100), _stroke);
        _shape(
          canvas,
          Path()..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(10, 77, 14, 8),
              const Radius.circular(3),
            ),
          ),
          Colors.transparent,
        );
      default:
        break;
    }
  }

  /// Was vor den Figuren liegt oder über ihnen schwebt.
  void _inFront(Canvas canvas) {
    switch (mood) {
      case MascotMood.love:
        _heart(
          canvas,
          Offset(100, 22 - bounce * 4),
          16,
          const Color(0xFFE53950),
        );
        _heart(canvas, const Offset(118, 8), 9, const Color(0xFFF48FB1));
      case MascotMood.sleepy:
        final style = TextStyle(
          color: outline.withValues(alpha: 0.8),
          fontWeight: FontWeight.bold,
        );
        _text(canvas, 'z', Offset(178, 18), style.copyWith(fontSize: 12));
        _text(canvas, 'Z', Offset(188, 4), style.copyWith(fontSize: 16));
      case MascotMood.hungry:
        // Gabel neben Dudu
        final fork = _stroke..strokeWidth = 3;
        canvas.drawLine(const Offset(12, 120), const Offset(12, 80), fork);
        for (final x in [7.0, 12.0, 17.0]) {
          canvas.drawLine(Offset(x, 80), Offset(x, 68), fork..strokeWidth = 2);
        }
        canvas.drawLine(const Offset(7, 80), const Offset(17, 80), fork);
      case MascotMood.shopping:
        // Grüne Einkaufstüte in Dudus äußerer Hand
        final bag = Path()
          ..moveTo(2, 96)
          ..lineTo(30, 96)
          ..lineTo(27, 124)
          ..lineTo(5, 124)
          ..close();
        _shape(canvas, bag, lightGreen);
        canvas.drawArc(
          Rect.fromCenter(center: const Offset(16, 96), width: 14, height: 14),
          pi,
          pi,
          false,
          _stroke,
        );
        // Ein Lauch schaut raus
        canvas.drawLine(
          const Offset(22, 95),
          const Offset(28, 78),
          _stroke
            ..color = green
            ..strokeWidth = 4,
        );
      case MascotMood.cleaning:
        for (final (o, r) in [
          (const Offset(14, 30), 7.0),
          (const Offset(186, 46), 9.0),
          (const Offset(100, 12), 6.0),
        ]) {
          _sparkle(canvas, o, r);
        }
      case MascotMood.money:
        final coin = Path()
          ..addOval(
            Rect.fromCircle(center: Offset(100, 16 - bounce * 4), radius: 12),
          );
        _shape(canvas, coin, const Color(0xFFFFCA28));
        _text(
          canvas,
          '€',
          Offset(100, 16 - bounce * 4),
          const TextStyle(
            color: outline,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        );
      case MascotMood.calendar:
        final page = RRect.fromRectAndRadius(
          Rect.fromLTWH(170, 82, 28, 32),
          const Radius.circular(4),
        );
        _shape(canvas, Path()..addRRect(page), Colors.white);
        canvas.drawRect(
          Rect.fromLTWH(171.5, 83.5, 25, 8),
          _fill(const Color(0xFFE53950)),
        );
        _text(
          canvas,
          '${DateTime.now().day}',
          const Offset(184, 103),
          const TextStyle(
            color: outline,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        );
      case MascotMood.care:
        // Kleines Pflänzchen bei Dudu
        final pot = Path()
          ..moveTo(4, 104)
          ..lineTo(26, 104)
          ..lineTo(23, 124)
          ..lineTo(7, 124)
          ..close();
        _shape(canvas, pot, const Color(0xFFBF7B54));
        for (final s in [-1, 1]) {
          final leaf = Path()
            ..addOval(
              Rect.fromCenter(
                center: Offset(15 + s * 6, 94),
                width: 12,
                height: 8,
              ),
            );
          _shape(canvas, leaf, lightGreen);
        }
      case MascotMood.thinking:
        _text(
          canvas,
          '?',
          Offset(186, 20 - bounce * 4),
          const TextStyle(
            color: green,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        );
      default:
        break;
    }
  }

  void _heart(Canvas canvas, Offset c, double s, Color color) {
    final p = Path()
      ..moveTo(c.dx, c.dy + s * 0.45)
      ..cubicTo(
        c.dx - s * 0.9,
        c.dy - s * 0.1,
        c.dx - s * 0.45,
        c.dy - s * 0.75,
        c.dx,
        c.dy - s * 0.3,
      )
      ..cubicTo(
        c.dx + s * 0.45,
        c.dy - s * 0.75,
        c.dx + s * 0.9,
        c.dy - s * 0.1,
        c.dx,
        c.dy + s * 0.45,
      )
      ..close();
    canvas.drawPath(p, _fill(color));
  }

  void _sparkle(Canvas canvas, Offset c, double r) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(p, _fill(const Color(0xFFFFD54F)));
  }

  void _text(Canvas canvas, String text, Offset center, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(MascotPainter old) =>
      old.mood != mood || old.bounce != bounce || old.only != only;
}
