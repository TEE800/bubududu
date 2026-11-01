import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/offline.dart';
import '../data/store.dart';

/// Die Kacheln der Startseite. Die Namen stehen so in Firestore
/// (users/{uid}.dashboard = {order: [...], hidden: [...]}), also nicht umbenennen.
/// Jede Person hat ihre eigene Startseite.
enum DashTile {
  aktionstage('Aktionstage', Icons.celebration_outlined),
  weather('Wetter', Icons.wb_sunny_outlined),
  today('Aufgaben heute', Icons.today),
  upcoming('Nächste Termine', Icons.event),
  shopping('Einkaufsliste', Icons.shopping_cart_outlined),
  meal('Essen', Icons.restaurant),
  money('Finanzen', Icons.euro),
  reminders('Nicht vergessen', Icons.notifications_outlined),
  health('Arzttermine', Icons.medical_services_outlined),
  depot('Mein Depot', Icons.account_balance_wallet_outlined),
  stocks('Aktien', Icons.show_chart),
  together('Zusammen seit', Icons.favorite_outline),
  location('Standort', Icons.place_outlined);

  const DashTile(this.label, this.icon);

  final String label;
  final IconData icon;
}

class DashLayout {
  const DashLayout({required this.order, required this.hidden});

  /// Alle Kacheln in der gewählten Reihenfolge (auch ausgeblendete).
  final List<DashTile> order;
  final Set<DashTile> hidden;

  static const standard = DashLayout(order: DashTile.values, hidden: {});

  List<DashTile> get visible => [
    for (final t in order)
      if (!hidden.contains(t)) t,
  ];

  /// Unbekannte Namen werden ignoriert; neue Kacheln, die noch nicht in der
  /// gespeicherten Reihenfolge stehen, kommen an ihrer Standardstelle dazu.
  factory DashLayout.fromMap(Object? raw) {
    if (raw is! Map) return standard;
    DashTile? byName(Object? n) {
      for (final t in DashTile.values) {
        if (t.name == n) return t;
      }
      return null;
    }

    final order = <DashTile>[];
    for (final n in raw['order'] as List? ?? const []) {
      final t = byName(n);
      if (t != null && !order.contains(t)) order.add(t);
    }
    for (final t in DashTile.values) {
      if (order.contains(t)) continue;
      // Hinter dem Vorgänger aus der Standardreihenfolge einsortieren.
      final prev = t.index == 0 ? null : DashTile.values[t.index - 1];
      final at = prev == null ? 0 : order.indexOf(prev) + 1;
      order.insert(at, t);
    }
    final hidden = <DashTile>{};
    for (final n in raw['hidden'] as List? ?? const []) {
      final t = byName(n);
      if (t != null) hidden.add(t);
    }
    return DashLayout(order: order, hidden: hidden);
  }

  Map<String, dynamic> toMap() => {
    'order': [for (final t in order) t.name],
    'hidden': [
      for (final t in DashTile.values)
        if (hidden.contains(t)) t.name,
    ],
  };

  DashLayout toggled(DashTile t) => DashLayout(
    order: order,
    hidden: hidden.contains(t) ? ({...hidden}..remove(t)) : {...hidden, t},
  );

  DashLayout moved(int oldIndex, int newIndex) {
    final list = [...order];
    final t = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), t);
    return DashLayout(order: list, hidden: hidden);
  }
}

final dashLayoutProvider = StreamProvider<DashLayout>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid.isEmpty) return Stream.value(DashLayout.standard);
  return ref
      .watch(firestoreProvider)
      .doc('users/$uid')
      .snapshots()
      .map((s) => DashLayout.fromMap(s.data()?['dashboard']));
});

Future<void> saveDashLayout(WidgetRef ref, DashLayout layout) {
  final uid = ref.read(uidProvider);
  return writeInBackground(
    ref.read(firestoreProvider).doc('users/$uid').set({
      'dashboard': layout.toMap(),
    }, SetOptions(merge: true)),
  );
}

/// „Kacheln auswählen & sortieren“: Haken blendet ein/aus,
/// am Griff ziehen ändert die Reihenfolge.
class DashLayoutScreen extends ConsumerWidget {
  const DashLayoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(dashLayoutProvider).value ?? DashLayout.standard;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kacheln'),
        actions: [
          TextButton(
            onPressed: () => saveDashLayout(ref, DashLayout.standard),
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
      body: ReorderableListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
        buildDefaultDragHandles: false,
        header: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(
            'Haken weg blendet eine Kachel aus. Am Griff rechts ziehen ändert '
            'die Reihenfolge. Gilt nur für deine Startseite.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        onReorderItem: (oldIndex, newIndex) =>
            saveDashLayout(ref, layout.moved(oldIndex, newIndex)),
        children: [
          for (final (i, t) in layout.order.indexed)
            CheckboxListTile(
              key: ValueKey(t),
              controlAffinity: ListTileControlAffinity.leading,
              value: !layout.hidden.contains(t),
              onChanged: (_) => saveDashLayout(ref, layout.toggled(t)),
              title: Row(
                children: [
                  Icon(t.icon, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t.label)),
                ],
              ),
              secondary: ReorderableDragStartListener(
                index: i,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
