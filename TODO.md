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
| 1 | Versionswächter: ETS-Inhalt geändert, ApplicationVersion gleich | 1 | hoch | M | geprüft |
| 2 | Bits der Geräteabfrage nach Namen aus der Slot-Datei vergeben | 1 | hoch | M | geprüft |
| 3 | Produkt-XML gegen das Manifest prüfen (Präfix, ModuleType, Seitenblock) | 1 | mittel | S |  |
| 4 | Calculations und Baumtext in ETS 5 und 6 messen | 1 | hoch | M | Messplan steht |
| 5 | Parametertypen je Board nach Inhalt zusammenfassen | 2 | mittel | M | laut Review, Update-Verhalten prüfen |
| 6 | GPIO-Parameter für Boards ohne Pins weglassen | 2 | mittel | S | laut Review |
| 7 | Slot-Grenze der OAM-Vorlagen prüfen (NeoPixel: 50) | 2 | mittel | S | geprüft |
| 8 | Neue Funktionen standardmäßig aus? | 2 | mittel | S | entscheiden |
| 9 | Gelöschte Boards in der Auswahl behalten | 2 | mittel | S | entscheiden |
| 10 | PSRAM-Pins ESP32: CS1 (S3) uneinheitlich, CS/CLK (ESP32) fehlen | 2 | niedrig | S | laut Review |
| 11 | Unbekannte Attribute im Manifest melden, `prefix` prüfen | 2 | niedrig | S | laut Review |
| 12 | CI ausbauen: XSD, Producer-Lauf, Header kompilieren, Tests | 2 | mittel | M-L |  |
| 13 | Windows PowerShell 5.1: CI-Lauf nach dem Push prüfen | 2 | mittel | S | wartet auf Push |
| 14 | Zweites Hardware-Modul: beide beantworten 158/4 | 2 | mittel | S | laut Review |
| 15 | Doppelte Tabellen QUICKSTART/README | 3 | niedrig | S | entscheiden |
| 16 | Port-Listen verschiedener Envs einer HW-ID: Fehler statt Warnung | 3 | niedrig | S | laut Review |
| 17 | Sortierung ordinal statt kulturabhängig | 3 | niedrig | S | laut Review |
| 18 | `-Init` schreibt `order="hwid"` | 3 | niedrig | S | laut Review |
| 19 | Header: `-Wtype-limits`-Warnungen, static_assert für Relais-GPIOs | 3 | niedrig | S | laut Review |
| 20 | BoardTable, Entwickleransicht und op:config schlanker | 3 | niedrig | M | laut Review |
| 21 | Laufzeit: weniger Präprozessorläufe, Cache bei unveränderten Eingängen | 3 | niedrig | M | laut Review |
| 22 | Manifest-XSD für Editor und Prüfung | 3 | niedrig | M |  |
| 23 | Feste Texte übersetzbar machen | 3 | niedrig | M |  |
| 24 | Baumtext ohne Script (Assign auf speicherlose Aufzählung) | 3 | niedrig | S | erst in ETS prüfen |
| 25 | `unselectedValue` und `ids="index"` entfernen, wenn kein OAM sie braucht | 3 | niedrig | S |  |
| 26 | Meldungen des Abfrage-Scripts sagen „Hardware“, die Seite „Gerät“ | 3 | niedrig | S |  |
| 27 | Render-Skripte für Badge und Glyphen-Atlas fehlen im Repo | 3 | niedrig | S | laut Review |

### 1 — Versionswächter: ETS-Inhalt geändert, ApplicationVersion gleich

Der Generator warnt nur bei geänderter Board-Liste oder geänderten Abfrage-Bits. Andere Änderungen an share, conf, Script oder
Bildern ändern die knxprod ohne Warnung; ETS behandelt zwei gleich nummerierte Versionen mit verschiedenem Inhalt als Reset
(laut OAM-NeoPixel/CLAUDE.md, nicht gemessen).
Belegt: Commit `b2f2d1b` änderte die Demo-`share.xml`, die ApplicationVersion blieb. Vorschlag: Hash der ETS-Ausgaben plus
Version aus `<op:ETS>` in die Slot-Datei; Inhalt anders, Version gleich → Warnung bzw. Abbruch.

### 2 — Bits der Geräteabfrage nach Namen aus der Slot-Datei vergeben

