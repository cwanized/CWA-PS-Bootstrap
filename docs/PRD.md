# Product Requirements Document (PRD)

# Client Bootstrap & Configuration System

## 1. Overview

Dieses Projekt definiert ein **Git-basiertes System zur automatisierten
Einrichtung und Validierung von Windows-Clients**.

Die gesamte Konfiguration eines Clients wird über ein **privates
Git-Repository** verwaltet. Dadurch entsteht eine reproduzierbare,
versionskontrollierte und modular aufgebaute Clientkonfiguration.

Das System soll sicherstellen, dass auf einem Client:

-   definierte **Applikationen installiert**
-   notwendige **Ordnerstrukturen erstellt**
-   bestimmte **Systemanwendungen konfiguriert**
-   Entwicklerumgebungen vorbereitet
-   Konfigurationsdateien synchronisiert

werden.

Der Workflow muss sowohl für:

1.  **Neu eingerichtete Systeme**
2.  **Bereits bestehende Clients**

funktionieren.

Die Lösung arbeitet in zwei Modi:

-   **Report Mode** → zeigt Abweichungen vom gewünschten Zustand
-   **Enforce Mode** → korrigiert Abweichungen automatisch

------------------------------------------------------------------------

## 2. Goals

### Primary Goals

-   Automatisierte Einrichtung eines neuen Windows-Clients
-   Reproduzierbare Client-Konfiguration
-   Versionskontrolle aller Konfigurationen über Git
-   Flexible Definition von Clientprofilen
-   Wiederverwendbare Konfigurationen über Kategorien
-   Bevorzugte Nutzung von `winget DSC` für deklarative Paketverwaltung
-   Einrichtung eines standardisierten PowerShell-Profils
-   Einrichtung einer standardisierten Oh-My-Posh Shell-Darstellung

### Secondary Goals

-   Nachträgliche Überprüfung bestehender Systeme
-   Erweiterbarkeit für weitere Installer-Typen
-   Minimale Benutzerinteraktion beim Setup
-   Modularisierung von Konfiguration und Logik
-   Kategoriespezifische Shell-Profile für unterschiedliche Arbeitskontexte
-   Konzeptionelle Vorbereitung von `choco`, `msi` und `exe` als ergänzende Hüllen

------------------------------------------------------------------------

## 3. High Level Workflow

### 3.1 Bootstrap Installation

Der Benutzer startet das Setup mit einem einzigen Befehl:

``` powershell
irm https://example/bootstrap.ps1 | iex
```

Das Bootstrap-Skript übernimmt:

1.  Installation grundlegender Tools
2.  Authentifizierung am Git-Repository
3.  Klonen des Repositories
4.  Laden des PowerShell-Moduls
5.  Aufruf des Client-Setups
6.  Nutzung von `winget DSC` für passende Paketdefinitionen

------------------------------------------------------------------------

### 3.2 Authentifizierung

Beim Zugriff auf das Repository wird **Git Credential Manager**
verwendet.

Ablauf:

1.  `git clone` wird gestartet
2.  Git Credential Manager erkennt fehlende Credentials
3.  Ein Browser wird automatisch geöffnet
4.  Benutzer authentifiziert sich bei GitLab
5.  Token wird im Windows Credential Store gespeichert

Unterstützte Authentifizierungsarten:

-   Passwort
-   Passkey
-   MFA

------------------------------------------------------------------------

### 3.3 Client Setup Workflow

Nach dem Klonen des Repositories läuft der folgende Prozess:

1.  Hostname des Clients wird ermittelt
2.  Passendes Client-Profil wird geladen
3.  Kategorien des Clients werden ermittelt
4.  Konfigurationen der Kategorien werden zusammengeführt
5.  Installer-Quellen und Shell-Profile werden aufgelöst
6.  PowerShell-Profil und Oh-My-Posh-Konfiguration werden validiert
7.  `winget DSC`-fähige Anwendungen werden deklarativ verarbeitet
8.  ergänzende Quellen werden bei Bedarf über PowerShell-Hüllen behandelt
9.  System wird überprüft oder konfiguriert

------------------------------------------------------------------------

## 4. Operating Modes

### Report Mode

Report Mode überprüft den aktuellen Zustand des Systems.

Geprüft werden:

-   installierte Anwendungen
-   vorhandene Ordner
-   vorhandene Konfigurationsdateien
-   PowerShell-Profil
-   aktive Oh-My-Posh-Konfiguration

Beispielausgabe:

    [OK] Microsoft.VisualStudioCode
    [MISSING] Git.Git
    [OK] C:\Temp
    [MISSING] C:\Users\User\_Repos

Es werden **keine Änderungen durchgeführt**.

------------------------------------------------------------------------

### Enforce Mode

Enforce Mode stellt den gewünschten Zustand her.

