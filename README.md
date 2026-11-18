# Alltag

Jakobs persönliche iPhone-App: diktieren statt organisieren. Apple Intelligence sortiert jedes Diktat kostenlos und offline in Aufgaben, Termine und Projekt-Ideen.

## Was Version 1 kann
- **Heute:** ein nächster Schritt, Termine von heute, höchstens drei Aufgaben.
- **Kalender:** eigene Ansicht, synchron mit dem iPhone-Kalender (iCloud).
- **Projekte:** Arbeit und Privat, Ideenlisten, Ideen-Parkplatz.
- **Eingang:** alles, was diktiert wurde, durchsuchbar.
- **Assistent:** Mikrofon-Knopf, Aktionstaste („Diktieren“) und Siri („Hey Siri, Alltag merken“).

## Technik
SwiftUI, SwiftData, EventKit, Speech, App Intents, iOS 26. Das Xcode-Projekt wird mit XcodeGen aus `project.yml` erzeugt. GitHub Actions baut bei jedem Push (`.github/workflows/build.yml`), ein Mac ist nicht nötig.

Kein API-Schlüssel nötig: Spracherkennung und Sortieren laufen auf dem iPhone (Apple Intelligence muss eingeschaltet sein).

## Als Nächstes
Abend-Check (Standort, Fahrzeit, Wecker), Teilen aus WhatsApp, Geburtstage, Countdown bis Losgehen, TestFlight.
