# Design Concept

## 1. Ziel des Dokuments

Dieses Dokument übersetzt das PRD in ein technisch belastbares Zielbild für die erste Version des **Client Bootstrap & Configuration System**.

Fokus von v1:

- Developer-Workstations unter Windows
- Unterstützung für Windows Sandbox als Debug-/Test-Umgebung
- deklarative Konfiguration über Git
- zwei Betriebsmodi: `Report` und `Enforce`
- standardisiertes PowerShell-Profil
- standardisierte Oh-My-Posh-Konfiguration
- Bootstrap-PowerShell-Module als verpflichtende Grundlage

Dieses Dokument beschreibt bewusst **Architektur, Regeln und Grenzen** und noch keine vollständige Implementierung.

---

## 2. Machbarkeit

Die im PRD beschriebene Lösung ist für Windows grundsätzlich **machbar**.

Warum sie machbar ist:

- `PowerShell 7` eignet sich gut als Orchestrierungsschicht.
- `winget DSC` nimmt für `winget`-basierte Anwendungen einen großen Teil von Sollzustand, Idempotenz und Enforcement ab.
- Git-basierte Konfiguration ist nachvollziehbar und versionierbar.
- `winget` und `choco` decken viele typische Developer-Tools ab.
- Der Ansatz mit Kategorien und Client-Profilen ist modular und erweiterbar.
- `Report` und `Enforce` passen gut zu Erstinstallation und Drift-Erkennung.

Aktuelle Einschränkung:

- Im Repository existiert bislang nur das PRD. Die eigentliche technische Struktur ist noch nicht vorhanden.
- Die Machbarkeit ist daher fachlich gut, aber operativ noch nicht durch Prototypen abgesichert.

---

## 3. Ziele für v1

### In Scope

- Bootstrap eines Windows-Clients mit einem Einstiegspunkt
- Laden eines Zielprofils
- Auflösen von Kategorien
- Installation definierter Anwendungen
- bevorzugte Nutzung von `winget DSC` für `winget`-basierte Anwendungen
- Installation benötigter Bootstrap-PowerShell-Module
- Konfiguration deklarierter PowerShell-Repositories als `Trusted`
- Installation optionaler PowerShell-Module aus Kategorien
- Erstellen definierter Ordner
- Anwenden ausgewählter Konfigurationsdateien
- Einrichtung des PowerShell-Profils
- Einrichtung und Validierung von Oh My Posh
- `Report Mode` zur Abweichungserkennung
- `Enforce Mode` zur Herstellung des Soll-Zustands
- Logging mit klaren Status- und Fehlerausgaben
- einfache Sandbox-/Debug-Variante
- konzeptionelle Hüllen für `choco`, `msi` und `exe`

### Out of Scope für v1

- Rollback von Installationen
- komplexe Dependency-Resolution
- automatische Deinstallation nicht gewünschter Software
- GUI
- bidirektionale Synchronisation von Benutzerkonfigurationen
- vollständige Ausimplementierung aller Sonderfälle für `choco`, `msi` und `exe`

---

## 4. Leitprinzipien

### Declarative first

Konfiguration beschreibt den gewünschten Zustand. Logik interpretiert diese Daten.

### Bootstrap foundation first

Bootstrap-abhängige PowerShell-Module werden immer vor der eigentlichen Client-Konfiguration installiert.

### Idempotent execution

Ein mehrfaches Ausführen desselben Setups darf keine unerwarteten Nebeneffekte erzeugen.

### Fail fast bei Konflikten

Widersprüchliche Konfigurationen werden in v1 nicht still aufgelöst, sondern früh erkannt und mit verständlicher Fehlermeldung abgebrochen.

Ausnahme: Mehrfachdefinitionen derselben logischen Applikation über unterschiedliche Quellen werden zunächst deterministisch nach Source-Priorität aufgelöst.

### Additive Kategorien

Kategorien werden primär additiv kombiniert. Wo echte Konflikte möglich sind, gelten explizite Regeln.

### Deterministische Quellenwahl

