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
└─ bootstrap.ps1
```

### 5.2 Schichtenmodell

#### Bootstrap Layer

`bootstrap.ps1` übernimmt:

- Vorbedingungen prüfen
- Repository beschaffen oder aktualisieren
- Modul laden
- Zielmodus und Profil bestimmen
- Setup auslösen

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

#### Configuration Layer

`Config/*` enthält ausschließlich deklarative Daten.

---

## 6. Ausführungsmodell

### 6.1 Bootstrap-Ablauf

Vorgeschlagener logischer Ablauf:

1. PowerShell-Version prüfen
2. benötigte Basiswerkzeuge prüfen
3. Zielrepository klonen oder aktualisieren
4. Modul laden
5. Profil bestimmen
6. Kategorien auflösen
7. Installer-Quellen und Shell-Konfiguration auflösen
8. `winget`-Definitionen an `winget DSC` übergeben
9. ergänzende Quellen über Hüllen vorbereiten oder ausführen
10. Konfiguration validieren
11. Sollzustand berechnen
12. `Report` oder `Enforce` ausführen
13. Ergebnis loggen und Exitcode setzen

### 6.2 Betriebsmodi

#### Report Mode

- führt keine Änderungen durch
- prüft Anwendungen, Ordner und Konfigurationen
- prüft PowerShell-Profil und Oh-My-Posh-Auswahl
- meldet `OK`, `MISSING`, `CONFLICT`, `ERROR`

#### Enforce Mode

- installiert fehlende Anwendungen
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

Beispiele:

- gleiche Anwendung via `winget` und `choco` → `winget` wird wirksam
- gleiche Anwendung nur via `msi` und `exe` → `msi` wird wirksam
- gleiche `Name`-Definition mit zwei unterschiedlichen `winget`-Einträgen → `CONFLICT`
- unterschiedliche Silent-Argumente innerhalb der wirksamen Definition → `CONFLICT`

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

### 8.5 PowerShell- und Oh-My-Posh-Konfiguration

Das PowerShell-Profil ist ein zentrales Zielartefakt von v1.

Regeln:

- Kategorien dürfen PowerShell-Profilfragmente additiv beitragen
- das finale PowerShell-Profil wird deterministisch aus den aktiven Fragmenten erzeugt
- Kategorien dürfen ein `OhMyPoshProfile` referenzieren
- mehrere identische `OhMyPoshProfile`-Referenzen sind zulässig
- mehrere unterschiedliche aktive `OhMyPoshProfile`-Referenzen erzeugen `CONFLICT`
- dieser Konflikt wird nicht automatisch aufgelöst, sondern explizit im Client-Profil entschieden

### 8.6 Verhältnis von Client-Profil und Kategorien

Client-Profile dienen in v1 primär zur Auswahl von Kategorien.

Direkte inhaltliche Overrides im Client-Profil sollen möglichst klein gehalten werden. Falls sie eingeführt werden, müssen sie explizit markiert und validiert werden.

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

## 11. PowerShell- und Oh-My-Posh-Konfiguration

PowerShell-Profil und Oh My Posh sind zentrale Bestandteile von v1.

### 11.1 PowerShell-Profil

Das finale `Microsoft.PowerShell_profile.ps1` wird als wirksames Zielartefakt behandelt.

V1-Regeln:

- ein Basisprofil stellt den gemeinsamen Einstieg bereit
- Kategorien können zusätzliche Fragmente aktivieren
- das finale Profil wird aus Basisprofil plus aktiven Fragmenten erzeugt
- die Erzeugung ist deterministisch und idempotent

### 11.2 Oh My Posh

Oh My Posh wird über explizit referenzierte Profile oder Themes unter `Config/Applications/OhMyPosh/Profiles` verwaltet.

V1-Regeln:

- Kategorien dürfen ein `OhMyPoshProfile` referenzieren
- mehrere aktive Kategorien mit demselben Profil sind zulässig
- mehrere unterschiedliche aktive Profile ergeben `CONFLICT`
- das Client-Profil kann diesen Konflikt explizit auflösen

### 11.3 Reporting

`Report Mode` muss sichtbar machen:

- welches PowerShell-Profil wirksam wäre
- welches Oh-My-Posh-Profil wirksam wäre
- ob ein Konflikt zwischen mehreren Kategorien besteht

---

## 12. Anwendungs-Konfigurationen

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

## 13. Windows Sandbox und Debug-Modus

### 12.1 Ziel

Die Sandbox soll als schneller Testpfad für Bootstrap und Konfigurationslogik dienen.

### 12.2 Anforderungen

Für die Sandbox wird ein eigenes Profil empfohlen:

- `sandbox-debug.json`
- minimale Tool-Auswahl
- bevorzugt nur schnell installierbare Pakete
- ausführliches Logging
- möglichst wenig interaktive Schritte

### 12.3 Besondere Einschränkungen

- Sandbox ist flüchtig
- persistente Credentials sind nur eingeschränkt sinnvoll
- Hostname ist kein verlässlicher Primärschlüssel
- lokale Benutzerdaten und Sync-Szenarien sind nur begrenzt relevant

### 12.4 Designentscheidung

Der Bootstrap muss explizit einen Sandbox-/Debug-Pfad unterstützen, statt Sandbox implizit aus dem Hostnamen abzuleiten.

---

## 14. Logging und Exitcodes

### 13.1 Logging-Ziele

Das Logging soll sowohl menschenlesbar als auch maschinenfreundlich sein.

Minimalanforderungen:

- Start- und Endzeit
- Modus
- Profilname
- geladene Kategorien
- gewählte Installationsquelle je Anwendung
- wirksames PowerShell-Profil
- wirksames Oh-My-Posh-Profil
- erkannte Abweichungen
- ausgeführte Aktionen
- Fehler und Abbruchgründe

### 13.2 Statusklassen

Empfohlene Statuswerte:

- `OK`
- `MISSING`
- `CHANGED`
- `SKIPPED`
- `CONFLICT`
- `ERROR`

### 13.3 Exitcodes

Vorschlag für v1:

- `0`: Erfolg, keine kritischen Probleme
- `1`: Abweichungen gefunden im `Report Mode`
- `2`: Konfigurationsfehler oder Konflikte
- `3`: Ausführungsfehler während `Enforce`

---

## 15. Sicherheit

Die Sicherheitsanforderung für den Bootstrap ist noch offen. Daher wird sie als Architekturentscheidung dokumentiert.

### 14.1 Mindestanforderung für v1

Mindestens vorgesehen werden sollten:

- vertrauenswürdige Bezugsquelle des Bootstrap-Skripts
- Integritätsprüfung des geladenen Inhalts
- saubere Behandlung von Credentials
- keine Ablage sensibler Daten im Repository

### 14.2 Offene Entscheidung

Noch zu klären:

- genügt Hash-/Integritätsprüfung
- oder ist Code-Signing für Bootstrap und Modul verpflichtend

Bis zur finalen Entscheidung sollte das Design keine unsichere Default-Annahme festschreiben.

---

## 16. Validierung vor Ausführung

Obwohl formale Validation im PRD als spätere Erweiterung auftaucht, sollte bereits v1 eine minimale Vorabprüfung besitzen.

### 15.1 Zu prüfen

- existieren referenzierte Kategorien
- existieren referenzierte Konfigurationsquellen
- sind Pflichtfelder pro Installer-Typ gesetzt
- gibt es doppelte oder widersprüchliche App-Definitionen
- lässt sich die priorisierte Quelle je Anwendung eindeutig bestimmen
- gibt es mehrere unterschiedliche aktive `OhMyPoshProfile`-Referenzen
- gibt es mehrere Writer für dieselbe Zieldatei
- sind `winget`-Definitionen `winget DSC`-fähig modelliert
- besitzen `choco`, `msi` und `exe` mindestens die für die Hülle erforderlichen Pflichtinformationen

### 15.2 Verhalten

Bei Validierungsfehlern wird nicht teilweise ausgeführt, sondern vor dem eigentlichen Setup abgebrochen.

---

## 17. Risiken

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

---

## 18. Empfohlene Umsetzungsreihenfolge

### Phase 1

- `bootstrap.ps1`
- Modulgrundgerüst
- Profilauflösung
- Basis-PowerShell-Profil
- Oh-My-Posh-Integration
- `Report Mode`
- `winget DSC`-Integration
- Ordnerverwaltung

### Phase 2

- `Enforce Mode`
- Logging und Exitcodes
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

## 19. Offene Entscheidungen

Folgende Punkte sind noch nicht final festgelegt:

1. Sicherheitsniveau des Bootstrap-Prozesses
2. genaue Authentifizierungsstrategie für Sandbox-/Debug-Szenarien
3. konkrete Detection-Regeln für `msi` und `exe`
4. ob Client-Profile künftig weitere direkte Overrides enthalten dürfen
5. ob später partielle Dateimerges unterstützt werden sollen
6. wie stark `Report Mode` direkt auf `winget DSC`-Ressourcen gegenüber zusätzlicher eigener Auswertung setzen soll

---

## 20. Fazit

Das Vorhaben ist für Windows technisch gut umsetzbar und das PRD liefert bereits eine tragfähige Grundrichtung.

Für eine robuste erste Version müssen jedoch vier Entscheidungen früh festgezogen werden:

- explizite Profilauflösung mit Sandbox-Unterstützung
- klare Merge-, Prioritäts- und Konfliktregeln
- minimale Validierung vor Ausführung
- definierte Sicherheitsbasis für den Bootstrap

Mit diesen Leitplanken kann das Repository schrittweise vom PRD zu einer belastbaren v1-Architektur weiterentwickelt werden.
