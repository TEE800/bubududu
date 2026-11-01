import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/wikipedia.dart';
import '../util/aktionstage.dart';
import '../util/dates.dart';

/// Zeigt die Infos zu einem Aktionstag in einem Blatt von unten: kurze
/// Erklärung, eine Idee für euch zwei und den Hintergrund aus Wikipedia.
Future<void> showAktionstag(BuildContext context, Aktionstag t, DateTime day) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) =>
          AktionstagDetails(tag: t, day: day, controller: controller),
    ),
  );
}

class AktionstagDetails extends ConsumerWidget {
  const AktionstagDetails({
    super.key,
    required this.tag,
    required this.day,
    this.controller,
  });

  final Aktionstag tag;
  final DateTime day;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final idee = tag.idee;
    final wiki = ref.watch(wikiArticleProvider((tag.wikiTitel, tag.name)));

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      children: [
        Text(tag.name, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Chip(
              avatar: Icon(
                tag.witzig
                    ? Icons.sentiment_very_satisfied_outlined
                    : Icons.public,
                size: 18,
              ),
              label: Text(tag.witzig ? 'Zum Schmunzeln' : 'Zum Nachdenken'),
            ),
            Chip(
              avatar: const Icon(Icons.event, size: 18),
              label: Text(formatDate(day)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(tag.info, style: theme.textTheme.bodyLarge),
        if (idee != null) ...[
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            color: colors.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: colors.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Idee für euch zwei',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colors.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          idee,
                          style: TextStyle(color: colors.onSecondaryContainer),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(Icons.menu_book_outlined, size: 20, color: colors.primary),
            const SizedBox(width: 8),
            Text('Hintergrund', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        wiki.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          ),
          error: (_, _) => const Text(
            'Der Hintergrund aus Wikipedia ließ sich gerade nicht laden. '
            'Bist du online?',
          ),
          data: (article) => article == null
              ? const Text('Zu diesem Tag gibt es keinen Wikipedia-Artikel.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (article.title != tag.name)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          article.title,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    Text(article.extract),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Bei Wikipedia weiterlesen'),
                        onPressed: () => _open(context, article.url),
                      ),
                    ),
                    Text(
                      'Text aus der Wikipedia, Lizenz CC BY-SA 4.0',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wikipedia ließ sich nicht öffnen.')),
      );
    }
  }
}
