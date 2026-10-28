import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'weather.dart' show httpClientProvider;

/// Kurse über die öffentliche (inoffizielle) Yahoo-Finance-Schnittstelle.
/// Funktioniert in der Handy-App; im Browser blockiert Yahoo die Anfrage.
class StockQuote {
  const StockQuote({
    required this.symbol,
    required this.name,
    required this.price,
    required this.previousClose,
    required this.currency,
  });

  final String symbol;
  final String name;
  final double price;
  final double previousClose;
  final String currency;

  double get changePercent =>
      previousClose == 0 ? 0 : (price - previousClose) / previousClose * 100;
}

const _headers = {'User-Agent': 'Mozilla/5.0 (BubuDudu-App)'};

StockQuote parseQuote(String symbol, Map<String, dynamic> json) {
  final result =
      (json['chart']['result'] as List).first as Map<String, dynamic>;
  final meta = result['meta'] as Map<String, dynamic>;
  final price = (meta['regularMarketPrice'] as num).toDouble();
  final prev =
      ((meta['chartPreviousClose'] ?? meta['previousClose'] ?? price) as num)
          .toDouble();
  return StockQuote(
    symbol: symbol,
    name: (meta['shortName'] ?? meta['longName'] ?? symbol) as String,
    price: price,
    previousClose: prev,
    currency: meta['currency'] as String? ?? '',
  );
}

final stockQuoteProvider = FutureProvider.family<StockQuote, String>((
  ref,
  symbol,
) async {
  final uri = Uri.https(
    'query1.finance.yahoo.com',
    '/v8/finance/chart/$symbol',
    {'range': '1d', 'interval': '1d'},
  );
  final res = await ref.watch(httpClientProvider).get(uri, headers: _headers);
  if (res.statusCode != 200) throw Exception('Kurs nicht verfügbar');
  return parseQuote(symbol, jsonDecode(res.body) as Map<String, dynamic>);
});

typedef StockSearchResult = ({String symbol, String name, String exchange});

Future<List<StockSearchResult>> searchStocks(
  http.Client client,
  String query,
) async {
  final uri = Uri.https('query1.finance.yahoo.com', '/v1/finance/search', {
    'q': query,
    'quotesCount': '8',
    'newsCount': '0',
  });
  final res = await client.get(uri, headers: _headers);
  if (res.statusCode != 200) return const [];
  final quotes =
      (jsonDecode(res.body) as Map<String, dynamic>)['quotes'] as List? ??
      const [];
  return [
    for (final q in quotes.cast<Map<String, dynamic>>())
      if (q['symbol'] is String)
        (
          symbol: q['symbol'] as String,
          name: (q['shortname'] ?? q['longname'] ?? q['symbol']) as String,
          exchange: (q['exchDisp'] ?? q['exchange'] ?? '') as String,
        ),
  ];
}
