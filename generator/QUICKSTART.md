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

Schreibt `HardwareProfile.xml` neben die `platformio.ini`, mit freiem `moduleType` und Präfix (Standard `45` / `HWP`).
Aktiv sind nur die Teile, die jedes OAM braucht:

```xml
<HardwareProfile prefix="HWP" moduleType="45" text="Gerät" unselected="showAll">
  <Output conf="src/HardwareProfile.conf.xml" share="src/HardwareProfile.share.xml" script="src/HardwareProfile.script.js" header="include/HardwareProfileData.h" />
  <Import href="lib/OGM-HardwareConfig/generator/capabilities/Common.caps.xml" />
  <Page text="Gerät" icon="memory" />
  <InfoImage style="card" />
  <Notice when="ThirdParty" title="Hardware eines Drittanbieters. ..." />
  <Boards platformio="release_*" />
  <!-- danach jede weitere Einstellung als auskommentiertes Beispiel -->
</HardwareProfile>
```

- `<Page>` gibt Baumtext und Icon der Seite vor, alle anderen Texte haben einen Standard. Ohne `<Page>` heißt die Seite
  „Geräteprofil“ (Zahnrad-Icon), hat keine Gerätekarte und listet alle Fähigkeiten auf.
- `<InfoImage>` zeigt die Gerätekarte (`DEVICE_NAME`, Logo aus `HW_INFO_LOGO` bzw. OpenKNX-Logo, Stempel „Drittanbieter“,
  `HW_INFO_TEXT` + `HW_INFO_TEXT2`, QR-Code aus `HW_INFO_URL` mit „Geräteinfo“ darunter),
  `<Notice>` den Hinweis für Drittanbieter-Boards.
- Die Liste der Fähigkeiten und Werte je Board ist eine **Entwickler-Sache**: das Beispiel „DEVELOPER VIEW“ (`<Page dev features>`)
  gehört nur in die Dev-Applikation. Der Generator unterscheidet Dev und Release nicht; er schreibt die Datei der
  Entwickleransicht immer, nur die Dev-Applikations-XML bindet sie ein. Teilen sich Dev und Release eine Vorlage
  (`<generate base>`), steht die Entwickleransicht nicht in der gemeinsamen Vorlage.
- Beispiele stehen auskommentiert im Manifest (Seitentexte, Gerätekarte, eigene Fähigkeit und Wert, Boards, Ports,
  reservierte Pins, GPIO-Rollen, Info-LEDs, Fixes, Filter, Hinweise je Wert, GPIO-Konflikte, Vorlagen). Zum Benutzen die
  Kommentarzeile über und unter den Elementzeilen löschen. Die Vorlage dafür ist `generator/init/HardwareProfile.examples.xml`.

Envs ohne Board (Test, native) kommen nach `exclude`, z. B. `<Boards platformio="release_*" exclude="release_native_*" />`.
`unselected="showAll"` bei einem bestehenden OAM so lassen (sonst setzt ein Download vor der Hardware-Wahl Werte zurück).

### `-Init` noch einmal (Manifest neu anlegen)

`-Init` legt nur ein neues Manifest an. Für einen zweiten Lauf, z. B. um die Beispiele einer neueren Generator-Version zu
bekommen:

1. `HardwareProfile.xml` löschen (oder umbenennen und eigene Einträge danach übernehmen). `HardwareProfile.slots` nur
   löschen, solange keine knxprod mit dem Hardware-Modul ausgeliefert oder in ETS importiert ist: die Slot-Datei hält die
   Board-Nummern der Parameter-IDs, die Bits der Geräteabfrage, die Slots der `<Filters>`-Regeln und die `ets`-Zeilen der
   Versionswache fest.
2. Das `op:define` des Hardware-Moduls in jeder Applikations-XML vorübergehend auskommentieren. Sonst bricht `-Init` ab
   („already includes a hardware module“); ist nur die erzeugte Share-Datei weg, wählt `-Init` einen neuen Präfix und
   ModuleType (`HWP2` und den nächsten freien ModuleType), weil es die alten als belegt sieht.
3. `-Init` laufen lassen, danach das `op:define` wieder aktivieren und die gewünschten Beispiele einschalten.

