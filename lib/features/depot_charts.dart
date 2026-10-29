import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/stocks.dart';
import '../util/dates.dart';
import '../util/trade_republic.dart';
import 'depot.dart';

/// Grafiken zu "Mein Depot": Verlauf, Aufteilung, Gewinn je Position.

typedef DepotPoint = ({DateTime day, double value});

/// Wert der heutigen Positionen über die Zeit (mit heutigen Stückzahlen).
/// Fremdwährungen werden mit dem heutigen Wechselkurs umgerechnet.
List<DepotPoint> combineHistory(
  List<({double shares, double factor, PriceHistory history})> series,
  double constant,
) {
  final days = <DateTime>{for (final s in series) ...s.history.days}.toList()
    ..sort();
  if (days.isEmpty) return const [];
  final result = <DepotPoint>[];
  final index = List.filled(series.length, 0);
  for (final day in days) {
    var total = constant;
    for (var i = 0; i < series.length; i++) {
      final h = series[i].history;
      if (h.closes.isEmpty) continue;
      // Letzten Schlusskurs bis zu diesem Tag nehmen (vorher: den ersten).
      while (index[i] + 1 < h.days.length &&
          !h.days[index[i] + 1].isAfter(day)) {
        index[i]++;
      }
      total += series[i].shares * h.closes[index[i]] * series[i].factor;
    }
    result.add((day: day, value: total));
  }
  return result;
}

final depotHistoryProvider =
    Provider.family<AsyncValue<List<DepotPoint>>, String>((ref, range) {
      final positions = ref.watch(depotProvider).value?.positions ?? const [];
      final series = <({double shares, double factor, PriceHistory history})>[];
      var constant = 0.0;
      var loading = false;
      for (final p in positions) {
        final symbol = p.symbol;
        final history = symbol == null
            ? null
            : ref
                  .watch(priceHistoryProvider((symbol: symbol, range: range)))
                  .value;
        final native = symbol == null
            ? null
            : ref.watch(stockQuoteProvider(symbol)).value;
        final euro = symbol == null
            ? null
            : ref.watch(euroQuoteProvider(symbol)).value;
        if (symbol != null &&
            (ref
                    .watch(priceHistoryProvider((symbol: symbol, range: range)))
                    .isLoading ||
                ref.watch(euroQuoteProvider(symbol)).isLoading)) {
          loading = true;
        }
        if (history != null && history.closes.isNotEmpty) {
          final factor = native != null && euro != null && native.price > 0
              ? euro.price / native.price
              : (history.currency == 'EUR' ? 1.0 : null);
          if (factor != null) {
            series.add((shares: p.shares, factor: factor, history: history));
            continue;
          }
        }
        constant += positionValue(
          p,
          euro == null ? null : AsyncData(euro),
        ).value;
      }
      if (loading && series.isEmpty) return const AsyncLoading();
      return AsyncData(combineHistory(series, constant));
    });

class DepotCharts extends ConsumerStatefulWidget {
  const DepotCharts({super.key, required this.positions});

  final List<DepotPosition> positions;

  @override
  ConsumerState<DepotCharts> createState() => _DepotChartsState();
}

class _DepotChartsState extends ConsumerState<DepotCharts> {
  String _range = '6mo';

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final p in widget.positions)
        (
          position: p,
          value: positionValue(
            p,
            p.symbol == null ? null : ref.watch(euroQuoteProvider(p.symbol!)),
          ).value,
        ),
    ];
    final history = ref.watch(depotHistoryProvider(_range));
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verlauf', style: text.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: '1mo', label: Text('1 Monat')),
                    ButtonSegment(value: '6mo', label: Text('6 Monate')),
                    ButtonSegment(value: '1y', label: Text('1 Jahr')),
                  ],
                  selected: {_range},
                  onSelectionChanged: (s) => setState(() => _range = s.first),
                ),
                const SizedBox(height: 12),
                history.when(
                  loading: () => const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => const Text('Verlauf nicht verfügbar.'),
                  data: (points) => points.length < 2
                      ? const Text('Für den Verlauf fehlen noch Kurse.')
                      : DepotLineChart(points: points),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mit deinen heutigen Stückzahlen gerechnet, Käufe und '
                  'Verkäufe in diesem Zeitraum sind nicht berücksichtigt.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aufteilung', style: text.titleMedium),
                const SizedBox(height: 12),
                AllocationBars(values: values),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gewinn und Verlust', style: text.titleMedium),
                const SizedBox(height: 12),
                GainBars(values: values),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Linie mit Fadenkreuz: Antippen oder Wischen zeigt Tag und Wert.
class DepotLineChart extends StatefulWidget {
  const DepotLineChart({super.key, required this.points});

  final List<DepotPoint> points;

  @override
  State<DepotLineChart> createState() => _DepotLineChartState();
}

class _DepotLineChartState extends State<DepotLineChart> {
  int? _selected;