Falls dieselbe logische Applikation mehrfach definiert ist, gilt verbindlich die Priorität `winget > choco > msi > exe`.

### Sandbox as first-class debug target

Windows Sandbox wird nicht nur als Sonderfall betrachtet, sondern als bewusst unterstützte Testumgebung.

---

## 5. Zielarchitektur

### 5.1 Repository-Struktur

Folgende Struktur wird für v1 vorgeschlagen:

```text
repo-root
│
├─ Config
│   ├─ Applications
│   │   ├─ OhMyPosh
│   │   │   └─ Profiles
│   │   ├─ PowerShellModules
│   │   ├─ WindowsTerminal
│   │   ├─ PowerShell
│   │   │   ├─ Fragments
│   │   │   └─ profile.ps1
│   │   └─ Git
│   │
│   ├─ Clients
│   │   ├─ <hostname>.json
│   │   ├─ developer-default.json
│   │   └─ sandbox-debug.json
│   │
│   └─ Categories
│       ├─ core-dev.json
│       ├─ terminal.json
│       ├─ git.json
│       └─ sandbox-base.json
│
├─ PSModule
│   └─ ClientBootstrap
│       ├─ Public
│       ├─ Private
│       └─ ClientBootstrap.psm1
│
├─ Logs
│
├─ docs
│   ├─ PRD.md
│   └─ designconcept.md
│
├─ install.ps1
│
└─ bootstrap.ps1
```

### 5.2 Schichtenmodell

#### Bootstrap Layer

`install.ps1` übernimmt:

- fehlende Basistools wie `git` und `pwsh` bei Bedarf automatisch installieren
- Repository beschaffen oder aktualisieren
- bei Bedarf GitHub-Authentifizierung indirekt über `git clone` oder `git pull` auslösen
- an `bootstrap.ps1` im lokalen Checkout übergeben

`bootstrap.ps1` übernimmt:

- Vorbedingungen prüfen
- Bootstrap-PowerShell-Module sicherstellen
- Modul laden
- Zielmodus und Profil bestimmen
- Setup auslösen

Der primäre Einstieg in v1 ist ein öffentlicher Raw-Download von
`install.ps1`, der danach lokal in den regulären Git-basierten Workflow
übergeht.

#### Orchestration Layer

Das PowerShell-Modul enthält:

- Laden und Validieren von Konfigurationen
- Merge von Profilen und Kategorien
- Übergabe `winget`-fähiger Definitionen an `winget DSC`
- Hüllen für ergänzende Installer-Typen
- Ausführung von `Report` und `Enforce`
- Logging
- Fehlerbehandlung

#### Package Enforcement Layer

Die Paketverarbeitung wird in v1 zweigeteilt:

- `winget DSC` als bevorzugter deklarativer Enforcement-Pfad für `winget`
- PowerShell-Hüllen für `choco`, `msi` und `exe`, zunächst mit Fokus auf gemeinsame Verträge statt vollständiger Ausimplementierung

#### PowerShell Ecosystem Layer

PowerShell-Repositories und PowerShell-Module bilden eine eigene Konfigurationsdomäne:

- verpflichtende Bootstrap-Module für den Grundablauf
- optionale PowerShell-Module aus Kategorien
- deklarative Repository-Definitionen mit `Trusted`-Policy

#### Configuration Layer

`Config/*` enthält ausschließlich deklarative Daten.

---

## 6. Ausführungsmodell

### 6.1 Bootstrap-Ablauf

Vorgeschlagener logischer Ablauf:

1. PowerShell-Version prüfen
2. Install-Loader starten
3. fehlende Basistools wie `git` und `pwsh` automatisch installieren
4. Zielrepository klonen oder aktualisieren
5. GitHub-Authentifizierung bei Bedarf über Git Credential Manager durchführen
6. lokalen Repo-Bootstrap starten
7. benötigte Basiswerkzeuge prüfen
8. Bootstrap-PowerShell-Module installieren
9. Modul laden
10. Profil bestimmen
11. Kategorien auflösen
12. PowerShell-Repositories und optionale PowerShell-Module auflösen
13. Installer-Quellen und Shell-Konfiguration auflösen
14. `winget`-Definitionen an `winget DSC` übergeben
15. ergänzende Quellen über Hüllen vorbereiten oder ausführen
16. Konfiguration validieren
17. Sollzustand berechnen
18. `Report` oder `Enforce` ausführen
19. Ergebnis loggen und Exitcode setzen