Lag das Manifest in `src/`: `-Init` schreibt das neue immer in den Projektordner (neben die `platformio.ini`). Vor dem
nächsten Lauf die behaltene Slot-Datei daneben legen (`git mv src/HardwareProfile.slots HardwareProfile.slots`) oder das neue
Manifest nach `src/` verschieben (Pfade darin relativ zum Manifest anpassen, README „Regeln“); sonst legt der Lauf eine neue
Slot-Datei an und die Board-Nummern der Parameter-IDs können sich verschieben.

### Beispiel aktivieren: Info-LEDs

Die Seite „Info LEDs“ von OGM-Common zeigt dann je Gerät nur die Zeilen der LEDs, die das Board hat, mit dem Label aus dem
Board-Header („Info 1 (rot, links)“); ohne Auswahl alle drei.

1. **Manifest:** beim Beispiel `<PartRows source="lib/OGM-Common/src/InfoLed.part.xml" …>` die Zeile `<!--` darüber und die
   Zeile `-->` darunter löschen. Danach steht dort aktiv:

   ```xml
   <PartRows source="lib/OGM-Common/src/InfoLed.part.xml" output="src/HardwareProfile.infoled.gen.xml">
     <Row ref="%AID%_UP-%TT%00020_R-%TT%0002001" expr="defined(INFO1_LED_PIN) || defined(INFO_LED_PIN) || defined(INFO1_LED_LABEL)" label="INFO1_LED_LABEL" />
     <Row ref="%AID%_UP-%TT%00021_R-%TT%0002101" expr="defined(INFO2_LED_PIN) || defined(INFO2_LED_LABEL)" label="INFO2_LED_LABEL" />
     <Row ref="%AID%_UP-%TT%00022_R-%TT%0002201" expr="defined(INFO3_LED_PIN) || defined(INFO3_LED_LABEL)" label="INFO3_LED_LABEL" />
   </PartRows>
   ```

   Die Bedingung fragt auch das Label ab: Boards, deren `LED_INIT` die LEDs anlegt (REG2 ESP-S3-Pico), haben keine
   `INFO<n>_LED_PIN`, nur `INFO<n>_LED_LABEL`.
2. **Jede Applikations-XML** (Dev und Release): vor dem `op:define` von BASE diese Zeile (Pfad relativ zu `lib/OGM-Common/src`):

   ```xml
   <op:config name="%BASE_InfoLedPart%" value="../../../src/HardwareProfile.infoled.gen.xml" />
   ```

   Braucht ein OGM-Common, dessen `Common.share.xml` die Seite über `%BASE_InfoLedPart%` einbindet; ein älteres übergeht das
   `op:config` und zeigt die Originalseite.
3. **Seite „Gerät“ eingebunden** (Schritt 2): die Zeilen hängen von der Geräteauswahl ab, ohne die Seite bleiben immer alle drei.
4. **Bauen** (Schritt 3) und im Viewer je Gerät die Seite „Info LEDs“ ansehen. Neue Applikationsversion nicht vergessen.

Die anderen Beispiele schaltet man genauso ein (Kommentarzeilen löschen); was sie in der Applikations-XML brauchen, steht im
Kommentar über dem Beispiel.

## 2. Applikations-XML

`-Init` gibt die Zeilen aus, z. B.:

```xml
<op:config href="HardwareProfile.conf.xml" />
<op:define prefix="HWP" ModuleType="45" configTransferName="Gerät" share="HardwareProfile.share.xml" />
<!-- in <generate><Dynamic>: -->
<op:include href="HardwareProfile.share.xml" xpath="//ApplicationProgram/Dynamic/*" prefix="HWP" />
```

Das bindet die Seite als eigenen Kanal „Gerät“ (`text`) ein. Baut die Applikation den OpenKNX-Kanal selbst auf (eigener
`<Channel … Number="BASE">` in `<Dynamic>` mit den Seiten aus `Common.share.xml`, wie IP-Interface und NeoPixel), kann die
Seite in diesem Kanal stehen, z. B. direkt nach dem Include der Seite „Allgemein“ (zeigt `-Init` ebenfalls):

```xml
<op:include href="HardwareProfile.share.xml" xpath="//ApplicationProgram/Dynamic/Channel/ParameterBlock[@Name='Profile']" prefix="HWP" />
```