  void _select(Offset local, double width) {
    final n = widget.points.length;
    final i = (local.dx / width * (n - 1)).round().clamp(0, n - 1);
    if (i != _selected) setState(() => _selected = i);
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final first = points.first.value;
    final shown = points[_selected ?? points.length - 1];
    final change = shown.value - first;
    final percent = first == 0 ? 0.0 : change / first * 100;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatEuro(shown.value),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          '${formatSigned(change)} (${formatPercent(percent)}) '
          'seit ${formatShortDate(points.first.day)}'
          '${_selected == null ? '' : ' · am ${formatShortDate(shown.day)}'}',
          style: TextStyle(color: gainColor(context, change)),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _select(d.localPosition, width),
              onHorizontalDragUpdate: (d) => _select(d.localPosition, width),
              onHorizontalDragEnd: (_) => setState(() => _selected = null),
              onTapUp: (_) {},
              child: SizedBox(
                height: 160,
                width: width,
                child: CustomPaint(
                  painter: _LinePainter(
                    points: points,
                    selected: _selected,
                    line: scheme.primary,
                    grid: scheme.outlineVariant,
                    surface: scheme.surface,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.selected,
    required this.line,
    required this.grid,
    required this.surface,
  });

  final List<DepotPoint> points;
  final int? selected;
  final Color line;
  final Color grid;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((p) => p.value);
    var lo = values.reduce(math.min);
    var hi = values.reduce(math.max);
    if (hi - lo < 1) {
      hi += 1;
      lo -= 1;
    }
    final pad = (hi - lo) * 0.08;
    lo -= pad;
    hi += pad;
    Offset at(int i) => Offset(
      points.length == 1 ? 0 : i / (points.length - 1) * size.width,
      size.height - (points[i].value - lo) / (hi - lo) * size.height,
    );

    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var k = 0; k <= 2; k++) {
      final y = size.height * k / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.18), line.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final s = selected;
    if (s != null) {
      final p = at(s);
      canvas.drawLine(
        Offset(p.dx, 0),
        Offset(p.dx, size.height),
        Paint()
          ..color = grid
          ..strokeWidth = 1,
      );
      canvas.drawCircle(p, 6, Paint()..color = surface);
      canvas.drawCircle(p, 4, Paint()..color = line);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.points != points || old.selected != selected || old.line != line;
}

typedef PositionShare = ({DepotPosition position, double value});

/// Anteil jeder Position am Depot, größte zuerst.
class AllocationBars extends StatelessWidget {
  const AllocationBars({super.key, required this.values});

  final List<PositionShare> values;

  @override
  Widget build(BuildContext context) {
    final total = values.fold(0.0, (s, v) => s + v.value);
    final sorted = [...values]..sort((a, b) => b.value.compareTo(a.value));
    final max = sorted.isEmpty ? 0.0 : sorted.first.value;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final v in sorted)
          _BarRow(
            label: v.position.name,
            trailing:
                '${(total == 0 ? 0 : v.value / total * 100).toStringAsFixed(1).replaceAll('.', ',')} %',
            detail: formatEuro(v.value),
            fraction: max == 0 ? 0 : v.value / max,
            color: scheme.primary,
            track: scheme.surfaceContainerHighest,
          ),
      ],
    );
  }
}

/// Gewinn oder Verlust je Position seit dem Kauf, Balken von der Mitte aus.
class GainBars extends StatelessWidget {
  const GainBars({super.key, required this.values});

  final List<PositionShare> values;

  @override
  Widget build(BuildContext context) {
    final gains = [
      for (final v in values)
        if (v.position.invested > 0)
          (
            name: v.position.name,
            gain: v.value - v.position.invested,
            percent:
                (v.value - v.position.invested) / v.position.invested * 100,
          ),
    ]..sort((a, b) => b.gain.compareTo(a.gain));
    if (gains.isEmpty) {
      return const Text('Ohne Kaufbeträge lässt sich kein Gewinn berechnen.');
    }
    final max = gains.map((g) => g.gain.abs()).reduce(math.max);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final g in gains)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(g.name, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${formatSigned(g.gain)} · ${formatPercent(g.percent)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 10,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FractionallySizedBox(
                            heightFactor: 1,
                            widthFactor: g.gain < 0 && max > 0
                                ? g.gain.abs() / max
                                : 0,
                            child: _bar(scheme.error, left: true),
                          ),
                        ),
                      ),
                      Container(width: 1, color: scheme.outline),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            heightFactor: 1,
                            widthFactor: g.gain > 0 && max > 0
                                ? g.gain / max
                                : 0,
                            child: _bar(Colors.green.shade700, left: false),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _bar(Color color, {required bool left}) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: left
          ? const BorderRadius.horizontal(left: Radius.circular(4))
          : const BorderRadius.horizontal(right: Radius.circular(4)),
    ),
  );
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.trailing,
    required this.detail,
    required this.fraction,
    required this.color,
    required this.track,
  });

  final String label;
  final String trailing;
  final String detail;
  final double fraction;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Text(detail, style: small),
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                child: Text(trailing, textAlign: TextAlign.end),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: track)),
                  FractionallySizedBox(
                    heightFactor: 1,
                    widthFactor: fraction.clamp(0, 1),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
