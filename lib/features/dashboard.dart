import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../data/store.dart';
import '../services/stocks.dart';
import '../services/weather.dart';
import '../util/dates.dart';
import '../util/money.dart';
import '../widgets/common.dart';
import '../widgets/mascots.dart';
import 'calendar.dart';
import 'care.dart';
import 'contracts.dart';
import 'depot.dart';
import 'finance.dart';
import 'health.dart';
import 'location.dart';
import 'meals.dart';
import 'tasks.dart';
import 'us.dart';
import 'weather_screen.dart';

/// Einstellungen der Startseite liegen im Haushalts-Dokument:
/// weatherPlace = {name, lat, lng}, stocks = [Symbole].
final weatherPlaceProvider = Provider.family<Place?, String>(
  (ref, householdId) => Place.fromMap(
    ref.watch(householdDataProvider(householdId)).value?['weatherPlace'],
  ),
);

final stockSymbolsProvider = Provider.family<List<String>, String>(
  (ref, householdId) => List<String>.from(
    ref.watch(householdDataProvider(householdId)).value?['stocks'] as List? ??
        const [],
  ),
);

/// Die Startseite. [onOpenTab] wechselt den Tab unten (0 = Start).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({
    super.key,
    required this.householdId,
    required this.onOpenTab,
    required this.onOpenPage,
  });

  final String householdId;
  final ValueChanged<int> onOpenTab;

  /// Öffnet eine Seite aus "Mehr" (z. B. Finanzen).
  final void Function(Widget page) onOpenPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(uidProvider);
    final Household? household = ref
        .watch(householdProvider(householdId))
        .value;
    final name = household?.memberNames[uid] ?? '';
    final now = DateTime.now();
    final greeting = now.hour < 11
        ? 'Guten Morgen'
        : now.hour < 18
        ? 'Hallo'
        : 'Guten Abend';

    return Scaffold(
      appBar: AppBar(
        title: Text(name.isEmpty ? greeting : '$greeting, $name'),
        actions: [
          IconButton(
            tooltip: 'Startseite einrichten',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    DashboardSettingsScreen(householdId: householdId),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(weatherProvider);
          ref.invalidate(devicePlaceProvider);
          ref.invalidate(stockQuoteProvider);
          ref.invalidate(euroQuoteProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${weekdayLong(now)}, ${now.day}. ${monthNames[now.month - 1]} ${now.year}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Mascots(mood: moodForTime(now), height: 64),
                ],
              ),
            ),
            _WeatherCard(householdId: householdId),
            _TodayCard(householdId: householdId, onOpenTab: onOpenTab),
            _UpcomingCard(householdId: householdId, onOpenTab: onOpenTab),
            _ShoppingCard(householdId: householdId, onOpenTab: onOpenTab),
            _MealCard(householdId: householdId, onOpenPage: onOpenPage),
            _MoneyCard(householdId: householdId, onOpenPage: onOpenPage),
            _RemindersCard(householdId: householdId, onOpenPage: onOpenPage),
            _HealthCard(householdId: householdId, onOpenPage: onOpenPage),
            _DepotCard(onOpenPage: onOpenPage),
            _StocksCard(householdId: householdId),
            TogetherCard(householdId: householdId),
            _LocationCard(householdId: householdId, onOpenPage: onOpenPage),
          ],
        ),
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  const _DashCard({
    required this.icon,
    required this.title,
    required this.child,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (onTap != null) const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherCard extends ConsumerWidget {
  const _WeatherCard({required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(weatherLocationProvider(householdId));
    void openSettings() => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DashboardSettingsScreen(householdId: householdId),
      ),
    );
    final place = location.value;
    if (place == null) {
      return _DashCard(
        icon: Icons.wb_sunny_outlined,
        title: 'Wetter',
        onTap: openSettings,
        child: location.isLoading
            ? const LinearProgressIndicator()
            : Text(
                location.hasError
                    ? 'Standort nicht verfügbar. Tippe hier und wähle euren Ort.'
                    : 'Tippe hier und wähle euren Ort oder lass ihn automatisch erkennen.',
              ),
      );
    }
    final weather = ref.watch(
      weatherProvider((lat: place.lat, lng: place.lng)),
    );
    return _DashCard(
      icon: Icons.wb_sunny_outlined,
      title: 'Wetter in ${place.name.split(',').first}',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WeatherScreen(place: place, onSettings: openSettings),
        ),
      ),
      child: weather.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => const Text('Wetter gerade nicht erreichbar.'),
        data: (w) {
          final (text, icon) = describeWeather(w.code);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 40),
                  const SizedBox(width: 12),
                  Text(
                    '${w.temperature.round()}°',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(text)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final d in w.days.take(3))
                    Expanded(
                      child: Column(
                        children: [
                          Text(relativeDay(d.date).split(',').first),
                          Icon(describeWeather(d.code).$2),
                          Text('${d.min.round()}° / ${d.max.round()}°'),
                          Text(
                            '${d.rainChance} % Regen',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.householdId, required this.onOpenTab});

  final String householdId;
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final tasks =
        ref.watch(tasksProvider(householdId)).value ?? const <HouseTask>[];
    final names = memberNames(ref, householdId);
    final due = tasks
        .where((t) => t.isOverdue(now) || t.isDueToday(now))
        .toList();
    return _DashCard(
      icon: Icons.cleaning_services_outlined,
      title: 'Aufgaben heute',
      onTap: () => onOpenTab(2),
      child: due.isEmpty
          ? const Text('Nichts fällig. Genießt den Tag!')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final t in due.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '• ${t.title} (${t.assignee.isEmpty ? 'Beide' : names[t.assignee] ?? '?'})'
                      '${t.isOverdue(now) ? ', überfällig' : ''}',
                      style: t.isOverdue(now)
                          ? TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            )
                          : null,
                    ),
                  ),
                if (due.length > 5) Text('und ${due.length - 5} weitere'),
              ],
            ),
    );
  }
}

