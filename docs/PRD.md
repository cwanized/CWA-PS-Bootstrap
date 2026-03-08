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
-   Automatische Installation der für den Bootstrap benötigten PowerShell-Module

### Secondary Goals

-   Nachträgliche Überprüfung bestehender Systeme
-   Erweiterbarkeit für weitere Installer-Typen
-   Minimale Benutzerinteraktion beim Setup
-   Modularisierung von Konfiguration und Logik
-   Kategoriespezifische Shell-Profile für unterschiedliche Arbeitskontexte
-   Konzeptionelle Vorbereitung von `choco`, `msi` und `exe` als ergänzende Hüllen
-   Optionale Installation zusätzlicher PowerShell-Module über Kategorien
-   Deklarative Verwaltung vertrauenswürdiger PowerShell-Repositories

------------------------------------------------------------------------

## 3. High Level Workflow

### 3.1 Bootstrap Installation

Der Benutzer startet das Setup mit einem einzigen Befehl:

``` powershell
irm https://raw.githubusercontent.com/cwanized/CWA-PS-Bootstrap/master/bootstrap.ps1 | iex
```

Der Einzeiler lädt einen kleinen Bootstrap-Loader. Dieser Loader prüft
die Grundvoraussetzungen, klont anschließend das Repository lokal und
startet danach den eigentlichen Bootstrap aus dem Checkout.

Das Bootstrap-Skript übernimmt:

1.  Laden eines kleinen Bootstrap-Loaders
2.  Prüfung grundlegender Tools
3.  Authentifizierung am Git-Repository
4.  Klonen oder Aktualisieren des Repositories
5.  Installation der für den Bootstrap benötigten PowerShell-Module
6.  Laden des PowerShell-Moduls
7.  Aufruf des Client-Setups
8.  Nutzung von `winget DSC` für passende Paketdefinitionen

------------------------------------------------------------------------

### 3.2 Authentifizierung

Beim Zugriff auf das Repository wird **Git Credential Manager**
verwendet.

Ablauf:

1.  `git clone` wird gestartet
2.  Git Credential Manager erkennt fehlende Credentials
3.  Ein Browser wird automatisch geöffnet
4.  Benutzer authentifiziert sich bei GitHub
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
5.  PowerShell-Repositories und optionale PowerShell-Module werden aufgelöst
6.  Installer-Quellen und Shell-Profile werden aufgelöst
7.  PowerShell-Profil und Oh-My-Posh-Konfiguration werden validiert
8.  `winget DSC`-fähige Anwendungen werden deklarativ verarbeitet
9.  PowerShell-Repositories werden als `Trusted` konfiguriert und optionale Module installiert
10. ergänzende Quellen werden bei Bedarf über PowerShell-Hüllen behandelt
11. System wird überprüft oder konfiguriert

------------------------------------------------------------------------

## 4. Operating Modes

### Report Mode

Report Mode überprüft den aktuellen Zustand des Systems.

Geprüft werden:

