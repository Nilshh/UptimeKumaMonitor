# UptimeKumaMonitor

UptimeKumaMonitor ist eine native iOS App in SwiftUI, mit der du deinen selbst gehosteten Uptime Kuma Server von iPhone oder iPad aus überwachen kannst.[web:50][web:52]

## Features

- Anzeige der Monitore aus deinem Uptime Kuma Backend (Status, Uptime, letzter Check).[web:50]
- Detailansicht pro Monitor mit weiteren Informationen.
- Manuelle Aktualisierung der Daten via Pull-to-Refresh.
- Einfache Konfiguration der Server-URL und Zugangsdaten in den Settings.
- Lokale Speicherung der Einstellungen (UserDefaults).

## Voraussetzungen

- iOS 17 oder neuer (Ziel: iPhone / iPad).
- Xcode 16 oder neuer.
- Laufender Uptime Kuma Server (z. B. via Docker auf Port 3001).[web:50]
- Optional: HTTPS empfohlen für produktiven Einsatz (ansonsten ATS-Anpassungen in `Info.plist` nötig).[web:41][web:42]

## Installation & Setup

1. Repository clonen:
   ```bash
   git clone https://github.com/<DEIN-USER>/UptimeKumaMonitor.git
   cd UptimeKumaMonitor
   ```
2. Projekt in Xcode öffnen:
   ```bash
   open UptimeKumaMonitor.xcodeproj
   ```
3. Zielgerät/Simulator auswählen und Build & Run:
   - `Product → Run` oder `⌘R`.

4. In der App:
   - Über das Settings-Icon die Uptime Kuma URL setzen, z. B.:
     - `http://localhost:3001`
     - oder `http://<deine-ip>:3001`
   - Benutzername und Passwort deines Uptime Kuma Accounts eingeben.
   - „Connect“ tippen, um Monitore zu laden.

## App Transport Security (ATS)

Wenn dein Uptime Kuma nur per HTTP (ohne TLS) erreichbar ist, blockiert iOS die Verbindung standardmäßig (Fehler `NSURLErrorDomain Code=-1022`).[web:42][web:41]

Für Entwicklung kannst du in `Info.plist` folgenden Block ergänzen:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

Für produktiven Einsatz sollte dein Uptime Kuma Server über HTTPS erreichbar sein.[web:41][web:40]

## Architektur

- **UI**: SwiftUI Views (`ContentView`, `MonitorCard`, `MonitorDetailView`, `SettingsView`).
- **Networking**: `UptimeKumaAPI` (URLSession, JSON Decoding).
- **Modelle**:
  - `Monitor`: Repräsentiert einen Uptime Kuma Monitor.
  - `StatusPage` (optional, je nach Ausbaustufe).
  - `UptimeResponse`: generische API-Antworten.

## Lizenz
