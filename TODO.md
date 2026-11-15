# ToDo — OGM-HardwareConfig

**Die eine Liste.** Alles Offene zum Hardware-Generator und den Board-Headern steht hier. Erledigtes wird gelöscht,
nicht abgehakt — was hier steht, steht noch aus.

Stand: **2026-11-16** (Branch `ec/feat-hw-profiler`) · **4 offene Punkte**. Nummeriert nach Priorität; kommt ein
Punkt dazu oder fällt einer weg, wird neu nummeriert.

Regeln: Der Generator gilt für alle OAMs (keine produktspezifischen Sonderwege). Eine Änderung darf bestehende OAMs nicht
brechen: gleiche Parameter-IDs, gleiches Speicherlayout, gleiche Bit-Reihenfolge der Geräteabfrage; ändert sich der
ETS-Inhalt eines OAM, braucht es dort einen Versions-Bump. Skripte bleiben PowerShell 5.1 und ASCII.

## Übersicht, sortiert

Prio 1 = vor dem Push/Merge des Branches, 2 = bald, 3 = nur bei Bedarf. Aufwand: S = Stunden, M = 1-2 Tage, L = mehr.

| Nr | Thema | Prio | Risiko | Aufwand | Stand |
|---|---|---|---|---|---|
| 1 | Calculations, Baumtext und Ladezeit in ETS 5 und 6 messen | 1 | hoch | M | NeoPixel Dev 2.6 gebaut, wartet auf ETS |
| 2 | PSRAM ESP32: ETS und Firmware-Header reservieren verschieden; PSRAM-Suche an GPIO 16/17 | 1 | hoch | S-M | am Board messen |
| 3 | Windows PowerShell 5.1: CI-Lauf nach dem Push prüfen, dann CI ausbauen | 2 | mittel | S / M | wartet auf Push |
| 4 | Größe und Laufzeit: Typen, tote GPIO-Parameter, BoardTable, Präprozessorläufe | 3 | mittel | M | nur, wenn 1 es verlangt |

### 1 — Calculations, Baumtext und Ladezeit in ETS 5 und 6 messen

Die GPIO-Konfliktprüfung und der Baumtext liefen bisher nur im Viewer. Gemessen wird der heutige
Stand; eine Variante ohne `<Conflicts>` nur, wenn Öffnen oder Ändern spürbar langsam ist.
- **Konfliktprüfung:** zwei Strips auf denselben Port → Meldung erscheint; einen umstellen → Meldung verschwindet. Zeit für das
  Öffnen des Parameterdialogs und eine Port-Änderung (ETS6 auch über die Dauer von `device_set_parameter` im KNX-MCP).
- **Baumtext:** Auswahl setzen und auf „Nicht gewählt" zurück; „Vom Gerät lesen" setzt die Auswahl; Projekt schließen und
  öffnen; Applikation aktualisieren (Dev 2.0 → 2.7). Jedes Mal muss der Baum „Gerät" bzw. „Gerät (nicht gewählt)" zeigen.
  Zeigt ETS den Text nicht, Ersatz ohne Script: speicherlose Aufzählung mit zwei Werten, per `<Assign>` gesetzt.
- **Update:** die beiden knxprods aus `examples/HardwareProfileDemo/scripts/Test-DemoUpdate.ps1` (N und N+1): Gerät mit N
  einfügen, Werte setzen (Auswahl, GPIO-Rollen, Schalter, Ausgänge), N+1 importieren, „Aktualisieren“; jeder Wert außer denen
  des entfernten Boards muss bleiben. Bestätigt die Regel, nach der das Skript vergleicht.
- ETS5 per Hand (Screenshot), ETS6 über KNX-MCP im Projekt TEST-KNX; die knxprod liegt nicht im Katalog (dort bis Dev 2.0).

### 2 — PSRAM ESP32: ETS und Firmware-Header reservieren verschieden

Gemessen an framework-arduinoespressif32 3.3.7 (2026-11-16, aus den Dateien gelesen):
- Alle vorkompilierten sdkconfigs (esp32, esp32s3, esp32c5) setzen `CONFIG_SPIRAM 1`; `esp32-hal-psram.h` löscht es nur im
  Lib-Builder. `psramInit()` läuft deshalb bei jedem Build (`esp32-hal-misc.c:296-298`), mit oder ohne `BOARD_HAS_PSRAM`.
- Der Firmware-Header (`isReservedGpio`) zählt CS1 (S3: 26, C5: 15) bei `CONFIG_SPIRAM`, also immer; ETS
  (`$CHIP_RESERVED` Cs1) nur mit `BOARD_HAS_PSRAM` in den Build-Flags. Auf einem S3/C5 ohne das Flag bietet ETS den Pin an,
  die Firmware lehnt ihn ab.
- Klassischer ESP32: PSRAM-CS 16, -CLK 17 (`CONFIG_D0WD_PSRAM_CS_IO 16`, `CLK_IO 17`), auf keiner Seite reserviert.
  Gledopto und QuinLED nutzen GPIO 16 als LED-Daten 1, GPIO 17 als Taster, LED7 oder Ethernet-Takt.

Offen: am Board messen, ob die PSRAM-Suche ohne PSRAM die Pins belegt lässt (Spur zum Absturz in NeoPixel-TODO 2). Danach
entscheiden: beide Seiten nach dem tatsächlichen Verhalten angleichen, oder die PSRAM-Suche auf Boards ohne PSRAM abschalten.
GPIO 16 zu sperren nähme Gledopto und QuinLED den ersten LED-Port.

### 3 — Windows PowerShell 5.1: CI-Lauf nach dem Push prüfen, dann CI ausbauen

Der Stand lief nur unter PowerShell 7.6 (macOS). Unter 5.1 nicht belegt sind unter anderem: `Get-OrdinalSorted`
(`foreach` statt `@()` auf einer generischen List, die unter 7.6 wirft), `SHA256CryptoServiceProvider`, die Attributprüfung.
Danach die CI ausbauen: XSD-Prüfung, Producer-Lauf, Kompilieren von `HardwareProfileData.h` und `HardwarePorts.h` mit
`-Wextra -Werror`, ES3-Prüfung der Scripts, Tests für Vorlagen, QR, PNG und Konfliktprüfung im Repo.

### 4 — Größe und Laufzeit

Nur angehen, wenn die Messung (1) eine Ladezeit oder Größe zeigt, die stört; jede Änderung am ETS-Inhalt braucht einen Bump.
- NeoPixel: 80 Typen in `NeoPixel.hw.types.gen.xml`, laut Review 15 verschiedene Inhalte. Vorher belegen, dass ein
  Typwechsel bei gleicher Parameter-ID ein ETS-Update übersteht.
- GPIO-Parameter, ParameterRef und Typ entstehen auch für Boards ohne Pins (Demo laut Review 22 Parameter, 11 Typen,
  22 Eingänge der Konfliktprüfung); Speicherlayout (Union) prüfen.
- `NEOHW_table_EffectsOff` 9 073 Bytes, fast nur Nullen; Entwickleransicht 191 KB (nur Dev); Demo 133 op:config, 30 genutzt.
- Laufzeit Demo 9 s, NeoPixel 19 s je Lauf (NeoPixel baut zweimal je Build); je Env mehrere Präprozessorläufe.
