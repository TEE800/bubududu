import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/offline.dart';
import '../data/providers.dart';
import '../data/store.dart';
import 'pantry.dart';

/// households/{id}/settings/pantry: Grundeinstellung für alle Vorräte.
final shopDefaultProvider = StreamProvider.family<ShopDefault, String>(
  (ref, householdId) => ref
      .watch(firestoreProvider)
      .doc('households/$householdId/settings/pantry')
      .snapshots()
      .map((s) => ShopDefault.parse(s.data()?['autoShop'] as String?)),
);

Future<void> setShopDefault(HouseholdStore store, ShopDefault value) =>
    writeInBackground(
      store.col('settings').doc('pantry').set({
        'autoShop': value.name,
      }, SetOptions(merge: true)),
    );

/// Was die Automatik tun soll.
class AutoShopPlan {
  const AutoShopPlan({
    this.add = const [],
    this.alreadyListed = const [],
    this.reset = const [],
  });

  /// Auf die Einkaufsliste setzen und merken.
  final List<PantryItem> add;

  /// Steht schon offen auf der Liste: nur merken.
  final List<PantryItem> alreadyListed;

  /// Wieder aufgefüllt (oder Regel geändert): Merker löschen, damit es beim
  /// nächsten Mal wieder automatisch kommt.
  final List<PantryItem> reset;

  bool get isEmpty => add.isEmpty && alreadyListed.isEmpty && reset.isEmpty;
}

/// [openOnList]: offene Einträge der Einkaufsliste, kleingeschrieben.
AutoShopPlan planAutoShop(
  List<PantryItem> items,
  Set<String> openOnList,
  ShopDefault all,
  DateTime now,
) {
  final add = <PantryItem>[];
  final listed = <PantryItem>[];
  final reset = <PantryItem>[];
  final seen = {...openOnList};
  for (final i in items) {
    if (i.name.trim().isEmpty) continue;
    final wants = i.wantsShopping(now, all);
    if (!wants) {
      if (i.autoShopped) reset.add(i);
      continue;
    }
    if (i.autoShopped) continue;
    if (seen.add(i.name.trim().toLowerCase())) {
      add.add(i);
    } else {
      listed.add(i);
    }
  }
  return AutoShopPlan(add: add, alreadyListed: listed, reset: reset);
}

/// Setzt knappe Vorräte von selbst auf die Einkaufsliste, solange die App
/// offen ist: bei jeder Änderung und alle 15 Minuten (für den automatischen
/// Verbrauch, der ohne Speichern weiterläuft).
class PantryAutoShop extends ConsumerStatefulWidget {
  const PantryAutoShop({
    super.key,
    required this.householdId,
    required this.child,
  });

  final String householdId;
  final Widget child;

  @override
  ConsumerState<PantryAutoShop> createState() => _PantryAutoShopState();
}

class _PantryAutoShopState extends ConsumerState<PantryAutoShop> {
  Timer? _debounce;
  Timer? _timer;

  /// Schon geschrieben, aber noch nicht zurück im Vorrat.
  final _written = <String>{};

  @override
  void initState() {
    super.initState();
    final id = widget.householdId;
    void later(Object? _, Object? _) => _schedule();
    ref.listenManual(pantryProvider(id), later, fireImmediately: true);
    ref.listenManual(shopDefaultProvider(id), later);
    ref.listenManual(shoppingItemsProvider(id), later);
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => _schedule());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _run);
  }

  Future<void> _run() async {
    if (!mounted) return;
    final id = widget.householdId;
    final items = ref.read(pantryProvider(id)).value;
    final all = ref.read(shopDefaultProvider(id)).value;
    final shopping = ref.read(shoppingItemsProvider(id)).value;
    if (items == null || all == null || shopping == null) return;
    final onList = {
      for (final s in shopping)
        if (!s.done) s.text.trim().toLowerCase(),
    };
    // Was schon zurück im Vorrat gemerkt ist, braucht keinen Schutz mehr.
    final marked = {
      for (final i in items)
        if (i.autoShopped) i.id,
    };
    _written.removeWhere(marked.contains);
    final plan = planAutoShop(
      [
        for (final i in items)
          if (!_written.contains(i.id)) i,
      ],
      onList,
      all,
      DateTime.now(),
    );
    if (plan.isEmpty) return;
    final store = ref.read(storeProvider(id));
    final batch = store.firestore.batch();
    for (final i in plan.add) {
      // Feste ID: Laufen beide Handys gleichzeitig, bleibt es ein Eintrag.
      batch.set(store.col('shoppingItems').doc('auto-${i.id}'), {
        'text': i.name.trim(),
        'done': false,
        'addedBy': store.uid,
        'fromPantry': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    for (final i in [...plan.add, ...plan.alreadyListed]) {
      batch.update(store.col('pantry').doc(i.id), {'autoShopped': true});
      _written.add(i.id);
    }
    for (final i in plan.reset) {
      batch.update(store.col('pantry').doc(i.id), {'autoShopped': false});
    }
    await writeInBackground(batch.commit());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Auswahl der Grundeinstellung als Blatt von unten.
Future<void> showShopDefaultSheet(
  BuildContext context,
  WidgetRef ref,
  String householdId,
  ShopDefault current,
) async {
  final picked = await showModalBottomSheet<ShopDefault>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'Automatisch auf die Einkaufsliste',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Gilt für alle Vorräte, für euch beide. Einzelne Vorräte '
                'kannst du beim Bearbeiten anders einstellen.',
              ),
            ),
            RadioGroup<ShopDefault>(
              groupValue: current,
              onChanged: (v) => Navigator.of(context).pop(v),
              child: Column(
                children: [
                  for (final v in ShopDefault.values)
                    RadioListTile<ShopDefault>(
                      value: v,
                      title: Text(v.label),
                      subtitle: Text(v.hint),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (picked == null || picked == current) return;
  await setShopDefault(ref.read(storeProvider(householdId)), picked);
}
