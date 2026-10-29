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

// Yahoo lehnt Anfragen ohne gewöhnliche Browser-Kennung gern ab.
const _headers = {
  'User-Agent':
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36',
  'Accept': 'application/json',
};

/// Fragt query1 und bei Fehler query2 an (Yahoo drosselt die Server einzeln).
Future<http.Response?> _yahooGet(
  http.Client client,
  String path,
  Map<String, String> params,
) async {
  http.Response? last;
  for (final host in ['query1.finance.yahoo.com', 'query2.finance.yahoo.com']) {
    try {
      last = await client.get(Uri.https(host, path, params), headers: _headers);
      if (last.statusCode == 200) return last;
    } catch (_) {
      // nächsten Server versuchen
    }
  }
  return last;
}

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
  final res = await _yahooGet(
    ref.watch(httpClientProvider),
    '/v8/finance/chart/$symbol',
    {'range': '1d', 'interval': '1d'},
  );
  if (res == null || res.statusCode != 200) {
    throw Exception('Kurs nicht verfügbar');
  }
  return parseQuote(symbol, jsonDecode(res.body) as Map<String, dynamic>);
});

typedef StockSearchResult = ({String symbol, String name, String exchange});

Future<List<StockSearchResult>> searchStocks(
  http.Client client,
  String query,
) async {
  final res = await _yahooGet(client, '/v1/finance/search', {
    'q': query,
    'quotesCount': '8',
    'newsCount': '0',
  });
  if (res == null || res.statusCode != 200) return const [];
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
