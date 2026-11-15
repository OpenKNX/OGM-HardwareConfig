# ToDo — OGM-HardwareConfig

**Die eine Liste.** Alles Offene zum Hardware-Generator und den Board-Headern steht hier. Erledigtes wird gelöscht,
nicht abgehakt — was hier steht, steht noch aus.

Stand: **2026-11-16** (Branch `ec/feat-hw-profiler`) · **27 offene Punkte**. Nummeriert nach Priorität; kommt ein
Punkt dazu oder fällt einer weg, wird neu nummeriert. Quelle der meisten Punkte: Architektur-Review vom 2026-11-16.
„geprüft" = an Datei und Zeile nachvollzogen; „laut Review" = noch nicht selbst nachgeprüft.

Regeln: Der Generator gilt für alle OAMs (keine produktspezifischen Sonderwege). Eine Änderung darf bestehende OAMs nicht
brechen: gleiche Parameter-IDs, gleiches Speicherlayout, gleiche Bit-Reihenfolge der Geräteabfrage; ändert sich der
ETS-Inhalt eines OAM, braucht es dort einen Versions-Bump. Skripte bleiben PowerShell 5.1 und ASCII.

## Übersicht, sortiert

Prio 1 = vor dem Push/Merge des Branches, 2 = bald, wenn klein, 3 = danach. Aufwand: S = Stunden, M = 1-2 Tage, L = mehr.

| Nr | Thema | Prio | Risiko | Aufwand | Stand |
|---|---|---|---|---|---|
| 1 | Calculations und Baumtext in ETS 5 und 6 messen | 1 | hoch | M | Messplan steht |
| 2 | Parametertypen je Board nach Inhalt zusammenfassen | 2 | mittel | M | laut Review, Update-Verhalten prüfen |
| 3 | GPIO-Parameter für Boards ohne Pins weglassen | 2 | mittel | S | laut Review |
| 4 | Slot-Grenze der OAM-Vorlagen prüfen (NeoPixel: 50) | 2 | mittel | S | geprüft |
| 5 | Neue Funktionen standardmäßig aus? | 2 | mittel | S | entscheiden |
| 6 | Gelöschte Boards in der Auswahl behalten | 2 | mittel | S | entscheiden |
| 7 | PSRAM-Pins ESP32: CS1 (S3) uneinheitlich, CS/CLK (ESP32) fehlen | 2 | niedrig | S | laut Review |
| 8 | Unbekannte Attribute im Manifest melden, `prefix` prüfen | 2 | niedrig | S | laut Review |
| 9 | CI ausbauen: XSD, Producer-Lauf, Header kompilieren, Tests | 2 | mittel | M-L |  |
| 10 | Windows PowerShell 5.1: CI-Lauf nach dem Push prüfen | 2 | mittel | S | wartet auf Push |
| 11 | Zweites Hardware-Modul: beide beantworten 158/4 | 2 | mittel | S | laut Review |
| 12 | Doppelte Tabellen QUICKSTART/README | 3 | niedrig | S | entscheiden |
| 13 | Port-Listen verschiedener Envs einer HW-ID: Fehler statt Warnung | 3 | niedrig | S | laut Review |
| 14 | Sortierung ordinal statt kulturabhängig | 3 | niedrig | S | laut Review |
| 15 | `-Init` schreibt `order="hwid"` | 3 | niedrig | S | laut Review |
| 16 | Header: `-Wtype-limits`-Warnungen, static_assert für Relais-GPIOs | 3 | niedrig | S | laut Review |
| 17 | BoardTable, Entwickleransicht und op:config schlanker | 3 | niedrig | M | laut Review |
| 18 | Laufzeit: weniger Präprozessorläufe, Cache bei unveränderten Eingängen | 3 | niedrig | M | laut Review |
| 19 | Manifest-XSD für Editor und Prüfung | 3 | niedrig | M |  |
| 20 | Feste Texte übersetzbar machen | 3 | niedrig | M |  |
| 21 | Baumtext ohne Script (Assign auf speicherlose Aufzählung) | 3 | niedrig | S | erst in ETS prüfen |
| 22 | `unselectedValue` und `ids="index"` entfernen, wenn kein OAM sie braucht | 3 | niedrig | S |  |
| 23 | Meldungen des Abfrage-Scripts sagen „Hardware“, die Seite „Gerät“ | 3 | niedrig | S |  |
| 24 | Render-Skripte für Badge und Glyphen-Atlas fehlen im Repo | 3 | niedrig | S | laut Review |
| 25 | Nur ein abgefragter Wert für ein OAM frei (Common belegt 3 von 4) | 3 | niedrig | S | entscheiden |
| 26 | Fähigkeit wechselt `switch` false/true: Speicherbits späterer Schalter rutschen | 3 | mittel | S | laut Review |
| 27 | FIPS: Bildvergleich über SHA-256 meldet jedes PNG als geändert | 3 | niedrig | S | laut Review |

### 1 — Calculations und Baumtext in ETS 5 und 6 messen