### 6.2 Betriebsmodi

#### Report Mode

- führt keine Änderungen durch
- prüft Anwendungen, Ordner und Konfigurationen
- prüft PowerShell-Repositories und optionale PowerShell-Module
- prüft PowerShell-Profil und Oh-My-Posh-Auswahl
- meldet `OK`, `MISSING`, `CONFLICT`, `ERROR`

#### Enforce Mode

- installiert fehlende Anwendungen
- registriert deklarierte PowerShell-Repositories als `Trusted`
- installiert optionale PowerShell-Module
- erstellt fehlende Ordner
- kopiert oder aktualisiert definierte Konfigurationsartefakte
- erzeugt oder aktualisiert das wirksame PowerShell-Profil
- richtet das wirksame Oh-My-Posh-Profil ein
- dokumentiert jede Aktion im Log

---

## 7. Profilauflösung

Die reine Hostname-Auflösung aus dem PRD reicht für v1 nicht aus, insbesondere nicht für Windows Sandbox.

### 7.1 Auflösungsreihenfolge

Für v1 wird folgende Priorität vorgeschlagen:

1. explizit übergebener Profilname, z. B. `-Profile sandbox-debug`
2. explizit übergebene Umgebung, z. B. `-Environment sandbox`
3. Hostname-basierte Datei unter `Config/Clients/<hostname>.json`
4. Fallback-Profil `developer-default.json`

### 7.2 Begründung

Das löst mehrere praktische Probleme:

- Sandbox-Hostnamen sind nicht stabil genug als alleiniger Selektor.
- Debug-Szenarien benötigen reproduzierbare Minimalprofile.
- Neue Workstations können ohne individuelle Datei zunächst auf ein Standardprofil fallen.

---

## 8. Kategorien und Merge-Regeln

### 8.1 Grundregel

Kategorien werden additiv zusammengeführt.

### 8.2 Anwendungen

Anwendungen werden über einen logischen Schlüssel identifiziert.

Empfohlener Schlüssel in v1:

- `Name` als kanonischer fachlicher Schlüssel
- ergänzend source-spezifische Felder wie `Id`, `Url` oder `Path`

Regeln:

- unterschiedliche Anwendungen werden additiv übernommen
- identische Anwendungen aus derselben Quelle werden dedupliziert
- identische Anwendungen aus mehreren Quellen werden nach Priorität aufgelöst
- nur nicht auflösbare oder widersprüchliche wirksame Definitionen erzeugen `CONFLICT`

Umsetzungsregel in v1:

- wirksame `winget`-Definitionen werden bevorzugt über `winget DSC` verarbeitet
- `choco`, `msi` und `exe` werden über eine gemeinsame Abstraktionsschicht modelliert
- diese Abstraktionsschicht wird in v1 nur soweit ausgearbeitet, dass spätere Erweiterung sauber möglich ist

Verbindliche Source-Priorität in v1:

1. `winget`
2. `choco`
3. `msi`
4. `exe`

### 8.3 Ordner

Ordner werden als Menge behandelt.

Regeln:

- doppelte Einträge werden dedupliziert
- Pfade mit Umgebungsvariablen werden vor dem Vergleich normalisiert

### 8.4 Konfigurationsartefakte

Konfigurationsdateien sind die größte Konfliktquelle.

Regeln für v1:

- pro Zieldatei genau ein verantwortlicher Konfigurationseintrag
- mehrere Kategorien dürfen nicht dieselbe Zieldatei unterschiedlich definieren
- bei Mehrdeutigkeit wird mit `CONFLICT` abgebrochen

