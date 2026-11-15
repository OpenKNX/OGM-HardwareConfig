# Schnellstart: Hardware-Profil in ein OAM einbinden

Kurzweg für ein bestehendes OAM. Details zu jedem Schritt: [README](README.md). Vollständiges Beispiel:
[HardwareProfileDemo](../examples/HardwareProfileDemo). Produktiv genutzt in OAM-NeoPixel.

**Voraussetzungen**

- `lib/OGM-HardwareConfig` mit dem Generator; in der `dependencies.txt` z. B.
  `<commit> ec/feat-hw-profiler lib/OGM-HardwareConfig https://github.com/OpenKNX/OGM-HardwareConfig`.
- Jedes Board, das das OAM baut, hat im Board-Header eine `DEVICE_HW_ID` (prüfen: `-ListIds`, neue ID: `-NextId 0x21`).
- PlatformIO (`pio`) ist installiert; der Generator liest die `release_*`-Envs der `platformio.ini`.
- Das OAM nutzt OFM-ConfigTransfer (UCT), wie jede knxprod mit Modulliste.

## 1. Manifest anlegen

```
pwsh lib/OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 -Init
```

Schreibt `HardwareProfile.xml` neben die `platformio.ini`, mit freiem `moduleType` und Präfix (Standard `45` / `HWP`):

```xml
<HardwareProfile prefix="HWP" moduleType="45" text="Hardware" unselected="showAll" ids="slot">
  <Output conf="src/HardwareProfile.conf.xml" share="src/HardwareProfile.share.xml" script="src/HardwareProfile.script.js" header="include/HardwareProfileData.h" />
  <Import href="lib/OGM-HardwareConfig/generator/capabilities/Common.caps.xml" />
  <Boards platformio="release_*" />
</HardwareProfile>
```

Envs ohne Board (Test, native) kommen nach `exclude`, z. B. `<Boards platformio="release_*" exclude="release_native_*" />`.
`unselected="showAll"` bei einem bestehenden OAM so lassen (sonst setzt ein Download vor der Hardware-Wahl Werte zurück).

## 2. Applikations-XML

`-Init` gibt die Zeilen aus, z. B.:

```xml
<op:config href="HardwareProfile.conf.xml" />
<op:define prefix="HWP" ModuleType="45" configTransferName="Hardware" share="HardwareProfile.share.xml" />
<!-- in <generate><Dynamic>: -->
<op:include href="HardwareProfile.share.xml" xpath="//ApplicationProgram/Dynamic/*" prefix="HWP" />
```

