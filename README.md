# Bubu & Dudu

Die App für unseren gemeinsamen Alltag: Einkauf, Haushalt, Kalender, Finanzen und mehr.
Gebaut mit Flutter (eine Codebasis für Android, Web und später iPhone) und Firebase (Login, Datenbank, Live-Sync).

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
   flutterfire configure --project=<deine-firebase-projekt-id> --platforms=android,web
   ```

   Das ersetzt `lib/firebase_options.dart` und legt die Konfiguration für Android und Web an.
   Wenn später die echte iPhone-App dazukommt, einfach mit `--platforms=android,web,ios` wiederholen.

## App starten

```sh
flutter pub get
flutter run
```

- **Android:** Auf dem Handy diesen Link öffnen und die Datei installieren (Installation aus dieser Quelle erlauben):
  [bubududu.apk](https://github.com/TEE800/bubududu/releases/latest/download/bubududu.apk).
  GitHub baut die neueste Version automatisch nach jeder Änderung auf `main`.
- **iPhone (Web-App):** Die App läuft im Safari und wird von dort auf den Homescreen gelegt.
  Einmalig veröffentlichen (kostenlos über Firebase Hosting):

  ```sh
  flutter build web
  firebase deploy --only hosting
  ```

  Danach die angezeigte Adresse (`https://<projekt-id>.web.app`) auf dem iPhone in Safari öffnen,
  auf „Teilen“ tippen und „Zum Home-Bildschirm“ wählen. Nach jeder Änderung die zwei Befehle wiederholen.
- **Echte iPhone-App (später):** Ohne Mac geht das über einen Cloud-Build wie Codemagic und TestFlight.
  Dafür braucht es einen Apple-Developer-Account (ca. 99 USD pro Jahr).

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
