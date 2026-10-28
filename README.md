# Bubu & Dudu

Die App für unseren gemeinsamen Alltag: Einkauf, Haushalt, Kalender, Finanzen und mehr.
Gebaut mit Flutter (eine Codebasis für Android, Web und später iPhone) und Firebase (Login, Datenbank, Live-Sync).

Das Konzept mit allen geplanten Bereichen und dem MVP liegt im Projekt als Dokument
„Bubu-Dudu-App – Konzept“.

## Was die App kann

| Bereich | Funktionen |
| --- | --- |
| Start | Wetter für euren Ort oder automatisch per Standort, mit Detailansicht (Stunden, 7 Tage, Wind, UV), Aktien/ETFs, fällige Aufgaben, nächste Termine, Einkaufsliste, Essen heute, Finanzen, Erinnerungen, Jahrestag |
| Einkauf | Gemeinsame Liste, live auf beiden Handys |
| Haushalt | Aufgaben mit Zuständigkeit, Fälligkeit, Wiederholung und Punkten pro Monat |
| Kalender | Monatsansicht, Termine mit Uhrzeit, Geburtstage und Jahrestage jährlich |
| Finanzen | Ausgaben, Wer-schuldet-wem, Ausgleichen, Kategorien pro Monat, Fixkosten |
| Rezepte | Rezeptsammlung, Zutaten auf die Einkaufsliste |
| Essensplan | Wochenplan, Rezepte mit einem Tipp übernehmen |
| Notizen | Pinnwand mit Kategorien (WLAN, Kontakte, Geschenkideen …) |
| Vorräte | Bestand und Mindesthaltbarkeit, fehlende Vorräte auf die Einkaufsliste |
| Verträge | Kosten, Zahlungsrhythmus, Kündigungsfristen mit Hinweis |
| Reisen | Reisen mit gemeinsamer Packliste |
| Gesundheit | Arzttermine, Impfungen und Vorsorge pro Person, Empfehlungen nach Alter, private Einträge |
| Tiere & Pflanzen | Gießen, Füttern, Tierarzt im festen Rhythmus |
| Wir | Zusammen seit, Date-Ideen, Bucket-Liste, Ziele, Standort teilen (Karte oder Satellit), Einladungscode |

Standort teilen ist freiwillig: Jede Person schaltet es für sich ein, solange es läuft,
zeigt die App einen Hinweis-Balken. Geteilt wird nur, während die App geöffnet ist.

**Bubu & Dudu als Figuren:** Dudu (brauner Bär) und Bubu (weißer Panda mit grünem Halstuch)
sind selbst gezeichnet (`lib/widgets/mascots.dart`) und tauchen überall in der App auf, je nach
Bereich in anderer Stimmung: hungrig bei Rezepten, mit Tüte beim Einkauf, verschlafen morgens
auf der Startseite. Das App-Logo wird aus derselben Zeichnung erzeugt:

```sh
OUT=assets/logo flutter test tool/render_mascots_test.dart
dart run flutter_launcher_icons
```

**Offline:** Die App funktioniert auch ohne Netz, z. B. im Supermarkt-Keller. Alles wird auf dem
Handy zwischengespeichert, oben erscheint „Offline“, und sobald wieder Netz da ist, gleicht
die App automatisch ab. Noch nicht abgeglichene Einträge der Einkaufsliste sind markiert.

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

## Benachrichtigungen

- **Erinnerungen** (Termine, Aufgaben, Kündigungsfristen, Gießen, Arzttermine) plant das Handy
  selbst, auch ohne Netz. Funktioniert sofort, nichts einzurichten.
- **Neues vom Partner** („Bubu hat Milch auf die Einkaufsliste gesetzt“) kommt als Push vom Server
  (`functions/`). Das braucht einmalig:
  1. Firebase-Konsole → unten links **Upgrade** → Tarif **Blaze**. Für zwei Personen bleibt das im
     kostenlosen Kontingent; am besten gleich ein Budget-Limit von 1 € als Warnung setzen.
  2. [Google Cloud → Dienstkonten](https://console.cloud.google.com/iam-admin/serviceaccounts?project=bubududu-15f3f)
     → **Dienstkonto erstellen**, Name `github-deploy`, Rolle **Bearbeiter** (Editor) → Fertig.
     Dann das Konto anklicken → **Schlüssel** → **Schlüssel hinzufügen** → JSON. Die Datei wird heruntergeladen.
  3. GitHub → Repo → **Settings → Secrets and variables → Actions → New repository secret**,
     Name `FIREBASE_SERVICE_ACCOUNT`, Inhalt der JSON-Datei einfügen. Datei danach löschen.

  Ab dann veröffentlicht GitHub nach jeder Änderung die Push-Funktion und die Firestore-Regeln
  automatisch. Die Web-App wird nur veröffentlicht, wenn zusätzlich die Variable `PUBLISH_WEB=true` gesetzt ist.

Jede Person kann beides unter **Mehr → Einstellungen** abschalten.

## Google-Kalender

Unter **Mehr → Einstellungen → Kalender** „Termine in meinen Google-Kalender“ einschalten und den
Google-Kalender auswählen. Ab dann landen alle gemeinsamen und eigenen Termine automatisch dort
(über den Kalender des Handys, der sich selbst mit Google abgleicht, kein extra Login nötig).
Ändert oder löscht man einen Termin in der App, passiert das auch im Google-Kalender.
Umgekehrt holt man Termine aus Google gezielt über den Knopf oben im Kalender-Reiter.
Jede Person schaltet das auf ihrem eigenen Handy ein (nur Android-App).

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

Die Tests decken jeden Bereich ab: Logik (`test/logic_test.dart`), Anmelden und Haushalt
(`test/auth_test.dart`), Anlegen/Ändern/Löschen pro Bereich (`test/areas_test.dart`),
alle Seiten (`test/screens_test.dart`) und Offline (`test/offline_test.dart`).
Gemeinsame Testdaten liegen in `test/helpers.dart`.

Die Firestore-Regeln werden im Emulator geprüft (braucht Node und Java):

```sh
cd test_rules && npm install && npm test
```

Datenstruktur in Firestore:

| Pfad | Inhalt |
| --- | --- |
| `users/{uid}` | Name, `householdId`, `notify` (Einstellungen), `fcmTokens` (Geräte für Push) |
| `invites/{code}` | verweist auf den Haushalt |
| `households/{id}` | Name, Mitglieder, Einladungscode |
| `households/{id}/shoppingItems/{id}` | Einträge der Einkaufsliste |
| `households/{id}/recipes`, `mealPlan/{yyyy-mm-dd}` | Rezepte, Essensplan |
| `households/{id}/tasks`, `taskLog` | Aufgaben und wer was erledigt hat |
| `households/{id}/events` | Termine |
| `households/{id}/expenses`, `contracts` | Ausgaben, Verträge |
| `households/{id}/notes`, `pantry`, `trips`, `care`, `ideas` | weitere Bereiche |
| `households/{id}/locations/{uid}` | geteilter Standort (nur von der Person selbst schreibbar) |
| `households/{id}/health`, `healthProfiles` im Haushalt | gemeinsame Gesundheitseinträge, Geburtsdatum |
| `users/{uid}/health` | private Gesundheitseinträge (nur die Person selbst) |