Für v1 wird bewusst **kein inhaltliches Dateimerge** vorgesehen.

### 8.5 PowerShell-Repositories und Module

PowerShell-Repositories und PowerShell-Module werden additiv zusammengeführt.

Regeln:

- Bootstrap-Module sind nicht optional und werden vor allen Kategorien verarbeitet
- Kategorien dürfen zusätzliche `PowerShellRepositories` definieren
- deklarierte Repositories werden auf dem Client als `Trusted` konfiguriert
- Kategorien dürfen optionale `PowerShellModules` definieren
- PowerShell-Module können optional einem Repository zugeordnet werden
- identische Repository-Definitionen werden dedupliziert
- widersprüchliche Repository-Definitionen erzeugen `CONFLICT`
- identische Moduldefinitionen werden dedupliziert

### 8.6 PowerShell- und Oh-My-Posh-Konfiguration

Das PowerShell-Profil ist ein zentrales Zielartefakt von v1.

Regeln:

- Kategorien dürfen PowerShell-Profilfragmente additiv beitragen
- das finale PowerShell-Profil wird deterministisch aus den aktiven Fragmenten erzeugt
- Kategorien dürfen ein `OhMyPoshProfile` referenzieren
- mehrere identische `OhMyPoshProfile`-Referenzen sind zulässig
- mehrere unterschiedliche aktive `OhMyPoshProfile`-Referenzen erzeugen `CONFLICT`
- dieser Konflikt wird nicht automatisch aufgelöst, sondern explizit im Client-Profil entschieden

### 8.7 Verhältnis von Client-Profil und Kategorien

Client-Profile dienen in v1 primär zur Auswahl von Kategorien.

Direkte inhaltliche Overrides im Client-Profil sollen möglichst klein gehalten werden. Falls sie eingeführt werden, müssen sie explizit markiert und validiert werden.

Bootstrap-Module werden nicht im Client-Profil definiert, sondern zentral vom System vorgegeben.

---

## 9. Konfigurationsmodell

### 9.1 Client-Profil

Beispiel:

```json
{
  "Categories": [
    "core-dev",
    "terminal",
    "git"
  ],
  "OhMyPoshProfile": "coding-minimal"
}
```

### 9.2 Kategorie

Beispiel:

```json
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
  "Configurations": [
    {
      "Name": "PowerShellProfile",
      "SourcePath": "Config/Applications/PowerShell/profile.ps1",
      "TargetPath": "$env:USERPROFILE\\Documents\\PowerShell\\Microsoft.PowerShell_profile.ps1"
    }
  ],
  "OhMyPoshProfile": "coding-minimal"
}
```

### 9.3 Schema-Erwartung

Auch wenn Schema-Validierung laut PRD eher später geplant ist, sollte das Design bereits davon ausgehen, dass Konfigurationen formal validierbar sind.

Das betrifft insbesondere:

- Pflichtfelder je Source-Typ
- erlaubte Werte für `Source`
- eindeutige Identifikation von Anwendungen
- Pflichtfeld `Name` für die quellenübergreifende Auflösung
- eindeutige Identifikation von PowerShell-Repositories
- gültige Modulnamen und optionale Repository-Zuordnung
- gültige Zielpfade für Konfigurationen

---

## 10. Installer-Strategie

### 10.1 Priorisierung der Paketquellen

Für v1 gilt folgende verbindliche Priorisierung:

1. `winget`
2. `choco`
3. `msi`
4. `exe`

Begründung:

- `winget` und `choco` haben die beste Automatisierbarkeit.
- `msi` und `exe` benötigen mehr Sonderlogik für Detection, Silent-Install und Fehlerbehandlung.

### 10.2 Bevorzugter Mechanismus: `winget DSC`

Für `winget`-basierte Anwendungen ist `winget DSC` in v1 der bevorzugte technische Mechanismus.

Begründung:

- deklarativer Sollzustand
- gute Passung zu `Report` und `Enforce`
- weniger eigene Logik für Standardfälle
- bessere Grundlage für idempotentes Verhalten