Das `op:define` gehört in **jede** Applikations-XML (Dev und Release), die die Seite einbindet, sonst bekommt die Seite die
Nummern eines anderen Moduls (Producer: „duplicate Id“, „referenced but not defined“, „HWP_detectHardware is missing“).
Mehr dazu: [README, Applikations-XML](README.md#3-applikations-xml).

Hat das OAM ein Hauptmodul, bekommt `op:define` zusätzlich `isSubmoduleOf="<Präfix>"` (kein eigenes Kontrollkästchen
unter „Module“). Hardwareabhängige Einstellungen nur über Feature-Flags ein- und ausblenden:

```xml
<choose ParamRefId="%HWP_SelectRef%">
  <when test="%HWP_CAP_Wifi%"> ... nur auf Geräten mit WLAN ... </when>
</choose>
```

**Neue Applikationsversion** mit `ReplacesVersionsDownTo`, sonst behandelt ETS den neuen Inhalt als dieselbe Version.

## 3. Build

Mit einem `HardwareProfile.xml` im Projektordner (sonst in `src/`) ruft OGM-Common den Generator im Release-Build selbst
auf (`Build-Release-Preprocess.ps1`, vor dem OpenKNXproducer, bei `compileWith` = `openknxproducer`, nicht mit `-SkipKnxprod`): kein Aufruf im `scripts/Build-Release.ps1` der OAM nötig.
Fehlt der Generator in `lib/OGM-HardwareConfig`, bricht der Build ab. Eigene Parameter für den Generator: OGM-Common,
`doc/Build-and-release-environment.md`.

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
| `text` | Name des Moduls | „Gerät“ |
| `unselected` | `showAll`: „Nicht gewählt“ zeigt alles · `hide`: blendet alles Hardwareabhängige aus | `showAll` |
| `order` | `hwid` oder `manifest` (Reihenfolge der Auswahlliste) | `hwid` |
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
| `<Fixes output>`, `<Fix name capability ref value show>` | Einstellung eines anderen Moduls je Fähigkeit fest setzen: nur lesbar, ausgeblendet oder änderbar | keine Datei, Ausgaben unverändert |
| `<Generate template output>` | eigene Dateien aus Vorlagen (z. B. Port-Parameter je Board) | keine |

### Board-Header

| Makro | Wirkung | Ohne |
|---|---|---|
| `DEVICE_HW_ID` | Identität in ETS und Firmware | Pflicht (Abbruch) |
| `DEVICE_ID`, `DEVICE_NAME` | Name in der Auswahlliste | Pflicht (Abbruch), `DEVICE_ID` nur aus a-z A-Z 0-9 _ - |
| `HW_INFO_TEXT`, `HW_INFO_TEXT2`, `HW_INFO_URL` | Text (zwei Teile, je höchstens 255 Zeichen) und QR-Code der Gerätekarte | `<Page infoDefault>`, kein zweiter Teil, kein QR-Code |
| `HW_INFO_LOGO` | Logo der Gerätekarte, Pfad wie bei `#include` (z. B. `"HardwareConfig/Others/Shelly/logo.png"`), höchstens 100x74 px | OpenKNX-Logo, bei Drittanbietern der Stempel an seiner Stelle |
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

- **Hinzufügen** (Board, Fähigkeit, Wert, Port) geht jederzeit, auch im Paket `Common.caps.xml`: neue Einträge bekommen
  das nächste freie Bit bzw. den nächsten Slot, dann neue Applikationsversion (der Lauf warnt bei jedem Lauf, bis sie steigt).
- **Eine Fähigkeit oder einen Wert entfernen,** nachdem die Slot-Datei ihn kennt, bricht den Lauf ab: ausgelieferte
  Firmware sendet die Bits der Geräteabfrage nach Position. Den Eintrag stehen lassen (er darf nie wahr sein). Das gilt
  auch für das Weglassen von `<Import>` nach dem ersten Lauf.
- Ein entferntes Board behält seinen Slot (`removed` in der Slot-Datei), die übrigen IDs bleiben.

## Nicht tun

- Erzeugte Dateien von Hand ändern, Slot-Nummern in `HardwareProfile.slots` ändern, die `DEVICE_HW_ID` eines
  ausgelieferten Boards ändern (ETS verliert beim Update die Werte).
- In der Firmware Port- oder Pin-Parameter lesen, solange die Auswahl nicht das eigene Board ist.
- OAM-Spezifisches in OGM-HardwareConfig eintragen: alles Eigene gehört ins Manifest des OAM.
