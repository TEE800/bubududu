import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Offline-Modus: Firestore speichert alles lokal zwischen und gleicht ab,
/// sobald wieder Netz da ist. Schreibzugriffe landen sofort im lokalen Speicher;
/// ihr Future endet aber erst, wenn der Server sie bestätigt hat. Deshalb
/// warten wir in der App nicht darauf, sonst hängt ein Dialog im Supermarkt.

/// Schaltet den lokalen Zwischenspeicher ein, auch im Browser.
void enableOfflineCache(FirebaseFirestore db) {
  db.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
}

/// Zeigt Snackbars auch ohne BuildContext, z. B. wenn ein Abgleich später scheitert.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Startet einen Schreibzugriff, ohne auf den Server zu warten.
/// Scheitert er später (z. B. fehlende Rechte), sieht man einen Hinweis.
Future<void> writeInBackground(Future<void> write) {
  write.catchError((Object e) {
    debugPrint('Abgleich fehlgeschlagen: $e');
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Eine Änderung konnte nicht gespeichert werden.'),
      ),
    );
  });
  return Future.value();
}

/// true, solange das Gerät irgendeine Netzverbindung hat.
final onlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool online(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);
  yield online(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(online);
});

/// Schmaler Hinweis oben, solange keine Verbindung besteht.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider).value ?? true;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: online
              ? const SizedBox(width: double.infinity)
              : Material(
                  color: scheme.tertiaryContainer,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cloud_off,
                            size: 18,
                            color: scheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Offline – Änderungen werden später abgeglichen.',
                              style: TextStyle(
                                color: scheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        Expanded(
          child: online
              ? child
              // Der Banner hat den oberen Rand schon abgedeckt.
              : MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: child,
                ),
        ),
      ],
    );
  }
}