Aktionen:

-   Installation fehlender Anwendungen
-   Erstellung fehlender Ordner
-   Synchronisation von Konfigurationsdateien
-   Einrichtung des PowerShell-Profils
-   Einrichtung der Oh-My-Posh-Konfiguration

Für `winget`-basierte Anwendungen soll bevorzugt `winget DSC`
verwendet werden.

Beispiel:

    Installing Git.Git
    Creating folder C:\Temp
    Applying WindowsTerminal configuration

------------------------------------------------------------------------

## 5. Repository Structure

Das gesamte System basiert auf einem Git-Repository.

    repo-root
    │
    ├─ Config
    │   ├─ Applications
    │   │   ├─ OhMyPosh
    │   │   ├─ WindowsTerminal
    │   │   ├─ PowerToys
    │   │   └─ PowerShell
    │   │
    │   ├─ Clients
    │   │   └─ <hostname>.json
    │   │
    │   └─ Categories
    │       └─ <category>.json
    │
    ├─ PSModule
    │   └─ ClientBootstrap
    │
    ├─ docs
    │   ├─ PRD.md
    │   └─ designconcept.md
    │
    └─ bootstrap.ps1

------------------------------------------------------------------------

## 6. Configuration Principles

Die Architektur trennt strikt zwischen:

