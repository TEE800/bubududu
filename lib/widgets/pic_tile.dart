import 'package:flutter/material.dart';

import 'cute.dart';

/// Bildkachel, der rote Faden durch alle Bereiche: oben ein großes Bild
/// (Foto oder Symbol auf Pastellgrund) in einer Bonbon-Karte, darunter
/// Titel, ein paar Infos und auf Wunsch eine Fußzeile mit Knöpfen.
class PicTile extends StatelessWidget {
  const PicTile({
    super.key,
    required this.title,
    this.picture,
    this.emoji = '✨',
    this.tone = CuteTone.mint,
    this.subtitle,
    this.warn = false,
    this.badge,
    this.badgeIcon,
    this.badgeWarn = false,
    this.tag,
    this.corner,
    this.cornerRight,
    this.footer,
    this.onTap,
    this.onLongPress,
    this.done = false,
    this.titleLines = 2,
  });

  final String title;

  /// Eigenes Bild (Foto). Ohne Bild zeigt die Kachel [emoji] groß auf
  /// Pastellgrund in der Farbe von [tone].
  final Widget? picture;
  final String emoji;
  final CuteTone tone;
  final String? subtitle;

  /// Untertitel in Warnfarbe (fällig, überfällig, Frist).
  final bool warn;

  /// Kleines Schild oben rechts auf dem Bild, z. B. „in 3 Tagen“ oder ein Preis.
  final String? badge;
  final IconData? badgeIcon;
  final bool badgeWarn;

  /// Schild unten links auf dem Bild, z. B. eine Mengenangabe („500 g“).
  final String? tag;

  /// Knopf oben links auf dem Bild, z. B. zum Abhaken.
  final Widget? corner;

  /// Knopf oben rechts (statt [badge]), z. B. zum Löschen.
  final Widget? cornerRight;
  final Widget? footer;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Erledigt: blasser und durchgestrichen.
  final bool done;
  final int titleLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return CuteBox(
      tone: tone,
      radius: 26,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Opacity(
        opacity: done ? 0.55 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(21),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      picture ?? EmojiArt(emoji: emoji, tone: tone),
                      if (cornerRight != null)
                        Positioned(top: 2, right: 2, child: cornerRight!)
                      else if (badge != null)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: TileBadge(
                            label: badge!,
                            icon: badgeIcon,
                            warn: badgeWarn,
                          ),
                        ),
                      if (tag != null && tag!.isNotEmpty)
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: TileBadge(label: tag!),
                        ),
                      if (corner != null)
                        Positioned(top: 2, left: 2, child: corner!),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: titleLines,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: warn ? scheme.error : null,
                        ),
                      ),
                    ),
                  ?footer,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Symbol groß auf einem Pastellverlauf, wenn es kein Foto gibt.
class EmojiArt extends StatelessWidget {
  const EmojiArt({super.key, required this.emoji, this.tone = CuteTone.mint});

  final String emoji;
  final CuteTone tone;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [scheme.primaryContainer, scheme.surfaceContainerHighest]
              : [tone.soft, tone.edge],
        ),
      ),
      child: Center(
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 56),
              textScaler: TextScaler.noScaling,
            ),
          ),
        ),
      ),
    );
  }
}

/// Kleines rundes Schild auf dem Bild einer Kachel.
class TileBadge extends StatelessWidget {
  const TileBadge({
    super.key,
    required this.label,
    this.icon,
    this.warn = false,
  });

  final String label;
  final IconData? icon;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = warn ? scheme.onErrorContainer : scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      constraints: const BoxConstraints(maxWidth: 140),
      decoration: BoxDecoration(
        color: warn ? scheme.errorContainer : scheme.surface.withAlpha(235),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: fg, size: 14),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Runder Knopf auf dem Bild einer Kachel, z. B. zum Abhaken.
class TileButton extends StatelessWidget {
  const TileButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Gefüllt in Grün (z. B. schon abgehakt oder jetzt fällig).
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: active
            ? scheme.primary
            : scheme.surface.withAlpha(235),
        foregroundColor: active ? scheme.onPrimary : scheme.primary,
      ),
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
    );
  }
}

/// Kacheln in Reihen, zwei auf dem Handy, mehr auf breiten Bildschirmen.
/// Passt in eine ListView (scrollt nicht selbst).
class PicGrid extends StatelessWidget {
  const PicGrid({
    super.key,
    required this.children,
    this.tileHeight = 218,
    this.maxTileWidth = 200,
    this.padding = const EdgeInsets.fromLTRB(12, 4, 12, 8),
  });

  final List<Widget> children;
  final double tileHeight;
  final double maxTileWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // Eigene Zeilen statt GridView: kein zweites Scrollen in der Liste.
    final height =
        tileHeight + (MediaQuery.textScalerOf(context).scale(14) - 14) * 6;
    const gap = 12.0;
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = ((constraints.maxWidth + gap) / (maxTileWidth + gap))
              .ceil()
              .clamp(1, 12);
          return Column(
            children: [
              for (var start = 0; start < children.length; start += columns)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: start + columns < children.length ? gap : 0,
                  ),
                  child: SizedBox(
                    height: height,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var n = 0; n < columns; n++) ...[
                          if (n > 0) const SizedBox(width: gap),
                          Expanded(
                            child: start + n < children.length
                                ? children[start + n]
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Gleiches Raster für SliverGrid, damit alle Kacheln gleich aussehen.
/// Größere Schrift macht die Kacheln höher.
SliverGridDelegate picGridDelegate(
  BuildContext context, {
  double tileHeight = 218,
  double maxTileWidth = 200,
}) {
  final extra = (MediaQuery.textScalerOf(context).scale(14) - 14) * 6;
  return SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: maxTileWidth,
    mainAxisExtent: tileHeight + extra,
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
  );
}