class _UpcomingCard extends ConsumerWidget {
  const _UpcomingCard({required this.householdId, required this.onOpenTab});

  final String householdId;
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events =
        ref.watch(eventsProvider(householdId)).value ?? const <CalendarEvent>[];
    final next = occurrences(
      events,
      today(),
      addDays(today(), 14),
    ).take(4).toList();
    return _DashCard(
      icon: Icons.calendar_month_outlined,
      title: 'Nächste Termine',
      onTap: () => onOpenTab(3),
      child: next.isEmpty
          ? const Text('Keine Termine in den nächsten zwei Wochen.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final o in next)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${relativeDay(o.day)}${o.event.time == null ? '' : ', ${o.event.time}'}: '
                      '${o.event.title}',
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ShoppingCard extends ConsumerWidget {
  const _ShoppingCard({required this.householdId, required this.onOpenTab});

  final String householdId;
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(shoppingItemsProvider(householdId)).value ?? const [];
    final open = items.where((i) => !i.done).toList();
    return _DashCard(
      icon: Icons.shopping_cart_outlined,
      title: 'Einkaufsliste',
      onTap: () => onOpenTab(1),
      child: Text(
        open.isEmpty
            ? 'Alles eingekauft.'
            : '${open.length} offen: ${open.take(4).map((i) => i.text).join(', ')}'
                  '${open.length > 4 ? ' …' : ''}',
      ),
    );
  }
}

class _MealCard extends ConsumerWidget {
  const _MealCard({required this.householdId, required this.onOpenPage});

  final String householdId;
  final void Function(Widget page) onOpenPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(mealPlanProvider(householdId)).value ?? const {};
    final recipes = ref.watch(recipesProvider(householdId)).value ?? const [];
    final todayMeal = plan[mealDocId(today())];
    final tomorrowMeal = plan[mealDocId(addDays(today(), 1))];
    return _DashCard(
      icon: Icons.restaurant_outlined,
      title: 'Essen',
      onTap: () => onOpenPage(MealPlanScreen(householdId: householdId)),
      child: Text(
        [
          'Heute: ${todayMeal ?? 'noch nichts geplant'}',
          if (tomorrowMeal != null) 'Morgen: $tomorrowMeal',
          // Jeden Tag ein anderer Vorschlag aus euren Rezepten.
          if (todayMeal == null && recipes.isNotEmpty)
            'Idee: ${recipes[today().difference(DateTime(2020)).inDays % recipes.length].title}',
        ].join('\n'),
      ),
    );
  }
}

class _MoneyCard extends ConsumerWidget {
  const _MoneyCard({required this.householdId, required this.onOpenPage});

