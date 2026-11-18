# Alltag

Jakobs persönliche iPhone-App: diktieren statt organisieren. Claude sortiert jedes Diktat in Aufgaben, Termine, Antwort-Entwürfe und Projekt-Ideen. Gesendet wird nur nach einem Tipp.

## Was Version 1 kann
- **Heute:** ein nächster Schritt, Termine von heute, höchstens drei Aufgaben.
- **Kalender:** eigene Ansicht, synchron mit dem iPhone-Kalender (iCloud).
- **Antworten:** offene WhatsApp-/Mail-Antworten mit fertigem Entwurf, Senden mit einem Tipp.
- **Projekte:** Arbeit und Privat, Ideenlisten, Ideen-Parkplatz.
- **Eingang:** alles, was diktiert wurde, durchsuchbar.
- **Assistent:** Mikrofon-Knopf, Aktionstaste („Diktieren“) und Siri („Hey Siri, Alltag merken“).

## Technik
SwiftUI, SwiftData, EventKit, Speech, App Intents, iOS 26. Das Xcode-Projekt wird mit XcodeGen aus `project.yml` erzeugt. GitHub Actions baut bei jedem Push (`.github/workflows/build.yml`), ein Mac ist nicht nötig.

Der Claude-Schlüssel wird in der App unter Einstellungen eingetragen und im Schlüsselbund gespeichert.

## Als Nächstes
Abend-Check (Standort, Fahrzeit, Wecker), Teilen aus WhatsApp, Geburtstage, Countdown bis Losgehen, TestFlight.
