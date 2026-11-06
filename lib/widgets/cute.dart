import 'package:flutter/material.dart';

import '../theme.dart';

/// Pastellton einer Karte: [soft] für Flächen, [edge] für den festen
/// "Bonbon"-Schatten unten, [strong] für Zahlen und Symbole.
enum CuteTone {
  mint(Cute.mint, Cute.mintDeep, darkGreen),
  pink(Cute.pink, Cute.pinkDeep, Cute.rose),
  vanilla(Cute.vanilla, Cute.vanillaDeep, Cute.honey);

  const CuteTone(this.soft, this.edge, this.strong);

  final Color soft;
  final Color edge;
  final Color strong;
}

/// Weiße, runde Karte mit festem Pastell-Schatten unten, wie ein Bonbon.
/// Im Dunkelmodus eine schlichte dunkle Fläche.
class CuteBox extends StatelessWidget {
  const CuteBox({
    super.key,
    required this.child,
    this.tone = CuteTone.mint,
    this.color,
    this.radius = 28,
    this.onTap,
  });

  final Widget child;
  final CuteTone tone;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: dark
            ? null
            : [
                BoxShadow(color: tone.edge, offset: const Offset(0, 5)),
                const BoxShadow(
                  color: Color(0x141B5E20),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: color ?? (dark ? scheme.surfaceContainerHigh : Colors.white),
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

/// Farbe der Namens-Pille: eigene Aufgaben grün, die des anderen rosa,
/// gemeinsame vanille.
CuteTone toneForAssignee(String assignee, String? me) => assignee.isEmpty
    ? CuteTone.vanilla
    : assignee == me
    ? CuteTone.mint
    : CuteTone.pink;
