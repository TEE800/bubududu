import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/providers.dart';
import '../util/plant_care_hints.dart';

/// Ein Vorschlag der Pflanzenerkennung (Pl@ntNet über unsere Funktion).
class PlantSuggestion {
  const PlantSuggestion({
    required this.scientificName,
    required this.genus,
    required this.commonNames,
    required this.score,
  });

  final String scientificName;
  final String genus;
  final List<String> commonNames;

  /// 0 bis 1.
  final double score;

  factory PlantSuggestion.fromJson(Map<String, dynamic> j) => PlantSuggestion(
    scientificName: j['scientificName'] as String? ?? '',
    genus: j['genus'] as String? ?? '',
    commonNames: [
      for (final n in (j['commonNames'] as List? ?? const [])) '$n',
    ],
    score: (j['score'] as num?)?.toDouble() ?? 0,
  );

  /// Deutscher Name, sonst die Gattung, sonst der wissenschaftliche Name.
  String get displayName {
    final n = commonNames.where((n) => n.trim().isNotEmpty).firstOrNull;
    if (n != null) return n[0].toUpperCase() + n.substring(1);
    return genus.isNotEmpty ? genus : scientificName;
  }

  int get percent => (score * 100).round();

  PlantCareHint? get careHint =>
      careHintFor(genus.isNotEmpty ? genus : scientificName);
}

class PlantIdentifyException implements Exception {
  const PlantIdentifyException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Erkennt eine Pflanze auf einem Foto. Im Test ersetzbar.
typedef PlantIdentifier = Future<List<PlantSuggestion>> Function(
  String householdId,
  Uint8List jpeg,
);

const identifyPlantUrl =
    'https://europe-west3-bubududu-15f3f.cloudfunctions.net/identifyPlant';

final plantIdentifierProvider = Provider<PlantIdentifier>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return (householdId, jpeg) async {
    final token = await auth.currentUser?.getIdToken();
    if (token == null) {
      throw const PlantIdentifyException('Bitte melde dich erst an.');
    }
    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(identifyPlantUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'householdId': householdId,
              'image': base64Encode(jpeg),
            }),
          )
          .timeout(const Duration(seconds: 40));
    } catch (_) {
      throw const PlantIdentifyException(
        'Keine Verbindung. Die Erkennung braucht Internet.',
      );
    }
    return parseIdentifyResponse(res.statusCode, res.body);
  };
});

/// Antwort der Funktion → Vorschläge oder verständlicher Fehler.
List<PlantSuggestion> parseIdentifyResponse(int status, String body) {
  Map<String, dynamic> json;
  try {
    json = jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    json = const {};
  }
  if (status == 200) {
    return [
      for (final s in (json['suggestions'] as List? ?? const []))
        PlantSuggestion.fromJson(s as Map<String, dynamic>),
    ];
  }
  throw PlantIdentifyException(switch (json['error']) {
    'not-configured' =>
      'Die Pflanzenerkennung ist noch nicht eingerichtet '
          '(der Pl@ntNet-Schlüssel fehlt).',
    'quota' =>
      'Für heute sind alle Erkennungen aufgebraucht. Morgen geht es wieder.',
    'bad-image' => 'Mit dem Foto ging es nicht. Probier ein anderes.',
    _ => 'Die Erkennung hat gerade nicht geklappt. Probier es später nochmal.',
  });
}

/// Liste der Vorschläge. Gibt den gewählten zurück oder null.
Future<PlantSuggestion?> showPlantSuggestions(
  BuildContext context,
  Uint8List photo,
  List<PlantSuggestion> suggestions,
) => showModalBottomSheet<PlantSuggestion>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              photo,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          title: Text(
            suggestions.isEmpty ? 'Keine Pflanze erkannt' : 'Das könnte sein:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            suggestions.isEmpty
                ? 'Probier ein Foto, auf dem ein Blatt oder eine Blüte '
                      'groß und scharf zu sehen ist.'
                : 'Tippe auf die passende Pflanze.',
          ),
        ),
        for (final s in suggestions)
          ListTile(
            leading: CircleAvatar(child: Text('${s.percent}%')),
            title: Text(s.displayName),
            subtitle: Text(
              [
                s.scientificName,
                if (s.careHint != null) 'mit Pflegetipps',
              ].join(' · '),
            ),
            onTap: () => Navigator.pop(context, s),
          ),
        const SizedBox(height: 8),
      ],
    ),
  ),
);