### 10.3 Auflösungsregel bei Mehrfachdefinitionen

Wenn dieselbe logische Applikation über mehrere Quellen definiert ist, bleibt genau eine wirksame Definition aktiv.

Regeln:

- das System vergleicht Applikationen primär über `Name`
- anschließend wird die höchstpriorisierte Quelle gewählt
- nur die wirksame Definition wird für `Report` und `Enforce` verwendet
- die gewählte Quelle wird im Reporting explizit ausgewiesen

Wenn die wirksame Definition `Source = winget` besitzt, wird sie in v1 an `winget DSC` übergeben.

### 10.4 Detection-Strategie

Für `Report Mode` muss je Source eine Prüflogik vorhanden sein.

V1-Ansatz:

- `winget`: Paket anhand ID erkennen
- `choco`: Paket anhand Paketname erkennen
- `msi`: nur zulässig, wenn eindeutige Detection-Regel definiert ist
- `exe`: nur zulässig, wenn eindeutige Detection-Regel definiert ist

Konsequenz:

Ein `msi`- oder `exe`-Eintrag ohne definierte Detection sollte in v1 als unvollständige Konfiguration behandelt werden.

### 10.5 Hüllen für ergänzende Quellen

Für `choco`, `msi` und `exe` wird in v1 eine gemeinsame Hülle vorgesehen.

Ziel dieser Hülle:

- einheitlicher Konfigurationsvertrag
- einheitliches Logging
- einheitliche Fehlerbehandlung
- spätere Erweiterbarkeit ohne Umbau des Gesamtmodells

Nicht Ziel von v1:

- vollständige Implementierung aller Sonderfälle und Edge Cases dieser Quellen

---

## 11. PowerShell Repository- und Modul-Strategie

PowerShell-Repositories und PowerShell-Module werden getrennt von klassischen Applikationsquellen behandelt.

### 11.1 Bootstrap-Module

Für den Bootstrap notwendige PowerShell-Module werden immer zuerst installiert.

Ziel:

- definierte Laufzeitbasis
- reproduzierbarer Bootstrap-Ablauf
- keine implizite Abhängigkeit von bereits vorhandenen Client-Modulen

### 11.2 Kategorie-Module

Kategorien dürfen optionale PowerShell-Module deklarieren.

Regeln:

- Installation nach erfolgreicher Bootstrap-Grundinitialisierung
- deklarativ über Name und optionales Repository
- idempotente Behandlung bereits installierter Module

### 11.3 Repositories

Kategorien dürfen PowerShell-Repositories definieren.

Regeln:

- Repositories werden vor optionalen Kategorie-Modulen verarbeitet
- deklarierte Repositories werden als `Trusted` konfiguriert
- widersprüchliche Definitionen desselben Repository-Namens sind nicht zulässig

---

## 12. PowerShell- und Oh-My-Posh-Konfiguration

PowerShell-Profil und Oh My Posh sind zentrale Bestandteile von v1.

### 12.1 PowerShell-Profil

Das finale `Microsoft.PowerShell_profile.ps1` wird als wirksames Zielartefakt behandelt.

V1-Regeln:

- ein Basisprofil stellt den gemeinsamen Einstieg bereit
- Kategorien können zusätzliche Fragmente aktivieren
- das finale Profil wird aus Basisprofil plus aktiven Fragmenten erzeugt
- die Erzeugung ist deterministisch und idempotent

### 12.2 Oh My Posh

Oh My Posh wird über explizit referenzierte Profile oder Themes unter `Config/Applications/OhMyPosh/Profiles` verwaltet.

V1-Regeln:

- Kategorien dürfen ein `OhMyPoshProfile` referenzieren
- mehrere aktive Kategorien mit demselben Profil sind zulässig
- mehrere unterschiedliche aktive Profile ergeben `CONFLICT`
- das Client-Profil kann diesen Konflikt explizit auflösen

### 12.3 Reporting

`Report Mode` muss sichtbar machen:

