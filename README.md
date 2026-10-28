# Bubu & Dudu

Die App für unseren gemeinsamen Alltag: Einkauf, Haushalt, Kalender, Finanzen und mehr.
Gebaut mit Flutter (eine App für iPhone und Android) und Firebase (Login, Datenbank, Live-Sync).

Das Konzept mit allen geplanten Bereichen und dem MVP liegt im Projekt als Dokument
„Bubu-Dudu-App – Konzept“.

## Was schon geht

- Konto anlegen und anmelden (E-Mail und Passwort)
- Gemeinsamen Haushalt anlegen, Partner tritt mit 6-stelligem Einladungscode bei
- Einkaufsliste: hinzufügen, abhaken, wischen zum Löschen, Erledigte entfernen, live auf beiden Handys
- Platzhalter-Tabs für Haushalt, Kalender und Finanzen

## Firebase einrichten (einmalig)

1. Auf [console.firebase.google.com](https://console.firebase.google.com) ein Projekt anlegen, z. B. `bubududu`.
   Google Analytics kann aus bleiben.
2. **Authentication** → „Jetzt starten“ → Anbieter **E-Mail/Passwort** aktivieren.
3. **Firestore Database** → „Datenbank erstellen“ → Standort `eur3 (europe-west)` oder
   `europe-west3 (Frankfurt)` → im **Produktionsmodus** starten.
4. Unter Firestore → **Regeln** den Inhalt von [`firestore.rules`](firestore.rules) einfügen und veröffentlichen.
5. Auf dem Rechner die Werkzeuge installieren:
   - [Flutter](https://docs.flutter.dev/get-started/install)
   - [Firebase CLI](https://firebase.google.com/docs/cli): `npm install -g firebase-tools`, dann `firebase login`
   - FlutterFire CLI: `dart pub global activate flutterfire_cli`
6. Im Projektordner ausführen:

   ```sh
   flutterfire configure --project=<deine-firebase-projekt-id> --platforms=android,ios
   ```

   Das ersetzt `lib/firebase_options.dart` und legt die Konfigurationsdateien für Android und iOS an.

## App starten

```sh
flutter pub get
flutter run
```

- **Android:** Handy per USB anschließen, Entwickleroptionen und USB-Debugging aktivieren, dann `flutter run`.
  Alternativ `flutter build apk` und die Datei `build/app/outputs/flutter-apk/app-release.apk` aufs Handy schicken.
- **iPhone:** Braucht einen Mac mit Xcode. Zum Testen reicht eine kostenlose Apple-ID (App läuft dann 7 Tage),
  für dauerhafte Installation über TestFlight ein Apple-Developer-Account.

## Entwicklung

```sh
flutter analyze   # Code prüfen
flutter test      # Tests ausführen
```

Datenstruktur in Firestore:

| Pfad | Inhalt |
| --- | --- |
| `users/{uid}` | Name, `householdId` |
| `invites/{code}` | verweist auf den Haushalt |
| `households/{id}` | Name, Mitglieder, Einladungscode |
| `households/{id}/shoppingItems/{id}` | Einträge der Einkaufsliste |