Die GPIO-Konfliktprüfung (NeoPixel: 856 Eingänge) und der Baumtext liefen bisher nur im Viewer. Messplan:
- **Konfliktprüfung, Zeit:** gleiche Applikation einmal mit, einmal ohne `<Conflicts>` bauen. Je Variante: Öffnen des
  Parameterdialogs und eine Port-Änderung stoppen (ETS6 zusätzlich über die Dauer von `device_set_parameter` im KNX-MCP).
- **Konfliktprüfung, Wirkung:** zwei Strips auf denselben Port → Meldung erscheint; einen umstellen → Meldung verschwindet.
- **Baumtext:** Auswahl setzen und auf „nicht gewählt" zurück; „Vom Gerät lesen" setzt die Auswahl; Projekt schließen und
  öffnen; Applikation aktualisieren. Jedes Mal muss der Baum „Gerät" bzw. „Gerät (nicht gewählt)" zeigen.
- ETS5 nur per Hand (Screenshot), ETS6 über KNX-MCP im Projekt TEST.

### 2 — Parametertypen je Board nach Inhalt zusammenfassen

NeoPixel: 80 Typen in `NeoPixel.hw.types.gen.xml`, laut Review nur 15 verschiedene Inhalte (Daten- und Takt-Typ eines Boards
gleich). Vor der Umsetzung belegen, dass ein Typwechsel bei gleicher Parameter-ID und gleichen Werten ein ETS-Update übersteht.

### 3 — GPIO-Parameter für Boards ohne Pins weglassen

Parameter, ParameterRef und Typ der GPIO-Rollen entstehen auch für Boards ohne Pins; die Seite überspringt sie. Demo laut
Review: 22 tote Parameter, 11 Typen, 22 Eingänge der Konfliktprüfung. Speicherlayout vorher prüfen (Union).

### 4 — Slot-Grenze der OAM-Vorlagen prüfen

NeoPixel nummeriert Daten `900+Slot`, Takt `950+Slot`, Relais `200/250/300/350+Slot`: ab Slot 50 doppelte IDs. Belegt ist
bis Slot 39. Der Generator prüft nur 1000. Vorschlag: `maxSlots` im Manifest.

### 5 — Neue Funktionen standardmäßig aus?

`queryImage` und `unselectedTitle` gelten ohne Eintrag im Manifest; das README sagt „ohne den Eintrag bleiben die erzeugten
Dateien byte-gleich". Entscheiden: Standard aus (Regel gilt) oder an (README anpassen, OAMs übernehmen beim nächsten Lauf).

### 6 — Gelöschte Boards in der Auswahl behalten

Fällt ein `release_*`-Env weg, warnt der Lauf nur. Die gespeicherte HW-ID ist dann kein Wert der Aufzählung mehr; ETS setzt
„nicht gewählt", bei `hide` setzt der nächste Download die Einstellungen zurück. Vorschlag: Eintrag „(nicht mehr unterstützt)".

### 7 — PSRAM-Pins ESP32

ETS reserviert CS1 (S3) nur mit `BOARD_HAS_PSRAM`, der Header auch bei `CONFIG_SPIRAM`. CS/CLK des klassischen ESP32 mit PSRAM
(sdkconfig 16/17, Annahme, an den Boards nicht geprüft) fehlen auf beiden Seiten. Mit den Boards abgleichen.

### 8 — Unbekannte Attribute im Manifest melden

Nur InfoImage, Conflicts, Use und BoardTable prüfen ihre Attribute. Ein Tippfehler in `<Page>`, `<Capability>`, `<Value>` fällt
still auf den Standard. `prefix` landet in JS-Namen und C-Makros, wird aber nicht geprüft.

### 9 — CI ausbauen

Heute prüft die CI nur, ob die committeten Ausgaben den erzeugten entsprechen. Fehlt: XSD-Prüfung, Producer-Lauf, Kompilieren
von `HardwareProfileData.h`, ES3-Prüfung der Scripts, die Pfade `ids="index"` und `hide`, Tests für Vorlagen, QR, PNG und
Konfliktprüfung im Repo.

### 10 — Windows PowerShell 5.1: CI-Lauf nach dem Push prüfen

Der aktuelle Stand lief nur unter PowerShell 7 (macOS); unter 5.1 ist er nicht belegt. Die CI läuft unter 5.1; nach dem Push
das Ergebnis prüfen.

### 11 — Zweites Hardware-Modul: beide beantworten 158/4

`-Init` kann ein zweites Modul (z. B. `HWP2`) anlegen; beide Module beantworten die Geräteabfrage 158/4, es antwortet das
erste. 158/4 bleibt in OGM-HardwareConfig (Entscheidung 2026-11-16), deshalb: `-Init` lehnt ein zweites Modul ab.

### 12 — Doppelte Tabellen QUICKSTART/README

QUICKSTART „Was man setzen kann" wiederholt Tabellen des README; dort lief schon eine Zeile auseinander (Rückfall auf
`DEVICE_ID`). Entscheiden: Übersicht im QUICKSTART nur mit Verweisen, oder so lassen und bei jeder Änderung beide pflegen.