-   installierte Anwendungen
-   konfigurierte PowerShell-Repositories
-   installierte PowerShell-Module
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
-   Installation fehlender Bootstrap-PowerShell-Module
-   Konfiguration deklarierter PowerShell-Repositories als `Trusted`
-   Installation optionaler PowerShell-Module aus Kategorien
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
    │   │   ├─ PowerShellModules
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
-   PowerShell-Repositories
-   optionale PowerShell-Module
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
  "PowerShellRepositories": [
    {
      "Name": "PSGallery",
      "InstallationPolicy": "Trusted"
    }
  ],
  "PowerShellModules": [
    {
      "Name": "posh-git",
      "Repository": "PSGallery"
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

PowerShell-Repositories dürfen in Kategorien definiert werden und werden
auf dem Client als `Trusted` konfiguriert. Darüber hinaus können
Kategorien optionale PowerShell-Module definieren, die nach Abschluss
des Bootstrap-Grundaufbaus installiert werden.

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

## 10. PowerShell Module and Repository Management

Für den Bootstrap benötigte PowerShell-Module werden auf dem Client immer
zuerst installiert, bevor die eigentliche Client-Konfiguration ausgeführt
wird.

Zusätzlich können Kategorien optionale PowerShell-Module und
PowerShell-Repositories definieren.

Regeln:

-   Bootstrap-PowerShell-Module sind verpflichtender Bestandteil des
    Grundablaufs
-   Kategorie-Module sind optional und werden nach der Grundinitialisierung
    installiert
-   deklarierte PowerShell-Repositories werden auf dem Client als
    `Trusted` konfiguriert
-   PowerShell-Module können optional einem bestimmten Repository
    zugeordnet werden

Beispiel:

``` json
{
  "PowerShellRepositories": [
    {
      "Name": "PSGallery",
      "InstallationPolicy": "Trusted"
    }
  ],
  "PowerShellModules": [
    {
      "Name": "posh-git",
      "Repository": "PSGallery"
    },
    {
      "Name": "Terminal-Icons",
      "Repository": "PSGallery"
    }
  ]
}
```

------------------------------------------------------------------------

## 11. Folder Management

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

## 12. Application Configuration

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

## 13. Technologies

  Technologie              Zweck
  ------------------------ ------------------------------
  PowerShell 7             Orchestrierung
  PowerShellGet / PSResourceGet Verwaltung von Modulen und Repositories
  WinGet DSC               Deklarative Paketinstallation für Winget-Pakete
  Oh My Posh               Shell-Prompt und Profil-Darstellung
  Git                      Versionskontrolle
  GitHub                   Repository Hosting
  Git Credential Manager   Authentifizierung
  Winget                   Paketinstallation
  Chocolatey               Erweiterte Paketinstallation
  MSI / EXE                Legacy Installer

------------------------------------------------------------------------

## 14. Logging

Alle Aktionen werden protokolliert.

    Logs/
       2026-03-08-bootstrap.log

Das Logging enthält:

-   installierte Anwendungen
-   gewählte Installationsquelle je Anwendung
-   konfigurierte PowerShell-Repositories
-   installierte PowerShell-Module
-   erkannte Abweichungen
-   erkannte Shell-Profil-Konflikte
-   ausgeführte Aktionen
-   Fehler

------------------------------------------------------------------------

## 15. Future Extensions

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

## 16. Out of Scope (First Release)

Folgende Funktionen sind **nicht Teil der ersten Version**:

-   Rollback von Installationen
-   Komplexe Dependency Resolution
-   Automatisches Entfernen von Anwendungen
-   GUI-basierte Verwaltung
-   Vollständige Ausimplementierung aller `choco`, `msi` und `exe`-Sonderfälle

------------------------------------------------------------------------

## 17. Design Principles

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

### Bootstrap First

Die für den Bootstrap notwendigen PowerShell-Module werden immer zuerst
installiert, damit der restliche Workflow auf einem definierten Fundament
läuft.

### Extensibility

Neue Installer-Typen können einfach hinzugefügt werden.

------------------------------------------------------------------------

## 18. Success Criteria

Das System gilt als erfolgreich implementiert wenn:

-   ein neuer Client mit **einem Befehl** eingerichtet werden kann
-   Konfigurationen vollständig über Git verwaltet werden
-   Clients reproduzierbar eingerichtet werden können
-   Report Mode zuverlässig Abweichungen erkennt
-   neue Kategorien einfach hinzugefügt werden können
-   PowerShell-Profil und Oh-My-Posh korrekt eingerichtet werden
-   die priorisierte Quellenwahl bei Mehrfachdefinitionen nachvollziehbar funktioniert
-   `winget`-Anwendungen deklarativ über `winget DSC` verarbeitet werden können
-   deklarierte PowerShell-Repositories als `Trusted` konfiguriert werden können
-   optionale PowerShell-Module aus Kategorien reproduzierbar installiert werden können