Reihenfolge heute: ThirdParty, dann die Pakete (Common.caps.xml), dann das Manifest. Ein neuer Eintrag in `Common.caps.xml`
verschiebt die Bits jedes OAM mit eigenen Fähigkeiten und stoppt dessen Lauf; das OAM kann es nicht selbst beheben. Common
belegt 3 der 4 Wert-Plätze (`$MAX_VALUES = 4`). Vorschlag: Bits nach den in der Slot-Datei stehenden Namen, neue hinten;
Werte des Pakets standardmäßig `query="false"`, damit ein OAM mehr als einen eigenen Wert abfragen kann.
Bestehende Layouts bleiben unverändert.

### 3 — Produkt-XML gegen das Manifest prüfen

Der Generator kennt Präfix und ModuleType aus dem Manifest, prüft aber nicht, ob das Produkt-XML sie so einbindet und den
Seitenblock mit `TextParameterRefId` nutzt. Folge: ein OAM rechnet den Baumtext, zeigt ihn aber nicht (NeoPixel bis 2026-11-16). Mindestens eine
Warnung.

### 4 — Calculations und Baumtext in ETS 5 und 6 messen

Die GPIO-Konfliktprüfung (NeoPixel: 856 Eingänge) und der Baumtext liefen bisher nur im Viewer. Messplan:
- **Konfliktprüfung, Zeit:** gleiche Applikation einmal mit, einmal ohne `<Conflicts>` bauen. Je Variante: Öffnen des
  Parameterdialogs und eine Port-Änderung stoppen (ETS6 zusätzlich über die Dauer von `device_set_parameter` im KNX-MCP).
- **Konfliktprüfung, Wirkung:** zwei Strips auf denselben Port → Meldung erscheint; einen umstellen → Meldung verschwindet.
- **Baumtext:** Auswahl setzen und auf „nicht gewählt" zurück; „Vom Gerät lesen" setzt die Auswahl; Projekt schließen und
  öffnen; Applikation aktualisieren. Jedes Mal muss der Baum „Gerät" bzw. „Gerät (nicht gewählt)" zeigen.
- ETS5 nur per Hand (Screenshot), ETS6 über KNX-MCP im Projekt TEST.

### 5 — Parametertypen je Board nach Inhalt zusammenfassen

NeoPixel: 80 Typen in `NeoPixel.hw.types.gen.xml`, laut Review nur 15 verschiedene Inhalte (Daten- und Takt-Typ eines Boards
gleich). Vor der Umsetzung belegen, dass ein Typwechsel bei gleicher Parameter-ID und gleichen Werten ein ETS-Update übersteht.

### 6 — GPIO-Parameter für Boards ohne Pins weglassen

Parameter, ParameterRef und Typ der GPIO-Rollen entstehen auch für Boards ohne Pins; die Seite überspringt sie. Demo laut
Review: 22 tote Parameter, 11 Typen, 22 Eingänge der Konfliktprüfung. Speicherlayout vorher prüfen (Union).

### 7 — Slot-Grenze der OAM-Vorlagen prüfen

NeoPixel nummeriert Daten `900+Slot`, Takt `950+Slot`, Relais `200/250/300/350+Slot`: ab Slot 50 doppelte IDs. Belegt ist
bis Slot 39. Der Generator prüft nur 1000. Vorschlag: `maxSlots` im Manifest.

### 8 — Neue Funktionen standardmäßig aus?

`queryImage` und `unselectedTitle` gelten ohne Eintrag im Manifest; das README sagt „ohne den Eintrag bleiben die erzeugten
Dateien byte-gleich". Entscheiden: Standard aus (Regel gilt) oder an (README anpassen, OAMs übernehmen beim nächsten Lauf).

### 9 — Gelöschte Boards in der Auswahl behalten

Fällt ein `release_*`-Env weg, warnt der Lauf nur. Die gespeicherte HW-ID ist dann kein Wert der Aufzählung mehr; ETS setzt
„nicht gewählt", bei `hide` setzt der nächste Download die Einstellungen zurück. Vorschlag: Eintrag „(nicht mehr unterstützt)".

### 10 — PSRAM-Pins ESP32

ETS reserviert CS1 (S3) nur mit `BOARD_HAS_PSRAM`, der Header auch bei `CONFIG_SPIRAM`. CS/CLK des klassischen ESP32 mit PSRAM
(sdkconfig 16/17, Annahme, an den Boards nicht geprüft) fehlen auf beiden Seiten. Mit den Boards abgleichen.

### 11 — Unbekannte Attribute im Manifest melden

Nur InfoImage, Conflicts, Use und BoardTable prüfen ihre Attribute. Ein Tippfehler in `<Page>`, `<Capability>`, `<Value>` fällt
still auf den Standard. `prefix` landet in JS-Namen und C-Makros, wird aber nicht geprüft.

### 12 — CI ausbauen