### 13 — Port-Listen verschiedener Envs einer HW-ID

Weichen die Port-Listen zweier Envs derselben HW-ID ab, warnt der Lauf nur (Relais, URL, Text, MCU stoppen). ETS bietet dann
die Ports von Env A für die Firmware von Env B an. Vor dem Umstellen auf Fehler prüfen, welche OAMs das heute auslösen.

### 14 — Sortierung ordinal

`Sort-Object` auf Zeichenketten kann unter 5.1 (NLS) und 7 (ICU) anders sortieren; dann widersprechen sich `-Check` lokal und
in der CI. Ordinal vergleichen.

### 15 — `-Init` schreibt `order="hwid"`

Standard ist `manifest`; die Festlegung ist „nach HW-ID sortieren". Neue OAMs sollen es ohne Zutun bekommen.

### 16 — Header: Warnungen und Relais-Prüfung

`HardwarePorts.h` warnt mit `-Wextra` (`-Wtype-limits`) auf Boards ohne Relais; Relais-GPIOs haben kein static_assert wie die
Ports.

### 17 — BoardTable, Entwickleransicht und op:config schlanker

`NEOHW_table_EffectsOff` 9 073 Bytes, fast nur Nullen; Entwickleransicht 191 KB (nur Dev); Demo erzeugt 133 op:config, nutzt 30.

### 18 — Laufzeit

Demo 9 s, NeoPixel 19 s je Lauf; je Env mehrere Präprozessorläufe (Identität, Hauptlauf, BoardTable). Ein Lauf je Env oder ein
Cache über die Eingänge.

### 19 — Manifest-XSD

Für Vervollständigung im Editor und eine Prüfung vor dem Lauf.

### 20 — Feste Texte übersetzbar machen

„Nicht gewählt", „aus/ein", „nicht verwendet", Konfliktmeldungen, Script-Meldungen und Entwickleransicht sind fest deutsch.

### 21 — Baumtext ohne Script

Statt der ParameterCalculation eine speicherlose Aufzählung mit zwei Werten, per `<Assign>` in den vorhandenen `when`-Zweigen
gesetzt, als `TextParameterRefId`. Erst prüfen, ob ETS für `{{0}}` den Text der Aufzählung zeigt.

### 22 — `unselectedValue` und `ids="index"` entfernen

Weniger Code und Zweige, sobald kein OAM die Altpfade mehr braucht.

### 23 — Meldungen des Abfrage-Scripts sagen „Hardware“, die Seite „Gerät“

Das Script meldet „Hardware: … erkannt“ und „Hardware … ist dieser Applikation unbekannt“; Seite, Auswahl und Knopf sprechen
seit der neuen Geräteseite von „Gerät“ bzw. „Gerätetyp“. Texte angleichen (OAM-Hilfen zitieren sie).

### 24 — Render-Skripte für Badge und Glyphen-Atlas fehlen im Repo

`generator/assets/README.md` beschreibt das Erzeugen von Badge und Schrift-Atlas, das Skript dazu liegt nicht im Repo. Als
PowerShell-Skript beilegen oder das Vorgehen so beschreiben, dass es nachvollziehbar ist.

### 25 — Nur ein abgefragter Wert für ein OAM frei (Common belegt 3 von 4)

Die Geräteabfrage trägt höchstens 4 Werte (`$MAX_VALUES`, Länge des Telegramms); `Common.caps.xml` fragt BinaryInputs, StatusLeds
und FlashMB ab. Vorschlag: Werte im Paket standardmäßig `query="false"` (nur ETS). Achtung: ein OAM, dessen Slot-Datei diese
Werte schon kennt, braucht sie weiter in der Abfrage (eine Firmware im Feld sendet sie); also nur für neue OAMs.

### 26 — Fähigkeit wechselt `switch` false/true: Speicherbits späterer Schalter rutschen

Das Speicherbit eines Schalters ist seine Position unter den Fähigkeiten mit `switch="true"` (`Get-Switches`). Wird eine schon
erfasste Fähigkeit nachträglich zum Schalter (oder umgekehrt), verschieben sich die Bits aller späteren Schalter, und ein
ETS-Update liest deren Werte falsch. Vorschlag: Schalter-Bits wie die Abfrage-Bits in der Slot-Datei festhalten.

### 27 — FIPS: Bildvergleich über SHA-256 meldet jedes PNG als geändert

`Update-PngRgba` (helpers/PngImage.ps1) vergleicht über `Get-PngSha256` und fängt einen Fehler ab, indem es die Datei neu
schreibt. Blockiert eine FIPS-Richtlinie `SHA256.Create()` (Windows PowerShell 5.1, .NET Framework), schreibt jeder Lauf alle
Bilder neu und `-Check` meldet sie als veraltet. Vergleich ohne Hash (Bytes) oder `SHA256CryptoServiceProvider`; nicht gemessen.
