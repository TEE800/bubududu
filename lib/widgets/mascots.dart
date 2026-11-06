import 'dart:math';

import 'package:flutter/material.dart';

/// Wie Bubu und Dudu gerade drauf sind. Jeder Bereich hat seine eigene Stimmung.
enum MascotMood {
  /// Fröhlich, Standard.
  happy,

  /// Fröhlich mit Herzchen darüber, für "Wir" und Jahrestage.
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

/// Dudu (Kevin: Glatze, Vollbart, grüner Hoodie) und Bubu (Fritzi: braune
/// Frisur, Sommersprossen, schwarzer Hoodie) als Comicfiguren.
///
/// Die Bilder liegen je Stimmung unter assets/mascots/ und werden aus
/// tool/figuren/ erzeugt (siehe README dort).
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

  /// Seitenverhältnis der Bilder (Breite / Höhe).
  static const pairAspect = 760 / 550;
  static const singleAspect = 330 / 550;

  /// Bilddatei für eine Stimmung oder eine einzelne Figur.
  static String assetFor(MascotMood mood, {String? only}) => only != null
      ? 'assets/mascots/$only.png'
      : 'assets/mascots/${mood.name}.png';

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
        ? Mascots.pairAspect
        : Mascots.singleAspect;
    final image = Image.asset(
      Mascots.assetFor(widget.mood, only: widget.only),
      height: widget.height,
      width: widget.height * aspect,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      // Falls ein Bild fehlt, bleibt einfach der Platz frei.
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    return Semantics(
      label: widget.only == 'bubu'
          ? 'Bubu'
          : widget.only == 'dudu'
          ? 'Dudu'
          : 'Bubu und Dudu',
      image: true,
      child: SizedBox(
        height: widget.height,
        width: widget.height * aspect,
        child: AnimatedBuilder(
          animation: _wiggle,
          builder: (context, child) => Transform.translate(
            // Zwei sanfte Hüpfer, die ausklingen.
            offset: Offset(
              0,
              -sin(_wiggle.value * 4 * pi) *
                  (1 - _wiggle.value) *
                  widget.height *
                  0.03,
            ),
            child: child,
          ),
          child: image,
        ),
      ),
    );
  }
}