  final String householdId;
  final void Function(Widget page) onOpenPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses =
        ref.watch(expensesProvider(householdId)).value ?? const <Expense>[];
    final names = memberNames(ref, householdId);
    final members = memberIds(ref, householdId);
    final now = DateTime.now();
    final month = categoryTotals(
      expenses,
      now,
    ).values.fold<int>(0, (s, v) => s + v);
    final text = balanceText(expenses, members, names);
    return _DashCard(
      icon: Icons.euro,
      title: 'Finanzen',
      onTap: () => onOpenPage(FinanceScreen(householdId: householdId)),
      child: Text(
        [
          ?text,
          'Ausgaben im ${monthNames[now.month - 1]}: ${formatCents(month)}',
        ].join('\n'),
      ),
    );
  }
}

/// Arzttermine der nächsten 30 Tage. Erscheint nur, wenn es welche gibt.
class _HealthCard extends ConsumerWidget {
  const _HealthCard({required this.householdId, required this.onOpenPage});

  final String householdId;
  final void Function(Widget page) onOpenPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final names = memberNames(ref, householdId);
    final soon = upcomingAppointments(
      ref.watch(healthEntriesProvider(householdId)).value ?? const [],
      now,
    ).where((e) => daysBetween(today(), e.date) <= 30).take(3).toList();
    if (soon.isEmpty) return const SizedBox.shrink();
    return _DashCard(
      icon: Icons.health_and_safety_outlined,
      title: 'Arzttermine',
      onTap: () => onOpenPage(HealthScreen(householdId: householdId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in soon)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• ${relativeDay(e.date)}: ${e.title}'
                '${names[e.person] != null ? ' (${names[e.person]})' : ''}',
              ),
            ),
        ],
      ),
    );
  }
}

/// Fällige Pflege und Kündigungsfristen. Erscheint nur, wenn es etwas gibt.
class _RemindersCard extends ConsumerWidget {
  const _RemindersCard({required this.householdId, required this.onOpenPage});