- welches PowerShell-Profil wirksam wäre
- welches Oh-My-Posh-Profil wirksam wäre
- ob ein Konflikt zwischen mehreren Kategorien besteht

---

## 13. Anwendungs-Konfigurationen

Konfigurationen unter `Config/Applications/*` werden nicht direkt "magisch" erkannt, sondern über deklarative Referenzen aus Kategorien eingebunden.

Das hat Vorteile:

- Nachvollziehbarkeit
- Konflikterkennung
- klare Ownership pro Zieldatei

V1-Regeln:

- Konfigurationen werden kopiert oder ersetzt
- keine bidirektionale Synchronisation
- keine inhaltlichen Merges von JSON/Textdateien
- Zielpfade müssen explizit angegeben sein

---

## 14. Windows Sandbox und Debug-Modus

### 14.1 Ziel

Die Sandbox soll als schneller Testpfad für Bootstrap und Konfigurationslogik dienen.

### 14.2 Anforderungen

Für die Sandbox wird ein eigenes Profil empfohlen:

- `sandbox-debug.json`
- minimale Tool-Auswahl
- bevorzugt nur schnell installierbare Pakete
- ausführliches Logging
- möglichst wenig interaktive Schritte

### 14.3 Besondere Einschränkungen

- Sandbox ist flüchtig
- persistente Credentials sind nur eingeschränkt sinnvoll
- Hostname ist kein verlässlicher Primärschlüssel
- lokale Benutzerdaten und Sync-Szenarien sind nur begrenzt relevant

### 14.4 Designentscheidung

Der Bootstrap muss explizit einen Sandbox-/Debug-Pfad unterstützen, statt Sandbox implizit aus dem Hostnamen abzuleiten.

---

## 15. Logging und Exitcodes

### 15.1 Logging-Ziele

Das Logging soll sowohl menschenlesbar als auch maschinenfreundlich sein.

Minimalanforderungen:

- Start- und Endzeit
- Modus
- Profilname
- geladene Kategorien
- gewählte Installationsquelle je Anwendung
- konfigurierte PowerShell-Repositories
- installierte Bootstrap- und Kategorie-Module
- wirksames PowerShell-Profil
- wirksames Oh-My-Posh-Profil
- erkannte Abweichungen
- ausgeführte Aktionen
- Fehler und Abbruchgründe

### 15.2 Statusklassen

Empfohlene Statuswerte:

- `OK`
- `MISSING`
- `CHANGED`
- `SKIPPED`
- `CONFLICT`
- `ERROR`

### 15.3 Exitcodes

Vorschlag für v1:

- `0`: Erfolg, keine kritischen Probleme
- `1`: Abweichungen gefunden im `Report Mode`
- `2`: Konfigurationsfehler oder Konflikte
- `3`: Ausführungsfehler während `Enforce`

---

## 16. Sicherheit

Die Sicherheitsanforderung für den Bootstrap ist noch offen. Daher wird sie als Architekturentscheidung dokumentiert.

### 16.1 Mindestanforderung für v1

Mindestens vorgesehen werden sollten:

- vertrauenswürdige Bezugsquelle des Bootstrap-Skripts
- Integritätsprüfung des geladenen Inhalts
- saubere Behandlung von Credentials
- keine Ablage sensibler Daten im Repository

### 16.2 Offene Entscheidung

Noch zu klären:

- genügt Hash-/Integritätsprüfung
- oder ist Code-Signing für Bootstrap und Modul verpflichtend

Bis zur finalen Entscheidung sollte das Design keine unsichere Default-Annahme festschreiben.

---

## 17. Validierung vor Ausführung

Obwohl formale Validation im PRD als spätere Erweiterung auftaucht, sollte bereits v1 eine minimale Vorabprüfung besitzen.

### 17.1 Zu prüfen