Das bindet die Seite als eigenen Kanal „Hardware“ ein. Soll sie im OpenKNX-Kanal stehen:
[README, Applikations-XML](README.md#3-applikations-xml).

Hat das OAM ein Hauptmodul, bekommt `op:define` zusätzlich `isSubmoduleOf="<Präfix>"` (kein eigenes Kontrollkästchen
unter „Module“). Hardwareabhängige Einstellungen nur über Feature-Flags ein- und ausblenden:

```xml
<choose ParamRefId="%HWP_SelectRef%">
  <when test="%HWP_CAP_Wifi%"> ... nur auf Geräten mit WLAN ... </when>
</choose>
```

**Neue Applikationsversion** mit `ReplacesVersionsDownTo`, sonst behandelt ETS den neuen Inhalt als dieselbe Version.

## 3. Build

Den Generator vor dem OpenKNXproducer aufrufen, z. B. in `scripts/Build-Release.ps1`:

```powershell
$global:LASTEXITCODE = 0
& lib/OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 -Manifest HardwareProfile.xml
if ($global:LASTEXITCODE -ne 0) { Write-Host "Hardware generation failed!" -ForegroundColor Red; exit 1 }
```

- `HardwareProfile.xml` und `HardwareProfile.slots` **committen** (die Slot-Datei hält die Parameter-IDs je Board fest).
- Die übrigen Ausgaben erzeugt der Build. Entweder in die `.gitignore` (wie NeoPixel) oder committen und in der CI
  `-Check` laufen lassen (wie die Demo). Ein `pio run` allein erzeugt sie nicht: nach einem Clean erst das Build-Skript.

```
# .gitignore
src/HardwareProfile.conf.xml
src/HardwareProfile.share.xml
src/HardwareProfile.script.js
include/HardwareProfileData.h
src/Baggages/HWPInfo/          # nur mit <InfoImage>
```

## 4. Firmware

```cpp
#include "HardwareProfileData.h"

// Geräteabfrage (Button in ETS, Function Property 158/4)
bool MyModule::processFunctionProperty(uint8_t objectIndex, uint8_t propertyId, uint8_t length, uint8_t *data,
                                       uint8_t *resultData, uint8_t &resultLength)
{
    if (HardwareProfile::answerQuery(objectIndex, propertyId, resultData, resultLength))
        return true;
    return false;
}

// Hardwareabhängige Parameter nur lesen, wenn ETS dieses Board gewählt hat
if (HardwareProfile::checkSelection(ParamHWP_HardwareSelect) == HardwareProfile::Selection::Match)
{
    ...
}
```

`checkSelection` liefert `NotSelected`, `Match` oder `Other` (andere Hardware gewählt als die der Firmware).

## 5. Prüfen

1. Generator zweimal laufen lassen: der zweite Lauf meldet „unverändert“ (`-Check` prüft ohne zu schreiben).
2. knxprod bauen und im [knxprodviewer](https://tools.openknx.de/knxprodviewer/) die Seite „Gerät“ ansehen: Auswahl,
   ein- und ausgeblendete Einstellungen je Board.
3. In ETS: App-Update aus der alten Version, physikalische Adresse programmieren, andere Seite und zurück, „Vom Gerät lesen“
   (oder den Gerätetyp von Hand wählen), Download.

## Was man setzen kann

**Pflicht ist nur:** `DEVICE_HW_ID` im Board-Header, mindestens zwei Boards, und `moduleType`, sobald `<Output share>`
gesetzt ist. Alles andere hat einen Standard oder fällt weg, wenn es fehlt. Das Manifest aus `-Init` läuft so durch,
auch ohne `<Import>` und ohne `header`.

### Manifest: Attribute der Wurzel `<HardwareProfile>`

| Attribut | Wirkung | Ohne |
|---|---|---|
| `prefix` | Modulpräfix (`%HWP_…%`, `ParamHWP_…`) | `HWP` |
| `moduleType` | `%TT%` des ETS-Moduls (1..99) | Pflicht mit `<Output share>` |
| `text` | Name des Moduls | „Hardware“ |
| `unselected` | `showAll`: „Nicht gewählt“ zeigt alles · `hide`: blendet alles Hardwareabhängige aus | `showAll` |
| `unselectedValue` | Wert von „Nicht gewählt“ | 0 |
| `order` | `manifest` oder `hwid` (Reihenfolge der Auswahlliste) | `manifest` |
| `ids` | `slot` (IDs je Board fest, Slot-Datei) oder `index` (nur Bestands-OAMs) | `slot` |
| `portManualValue`, `portNoneValue` | Port-Werte „Manuell“ / „kein Port“ (nur zusammen) | kein `signalGpio` im Header |

### Manifest: Elemente

| Element | Wirkung | Ohne |
|---|---|---|
| `<Output conf share script header>` | erzeugte Dateien (`share` braucht `script`) | die fehlende Datei entsteht nicht (ohne `conf` keine Feature-Flags, ohne `share` kein ETS-Modul, ohne `header` kein Firmware-Header) |
| `<Import href="…/Common.caps.xml">` | Standard-Fähigkeiten: TP, LAN, WLAN, Display, RTC, SD, … | nur `ThirdParty` und die eigenen |
| `<Capability>`, `<Value>` | eigene Fähigkeit (`#if`-Ausdruck) / Zahl, als Feature-Flag nutzbar | keine eigenen |
| `<Boards platformio exclude>`, `<Board define flags>` | welche Boards in der Auswahl stehen | Pflicht (mindestens zwei Boards) |
| `<Page>`, `<InfoImage>` (`<Logo>`), `<Notice>` | eigene Seite „Gerät“ mit Gerätekarte (Logo, Badge, eigenes Bild oder keines je Board), QR-Code, Hinweisen, Schritt-Bild | Auswahl, Abfrage-Knopf und Fähigkeiten-Übersicht ohne eigene Seite |
| `<GpioRole>` | GPIO-Auswahlfelder aus den Pin-Makros der Boards | keine |
| `<Ports board use excludeRelayPins max>` | Teilmenge der `HW_PORT_*` je Board | alle beschriebenen Ports |
| `<ReservedPins macros>` | Pins, die die Applikation nie anbietet / als reserviert meldet | jeder Pin erlaubt |
| `<Conflicts>` (`reserved="true"`) | GPIO-Konfliktprüfung in ETS (+ reservierte Pins, `isReservedGpio`) | keine Prüfung, Ausgaben unverändert |
| `<BoardTable name header scan>` | Zahlen-Tabelle je Board im ETS-Skript (`<Prefix>_table_<name>`) aus Makros eines OAM-Headers mit den Build-Flags der Envs | keine Tabelle, Ausgaben unverändert |
| `<Generate template output>` | eigene Dateien aus Vorlagen (z. B. Port-Parameter je Board) | keine |

### Board-Header

| Makro | Wirkung | Ohne |
|---|---|---|
| `DEVICE_HW_ID` | Identität in ETS und Firmware | Pflicht (Abbruch) |
| `DEVICE_ID`, `DEVICE_NAME` | Name in der Auswahlliste | Pflicht (Abbruch), `DEVICE_ID` nur aus a-z A-Z 0-9 _ - |
| `HW_INFO_TEXT`, `HW_INFO_URL` | Text und QR-Code der Gerätekarte | `<Page infoDefault>`, kein QR-Code |
| `DEVICE_THIRD_PARTY` | Drittanbieter-Badge und `<Notice>` | OpenKNX-Logo |
| `HW_PORT_COUNT`, `HW_PORT_<n>_GPIO`, `HW_PORT_<n>_LABEL` | Ports des Boards | keine Ports (Label ohne Angabe: „Port n“) |
| `HW_RELAY_COUNT`, `HW_RELAY_<n>_GPIO`, `HW_RELAY_<n>_LABEL` | fest verdrahtete Relais | keine |

Details zu jeder Zeile: [README](README.md#manifest), [Hardware-Seite](README.md#hardware-seite-gerätekarte),
[Ports](README.md#ports-hw_port_-im-board-header), [Port-Auswahl](README.md#port-auswahl-in-der-firmware),
[Relais](README.md#relais-hw_relay_-im-board-header), [GPIO-Konflikte](README.md#gpio-konflikte-conflicts),
[Board-Tabellen](README.md#board-tabellen-boardtable), [Reservierte GPIOs](README.md#reservierte-gpios-conflicts-reservedtrue), [Vorlagen](README.md#vorlagen-bausteine).

### Erzeugt, aber nicht verwendet

- **Feature-Flags nicht in der Applikations-XML benutzt:** ETS zeigt die Auswahl, blendet aber nichts aus.
- **Header nicht in der Firmware eingebunden** (kein `answerQuery`): die Firmware läuft wie bisher; „Vom Gerät lesen“
  endet in ETS mit einem Zeitüberlauf.
- **`checkSelection` nicht aufgerufen:** keine Prüfung, ob ETS die passende Hardware gewählt hat. `signalGpio` und
  `relaySignalGpio` prüfen die Auswahl selbst.

### Später ändern

- **Hinzufügen** (Board, Fähigkeit, Wert, Port) geht jederzeit: neue Einträge werden angehängt, dann neue
  Applikationsversion.
- **Eine Fähigkeit oder einen Wert entfernen,** nachdem die Slot-Datei ihn kennt, bricht den Lauf ab: ausgelieferte
  Firmware sendet die Bits der Geräteabfrage nach Position. Den Eintrag stehen lassen (er darf nie wahr sein). Das gilt
  auch für das Weglassen von `<Import>` nach dem ersten Lauf.
- Mit `<Import>` **und** eigenen Fähigkeiten verschiebt ein neuer Eintrag im Paket die eigenen Bits: der Lauf bricht ab.
- Ein entferntes Board behält seinen Slot (`removed` in der Slot-Datei), die übrigen IDs bleiben.

## Nicht tun

- Erzeugte Dateien von Hand ändern, Slot-Nummern in `HardwareProfile.slots` ändern, die `DEVICE_HW_ID` eines
  ausgelieferten Boards ändern (ETS verliert beim Update die Werte).
- In der Firmware Port- oder Pin-Parameter lesen, solange die Auswahl nicht das eigene Board ist.
- OAM-Spezifisches in OGM-HardwareConfig eintragen: alles Eigene gehört ins Manifest des OAM.