Heute prüft die CI nur, ob die committeten Ausgaben den erzeugten entsprechen. Fehlt: XSD-Prüfung, Producer-Lauf, Kompilieren
von `HardwareProfileData.h`, ES3-Prüfung der Scripts, die Pfade `ids="index"` und `hide`, Tests für Vorlagen, QR, PNG und
Konfliktprüfung im Repo.

### 13 — Windows PowerShell 5.1: CI-Lauf nach dem Push prüfen

Der aktuelle Stand lief nur unter PowerShell 7 (macOS); unter 5.1 ist er nicht belegt. Die CI läuft unter 5.1; nach dem Push
das Ergebnis prüfen.

### 14 — Zweites Hardware-Modul: beide beantworten 158/4

`-Init` kann ein zweites Modul (z. B. `HWP2`) anlegen; beide Module beantworten die Geräteabfrage 158/4, es antwortet das
erste. 158/4 bleibt in OGM-HardwareConfig (Entscheidung 2026-11-16), deshalb: `-Init` lehnt ein zweites Modul ab.

### 15 — Doppelte Tabellen QUICKSTART/README

QUICKSTART „Was man setzen kann" wiederholt Tabellen des README; dort lief schon eine Zeile auseinander (Rückfall auf
`DEVICE_ID`). Entscheiden: Übersicht im QUICKSTART nur mit Verweisen, oder so lassen und bei jeder Änderung beide pflegen.

### 16 — Port-Listen verschiedener Envs einer HW-ID

Weichen die Port-Listen zweier Envs derselben HW-ID ab, warnt der Lauf nur (Relais, URL, Text, MCU stoppen). ETS bietet dann
die Ports von Env A für die Firmware von Env B an. Vor dem Umstellen auf Fehler prüfen, welche OAMs das heute auslösen.

### 17 — Sortierung ordinal

`Sort-Object` auf Zeichenketten kann unter 5.1 (NLS) und 7 (ICU) anders sortieren; dann widersprechen sich `-Check` lokal und
in der CI. Ordinal vergleichen.

### 18 — `-Init` schreibt `order="hwid"`

Standard ist `manifest`; die Festlegung ist „nach HW-ID sortieren". Neue OAMs sollen es ohne Zutun bekommen.

### 19 — Header: Warnungen und Relais-Prüfung

`HardwarePorts.h` warnt mit `-Wextra` (`-Wtype-limits`) auf Boards ohne Relais; Relais-GPIOs haben kein static_assert wie die
Ports.

### 20 — BoardTable, Entwickleransicht und op:config schlanker

`NEOHW_table_EffectsOff` 9 073 Bytes, fast nur Nullen; Entwickleransicht 191 KB (nur Dev); Demo erzeugt 133 op:config, nutzt 30.

### 21 — Laufzeit

Demo 9 s, NeoPixel 19 s je Lauf; je Env mehrere Präprozessorläufe (Identität, Hauptlauf, BoardTable). Ein Lauf je Env oder ein
Cache über die Eingänge.

### 22 — Manifest-XSD

Für Vervollständigung im Editor und eine Prüfung vor dem Lauf.

### 23 — Feste Texte übersetzbar machen

„Nicht gewählt", „aus/ein", „nicht verwendet", Konfliktmeldungen, Script-Meldungen und Entwickleransicht sind fest deutsch.

### 24 — Baumtext ohne Script

Statt der ParameterCalculation eine speicherlose Aufzählung mit zwei Werten, per `<Assign>` in den vorhandenen `when`-Zweigen
gesetzt, als `TextParameterRefId`. Erst prüfen, ob ETS für `{{0}}` den Text der Aufzählung zeigt.

### 25 — `unselectedValue` und `ids="index"` entfernen

Weniger Code und Zweige, sobald kein OAM die Altpfade mehr braucht.

### 26 — Meldungen des Abfrage-Scripts sagen „Hardware“, die Seite „Gerät“

Das Script meldet „Hardware: … erkannt“ und „Hardware … ist dieser Applikation unbekannt“; Seite, Auswahl und Knopf sprechen
seit der neuen Geräteseite von „Gerät“ bzw. „Gerätetyp“. Texte angleichen (OAM-Hilfen zitieren sie).

### 27 — Render-Skripte für Badge und Glyphen-Atlas fehlen im Repo

`generator/assets/README.md` beschreibt das Erzeugen von Badge und Schrift-Atlas, das Skript dazu liegt nicht im Repo. Als
PowerShell-Skript beilegen oder das Vorgehen so beschreiben, dass es nachvollziehbar ist.