### Configuration (Data)

    Config/*

Enthält ausschließlich deklarative Konfiguration.

### Logic (Code)

    PSModule/*

Enthält die Implementierung des Systems.

------------------------------------------------------------------------

## 7. Client Profiles

Jeder Client besitzt ein eigenes Profil.

Speicherort:

    Config/Clients/<hostname>.json

Der Dateiname entspricht dem Windows-Hostname.

Beispiel:

``` json
{
  "Categories": [
    "Coding",
    "Gaming"
  ],
  "OhMyPoshProfile": "coding-minimal"
}
```

Das Client-Profil ist außerdem der Ort, an dem Konflikte zwischen
mehreren aktiven Oh-My-Posh-Profilen explizit aufgelöst werden.

------------------------------------------------------------------------

## 8. Categories

Kategorien definieren wiederverwendbare Konfigurationsbausteine.

Speicherort:

    Config/Categories/<category>.json

Eine Kategorie kann definieren:

-   Anwendungen
-   Ordner
-   Konfigurationen
-   ein referenziertes Oh-My-Posh-Profil

Beispiel:

``` json
{
  "Applications": [
    {
      "Name": "Git",
      "Source": "winget",
      "Id": "Git.Git"
    },
    {
      "Name": "Visual Studio Code",
      "Source": "winget",
      "Id": "Microsoft.VisualStudioCode"
    }
  ],
  "Folders": [
    "C:\\Temp",
    "$env:USERPROFILE\\_Repos"
  ],
  "OhMyPoshProfile": "coding-minimal"
}
```

Mehrere Kategorien dürfen dasselbe Oh-My-Posh-Profil referenzieren.
Falls mehrere aktive Kategorien unterschiedliche Oh-My-Posh-Profile
definieren, entsteht ein Konflikt. Dieser Konflikt muss explizit im
Client-Profil aufgelöst werden.

------------------------------------------------------------------------

## 9. Application Installation

Applikationen werden über ein **Source-basiertes Installationsmodell**
installiert.

Für die erste Version ist `winget DSC` der bevorzugte Mechanismus zur
deklarativen Installation und Durchsetzung von `winget`-Paketen.

`choco`, `msi` und `exe` werden für v1 konzeptionell mitgedacht und über
gemeinsame PowerShell-Hüllen vorbereitet, aber nicht vollständig
ausimplementiert.

Unterstützte Sources:

-   winget
-   choco
-   msi
-   exe

### Source Priority

Wenn dieselbe logische Applikation über mehrere Quellen definiert ist,
gilt verbindlich folgende Prioritätsreihenfolge:

1.  winget
2.  choco
3.  msi
4.  exe

Das System verwendet die höchste verfügbare priorisierte Quelle als
wirksame Installationsdefinition.

Wenn für eine Applikation eine `winget`-Definition vorhanden ist, soll in
v1 nach Möglichkeit `winget DSC` als bevorzugter Umsetzungsweg genutzt
werden.

Beispiel:

``` json
{
  "Applications": [
    {
      "Name": "Git",
      "Source": "winget",
      "Id": "Git.Git"
    },
    {
      "Name": "Steam",
      "Source": "choco",
      "Id": "steam"
    },
    {
      "Name": "CustomTool",
      "Source": "msi",
      "Url": "https://example.com/tool.msi",
      "SilentArgs": "/qn"
    },
    {
      "Name": "LegacyApp",
      "Source": "exe",
      "Path": "\\\\server\\share\\installer.exe",
      "SilentArgs": "/S"
    }
  ]
}
```

Wenn `Git` beispielsweise sowohl über `winget` als auch über `choco`
definiert ist, wird `winget` verwendet.

------------------------------------------------------------------------

## 10. Folder Management

Ordner werden deklarativ definiert.

``` json
{
  "Folders": [
    "C:\\Temp",
    "$env:USERPROFILE\\_Repos"
  ]
}
```

Fehlende Ordner werden im Enforce Mode automatisch erstellt.

------------------------------------------------------------------------

## 11. Application Configuration

Konfigurationen befinden sich unter:

    Config/Applications/

Beispiel:

    Config/Applications
    │
    ├─ OhMyPosh
    │   └─ coding-minimal.omp.json
    │
    ├─ WindowsTerminal
    │   └─ settings.json
    │
    ├─ PowerToys
    │   └─ configuration files
    │
    └─ PowerShell
        └─ profile.ps1

Diese Konfigurationen werden während des Setup-Prozesses angewendet.

  Ein zentraler Bestandteil von v1 ist die Einrichtung eines konsistenten
  PowerShell-Profils inklusive Oh-My-Posh-Initialisierung.

  Kategorien dürfen unterschiedliche Oh-My-Posh-Profile referenzieren.
  Die finale Auswahl muss jedoch eindeutig sein. Ist sie es nicht, wird
  der Konflikt im Client-Profil aufgelöst.

------------------------------------------------------------------------

## 12. Technologies

  Technologie              Zweck
  ------------------------ ------------------------------
  PowerShell 7             Orchestrierung
  WinGet DSC               Deklarative Paketinstallation für Winget-Pakete
  Oh My Posh               Shell-Prompt und Profil-Darstellung
  Git                      Versionskontrolle
  GitLab                   Repository Hosting
  Git Credential Manager   Authentifizierung
  Winget                   Paketinstallation
  Chocolatey               Erweiterte Paketinstallation
  MSI / EXE                Legacy Installer

------------------------------------------------------------------------

## 13. Logging

Alle Aktionen werden protokolliert.

    Logs/
       2026-03-08-bootstrap.log

Das Logging enthält:

-   installierte Anwendungen
-   gewählte Installationsquelle je Anwendung
-   erkannte Abweichungen
-   erkannte Shell-Profil-Konflikte
-   ausgeführte Aktionen
-   Fehler

------------------------------------------------------------------------

## 14. Future Extensions

Geplante Erweiterungen:

### Configuration Validation

-   JSON Schema Validation
-   Pre-Commit Hooks

### Reporting

Exportmöglichkeiten:

-   JSON
-   Markdown
-   HTML

### GUI

Ein einfacher Client für:

-   Report Mode
-   Enforce Mode

### OneDrive Integration

Synchronisation von:

-   Konfigurationsdateien
-   Logs
-   lokalen Anpassungen

------------------------------------------------------------------------

## 15. Out of Scope (First Release)

Folgende Funktionen sind **nicht Teil der ersten Version**:

-   Rollback von Installationen
-   Komplexe Dependency Resolution
-   Automatisches Entfernen von Anwendungen
-   GUI-basierte Verwaltung
-   Vollständige Ausimplementierung aller `choco`, `msi` und `exe`-Sonderfälle

------------------------------------------------------------------------

## 16. Design Principles

### Declarative Configuration

Der gewünschte Zustand wird beschrieben, nicht die Schritte zur
Umsetzung.

### Idempotency

Der Setup-Prozess kann beliebig oft ausgeführt werden.

### Modularity

Konfigurationen werden über Kategorien wiederverwendet.

### Deterministic Resolution

Mehrfachdefinitionen werden nach klaren Regeln aufgelöst. Für
Applikationen gilt die Priorität `winget > choco > msi > exe`.

### Prefer Native Declarative Mechanisms

Wenn möglich, sollen native deklarative Mechanismen bevorzugt werden. Für
`winget`-basierte Anwendungen ist dies `winget DSC`.

### Extensibility

Neue Installer-Typen können einfach hinzugefügt werden.

------------------------------------------------------------------------

## 17. Success Criteria

Das System gilt als erfolgreich implementiert wenn:

-   ein neuer Client mit **einem Befehl** eingerichtet werden kann
-   Konfigurationen vollständig über Git verwaltet werden
-   Clients reproduzierbar eingerichtet werden können
-   Report Mode zuverlässig Abweichungen erkennt
-   neue Kategorien einfach hinzugefügt werden können
-   PowerShell-Profil und Oh-My-Posh korrekt eingerichtet werden
-   die priorisierte Quellenwahl bei Mehrfachdefinitionen nachvollziehbar funktioniert
-   `winget`-Anwendungen deklarativ über `winget DSC` verarbeitet werden können