  final String householdId;
  final void Function(Widget page) onOpenPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final all =
        ref.watch(careProvider(householdId)).value ?? const <CareItem>[];
    final care = [
      for (final c in all)
        if (c.isDue(now)) '${c.name}: ${c.action}',
      for (final c in all)
        if (c.isFertilizeDue(now)) '${c.name}: Düngen',
    ];
    final deadlines = upcomingDeadlines(
      ref.watch(contractsProvider(householdId)).value ?? const [],
      now: now,
    );
    if (care.isEmpty && deadlines.isEmpty) return const SizedBox.shrink();
    return _DashCard(
      icon: Icons.notifications_active_outlined,
      title: 'Nicht vergessen',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in care)
            InkWell(
              onTap: () => onOpenPage(CareScreen(householdId: householdId)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $c'),
              ),
            ),
          for (final c in deadlines)
            InkWell(
              onTap: () =>
                  onOpenPage(ContractsScreen(householdId: householdId)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• ${c.name} kündigen bis ${formatShortDate(c.cancelBy!)}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Nur für mich: Wert meines importierten Depots.
class _DepotCard extends ConsumerWidget {
  const _DepotCard({required this.onOpenPage});

  final void Function(Widget page) onOpenPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positions = ref.watch(depotProvider).value?.positions ?? const [];
    if (positions.isEmpty) return const SizedBox.shrink();
    final total = ref.watch(depotTotalProvider);
    return _DashCard(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Mein Depot',
      onTap: () => onOpenPage(const DepotScreen()),
      child: Row(
        children: [
          Expanded(
            child: Text(
              formatEuro(total.value),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Text(
            'Heute ${formatSigned(total.dayChange)}',
            style: TextStyle(color: gainColor(context, total.dayChange)),
          ),
        ],
      ),
    );
  }
}

class _StocksCard extends ConsumerWidget {
  const _StocksCard({required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbols = ref.watch(stockSymbolsProvider(householdId));
    void openSettings() => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DashboardSettingsScreen(householdId: householdId),
      ),
    );
    return _DashCard(
      icon: Icons.show_chart,
      title: 'Aktien',
      onTap: openSettings,
      child: symbols.isEmpty
          ? const Text('Tippe hier, um Aktien oder ETFs hinzuzufügen.')
          : Column(
              children: [
                for (final s in symbols)
                  ref
                      .watch(stockQuoteProvider(s))
                      .when(
                        loading: () => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(s),
                          trailing: const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: (_, _) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(s),
                          trailing: const Text('nicht verfügbar'),
                        ),
                        data: (q) {
                          final up = q.changePercent >= 0;
                          final color = up
                              ? Colors.green.shade700
                              : Theme.of(context).colorScheme.error;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              q.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(q.symbol),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${q.price.toStringAsFixed(2).replaceAll('.', ',')} ${q.currency}',
                                ),
                                Text(
                                  '${up ? '+' : ''}${q.changePercent.toStringAsFixed(2).replaceAll('.', ',')} %',
                                  style: TextStyle(color: color),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
    );
  }
}

class _LocationCard extends ConsumerWidget {
  const _LocationCard({required this.householdId, required this.onOpenPage});

  final String householdId;
  final void Function(Widget page) onOpenPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(uidProvider);
    final others = (ref.watch(locationsProvider(householdId)).value ?? const [])
        .where((l) => l.uid != uid)
        .toList();
    final sharing = ref.watch(shareLocationProvider).value ?? false;
    if (others.isEmpty && !sharing) return const SizedBox.shrink();
    final names = memberNames(ref, householdId);
    return _DashCard(
      icon: Icons.location_on_outlined,
      title: 'Standort',
      onTap: () => onOpenPage(LocationScreen(householdId: householdId)),
      child: Text(
        [
          if (sharing) 'Du teilst gerade deinen Standort.',
          for (final l in others)
            '${names[l.uid] ?? '?'} teilt den Standort (${agoText(l.updatedAt)})',
        ].join('\n'),
      ),
    );
  }
}

class DashboardSettingsScreen extends ConsumerStatefulWidget {
  const DashboardSettingsScreen({super.key, required this.householdId});

  final String householdId;

  @override
  ConsumerState<DashboardSettingsScreen> createState() =>
      _DashboardSettingsScreenState();
}

class _DashboardSettingsScreenState
    extends ConsumerState<DashboardSettingsScreen> {
  final _placeQuery = TextEditingController();
  final _stockQuery = TextEditingController();
  List<Place> _places = const [];
  List<StockSearchResult> _stocks = const [];
  bool _searching = false;

  @override
  void dispose() {
    _placeQuery.dispose();
    _stockQuery.dispose();
    super.dispose();
  }

  Future<void> _searchPlace() async {
    if (_placeQuery.text.trim().isEmpty) return;
    setState(() => _searching = true);
    final result = await searchPlaces(
      ref.read(httpClientProvider),
      _placeQuery.text.trim(),
    ).catchError((_) => <Place>[]);
    if (!mounted) return;
    setState(() {
      _places = result;
      _searching = false;
    });
    if (result.isEmpty) showError(context, 'Keinen Ort gefunden.');
  }

  Future<void> _searchStock() async {
    if (_stockQuery.text.trim().isEmpty) return;
    setState(() => _searching = true);
    final result = await searchStocks(
      ref.read(httpClientProvider),
      _stockQuery.text.trim(),
    ).catchError((_) => <StockSearchResult>[]);
    if (!mounted) return;
    setState(() {
      _stocks = result;
      _searching = false;
    });
    if (result.isEmpty) {
      showError(context, 'Nichts gefunden. Probier den Namen oder das Kürzel.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.read(storeProvider(widget.householdId));
    final place = ref.watch(weatherPlaceProvider(widget.householdId));
    final symbols = ref.watch(stockSymbolsProvider(widget.householdId));
    final auto = ref.watch(weatherAutoProvider(widget.householdId));

    return Scaffold(
      appBar: AppBar(title: const Text('Startseite einrichten')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_searching) const LinearProgressIndicator(),
          Text('Wetter', style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.my_location),
            title: const Text('Standort automatisch erkennen'),
            subtitle: const Text(
              'Wetter für den Ort, an dem das Handy gerade ist',
            ),
            value: auto,
            onChanged: (v) async {
              if (v) {
                final error = await ensureLocationPermission();
                if (error != null) {
                  if (context.mounted) showError(context, error);
                  return;
                }
                ref.invalidate(devicePlaceProvider);
              }
              await store.updateHousehold({'weatherAuto': v});
            },
          ),
          if (!auto && place != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place),
              title: Text(place.name),
            ),
          TextField(
            controller: _placeQuery,
            decoration: InputDecoration(
              labelText: 'Ort suchen',
              hintText: 'z. B. Leipzig',
              suffixIcon: IconButton(
                tooltip: 'Suchen',
                icon: const Icon(Icons.search),
                onPressed: _searchPlace,
              ),
            ),
            onSubmitted: (_) => _searchPlace(),
          ),
          for (final p in _places)
            ListTile(
              title: Text(p.name),
              onTap: () async {
                await store.updateHousehold({
                  'weatherPlace': p.toMap(),
                  'weatherAuto': false,
                });
                if (mounted) setState(() => _places = const []);
              },
            ),
          const SizedBox(height: 32),
          Text('Aktien & ETFs', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Mein Depot (Trade Republic)'),
            subtitle: const Text('Export importieren, nur für dich sichtbar'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const DepotScreen())),
          ),
          for (final s in symbols)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.show_chart),
              title: Text(s),
              trailing: IconButton(
                tooltip: 'Entfernen',
                icon: const Icon(Icons.close),
                onPressed: () => store.updateHousehold({
                  'stocks': [...symbols]..remove(s),
                }),
              ),
            ),
          TextField(
            controller: _stockQuery,
            decoration: InputDecoration(
              labelText: 'Aktie suchen',
              hintText: 'z. B. Apple, SAP, MSCI World',
              suffixIcon: IconButton(
                tooltip: 'Suchen',
                icon: const Icon(Icons.search),
                onPressed: _searchStock,
              ),
            ),
            onSubmitted: (_) => _searchStock(),
          ),
          for (final s in _stocks)
            ListTile(
              title: Text(s.name),
              subtitle: Text('${s.symbol} · ${s.exchange}'),
              trailing: symbols.contains(s.symbol)
                  ? const Icon(Icons.check)
                  : const Icon(Icons.add),
              onTap: symbols.contains(s.symbol)
                  ? null
                  : () => store.updateHousehold({
                      'stocks': [...symbols, s.symbol],
                    }),
            ),
          const SizedBox(height: 16),
          Text(
            'Kurse kommen von Yahoo Finance und können verzögert sein.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