- existieren referenzierte Kategorien
- existieren referenzierte Konfigurationsquellen
- sind Pflichtfelder pro Installer-Typ gesetzt
- gibt es doppelte oder widersprüchliche App-Definitionen
- lässt sich die priorisierte Quelle je Anwendung eindeutig bestimmen
- gibt es mehrere unterschiedliche aktive `OhMyPoshProfile`-Referenzen
- gibt es mehrere Writer für dieselbe Zieldatei
- sind `winget`-Definitionen `winget DSC`-fähig modelliert
- besitzen `choco`, `msi` und `exe` mindestens die für die Hülle erforderlichen Pflichtinformationen
- sind deklarierte PowerShell-Repositories eindeutig und vollständig
- besitzen optionale PowerShell-Module gültige Namen und ggf. gültige Repository-Verweise

### 17.2 Verhalten

Bei Validierungsfehlern wird nicht teilweise ausgeführt, sondern vor dem eigentlichen Setup abgebrochen.

---

## 18. Risiken

### Technische Risiken

- uneinheitliche Detection bei `msi` und `exe`
- unterschiedliche Systemzustände auf bestehenden Clients
- Konflikte zwischen Kategorien bei wachsender Konfigurationsmenge
- Sicherheitsrisiko durch zu simplen Bootstrap-Pfad

### Operative Risiken

- interaktive Authentifizierung kann in Sandbox umständlich sein
- Installer können Reboots oder Sonderrechte verlangen
- Paketquellen können temporär nicht verfügbar sein

### Designrisiken

- zu viele Sonderregeln im Client-Profil
- fehlende Ownership für Konfigurationsdateien
- spätes Einführen von Validierung erzeugt instabile Datenqualität
- unklare Shell-Profil-Verantwortung zwischen Kategorien
- widersprüchliche Repository-Definitionen für PowerShell-Module

---

## 19. Empfohlene Umsetzungsreihenfolge

### Phase 1

- `bootstrap.ps1`
- Modulgrundgerüst
- Bootstrap-PowerShell-Module
- Profilauflösung
- Basis-PowerShell-Profil
- Oh-My-Posh-Integration
- `Report Mode`
- `winget DSC`-Integration
- Ordnerverwaltung

### Phase 2

- `Enforce Mode`
- Logging und Exitcodes
- PowerShell-Repositories als `Trusted`
- optionale Kategorie-Module
- Konfigurationsanwendung für einfache Dateien
- Sandbox-Debug-Profil
- kategoriespezifische PowerShell-Fragmente
- Hülle für ergänzende Paketquellen

### Phase 3

- konzeptionelle Erweiterung für `choco`
- Validation Layer
- Konflikterkennung für Konfigurationen
- Konflikterkennung für `OhMyPoshProfile`

### Phase 4

- `msi` und `exe` mit sauberer Detection
- erweiterte Reports
- optionale Security-Härtung wie Signierung

---

## 20. Offene Entscheidungen

Folgende Punkte sind noch nicht final festgelegt:

1. Sicherheitsniveau des Bootstrap-Prozesses
2. genaue Authentifizierungsstrategie für Sandbox-/Debug-Szenarien
3. konkrete Detection-Regeln für `msi` und `exe`
4. ob Client-Profile künftig weitere direkte Overrides enthalten dürfen
5. ob später partielle Dateimerges unterstützt werden sollen
6. wie stark `Report Mode` direkt auf `winget DSC`-Ressourcen gegenüber zusätzlicher eigener Auswertung setzen soll
7. ob für PowerShell-Module langfristig `PSResourceGet` oder klassische `PowerShellGet`-Befehle bevorzugt werden

---

## 21. Fazit

Das Vorhaben ist für Windows technisch gut umsetzbar und das PRD liefert bereits eine tragfähige Grundrichtung.

Für eine robuste erste Version müssen jedoch vier Entscheidungen früh festgezogen werden:

- explizite Profilauflösung mit Sandbox-Unterstützung
- klare Merge-, Prioritäts- und Konfliktregeln
- minimale Validierung vor Ausführung
- definierte Sicherheitsbasis für den Bootstrap

Zusätzlich muss der Bootstrap die für sich selbst benötigten PowerShell-Module immer zuerst sicherstellen, bevor kategorieabhängige optionale Module verarbeitet werden.
