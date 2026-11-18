# Anwendungsfälle: so nutzt eine Applikation die Hardware-Auswahl

Kurze Rezepte. Jedes Beispiel zeigt, wo die Angabe hingehört: **Board-Header** (was die Hardware hat) →
**Manifest** `HardwareProfile.xml` (wie die Applikation es nennt) → **Applikations-XML** (was ETS zeigt) →
**Firmware** (was das Gerät tut). Präfix in allen Beispielen: `HWP`. Begriffe und Attribute: [README](README.md).

Grundregel: Die Applikation fragt nie nach einer HW-ID, sondern nur nach einer Fähigkeit oder einem Wert.
Ein neues Board braucht dann nur seinen Header-Block. Die Fälle laufen mit ETS-Bordmitteln; Script erzeugt der Generator
nur für die Geräteabfrage (Button), die GPIO-Konfliktprüfung (Fall 16) und den Seitentitel im Baum (`<Page unselectedTitle>`,
Standard an); die beiden letzten sind ParameterCalculations.

**Einstieg:** Fall 1 und 2 reichen für die meisten Applikationen. Die übrigen Fälle sind optional.
**Alle Fälle in einer knxprod:** [Demo](../examples/HardwareProfileDemo/README.md) (mit Kontexthilfe je Seite).

---

## 1. Ganzes Modul / ganzen Kanal ein- oder ausblenden

*Beispiel: Jalousie nur auf Geräten mit mindestens 2 Relais, Binäreingänge nur, wenn es welche gibt.*

```c
// Board-Header
#define HW_RELAY_COUNT 2
#define OPENKNX_BI_GPIO_COUNT 2
```
```xml
<!-- Manifest -->
<Import href="lib/OGM-HardwareConfig/generator/capabilities/Common.caps.xml" />   <!-- Wert BinaryInputs -->
<Value name="Relays" text="Relais" expr="HW_RELAY_COUNT" default="0" max="16" />
```
```xml
<!-- Applikations-XML, im <Dynamic> um den Kanal -->
<choose ParamRefId="%HWP_SelectRef%">
  <when test="%HWP_VAL_Relays_GE_2%"> <op:include ... prefix="SHC" /> </when>          <!-- Jalousie -->
</choose>
<choose ParamRefId="%HWP_SelectRef%">
  <when test="%HWP_VAL_BinaryInputs_GE_1%"> <op:include ... prefix="BI" /> </when>
</choose>
```
Firmware: Das Modul wird nur angelegt, wenn der Header es hergibt (`#if HW_RELAY_COUNT >= 2`).

## 2. Einzelne Einstellungen ein- oder ausblenden (Feature-Flag)

*Beispiel: Leistungsmessung, Gerätetemperatur, Frontbedienung.*

```c
// Board-Header (nur bei den Geräten, die es haben)
#define HW_POWER_METER        // Strom-/Leistungsmessung
#define HW_TEMP_SENSOR        // interner Temperatursensor
```
```xml
<!-- Manifest -->
<Capability name="PowerMeter"  text="Leistungsmessung"  expr="defined(HW_POWER_METER)" />
<Capability name="Temperature" text="Gerätetemperatur"  expr="defined(HW_TEMP_SENSOR)" />
```
```xml
<!-- Applikations-XML, im Modul -->
<choose ParamRefId="%HWP_SelectRef%">
  <when test="%HWP_CAP_PowerMeter%">
    <ParameterSeparator Id="%AID%_PS-nnn" Text="Leistungsmessung" UIHint="Headline" />
    <ParameterRefRef RefId="..._TotalPowerSend" />
  </when>
</choose>
```
Muss eine Einstellung auch **vor** der Hardware-Auswahl sichtbar bleiben (sonst setzt ein Download sie zurück,
z. B. der WLAN-Zugang nach einem App-Update), nimmt man `%HWP_CAP_Wifi_OR_NONE%`.

## 3. Anzahl der Kanäle je Hardware

*Beispiel: 1, 2 oder 4 Binäreingänge; OFM-Notify mit höchstens n Empfängern je Gerät.*

**a) Kanal n nur zeigen, wenn die Hardware mindestens n hat:**
```xml
<!-- Applikations-XML: je Kanal ein choose -->
<choose ParamRefId="%HWP_SelectRef%">
  <when test="%HWP_VAL_BinaryInputs_GE_3%"> ... Kanal 3 ... </when>
</choose>
```

**b) Das Modul hat schon „Verfügbare Kanäle“ (z. B. `BI_VisibleChannels`):** Wert je Board per `<Assign>` setzen,
erzeugt aus dem Manifest-Wert (Vorlage `BoardWhens.xml`):
```xml
<!-- Vorlage src/hw/Channels.xml, im Manifest: <Generate template="src/hw/Channels.xml" output="src/Channels.gen.xml" /> -->
<Block name="AssignChannels">
  <choose ParamRefId="%HWP_SelectRef%">
@@use @hw/BoardWhens.xml
@@param Body
    <Assign TargetParamRefRef="%AID%_P-..._BI_VisibleChannels" Value="{{$b.Val.BinaryInputs}}" />
@@endparam
@@enduse
  </choose>
</Block>
```
Ein Wert, den die Hardware nicht vorgibt, sondern das Projekt (z. B. Notify-Empfänger nach Flash-Größe), kommt per
`<Set board="..." value="n" />` ins Manifest statt in den Header.

## 4. Auswahlliste (Dropdown) je Hardware

*Beispiel: Relais-Anzahl: ein Gerät mit 4 Relais zeigt 0..4, eines mit 1 Relais 0..1 (oder fest 1), eines ohne Relais nichts.*

ETS kann die Einträge einer Liste nicht je Auswahl filtern. Der Generator erzeugt deshalb je Listenlänge einen Typ und
einen Parameter, alle auf **einem** Byte (Union); ETS zeigt den der gewählten Hardware. Nur ETS-Mittel, kein Script.

```xml
<!-- Vorlage src/hw/Ranges.xml (Manifest: <Generate template="src/hw/Ranges.xml" output="src/Ranges.gen.xml" />) -->
@@set $rel = @{ Value = 'Relays'; Name = 'RelayCount'; Number = '%TT%{{D5 (300 + $n)}}'; Text = 'Relais';
               ZeroText = 'keine'; Default = 'max'; UIHint = 'DropDown'; SelectRef = '%HWP_SelectRef%' }
<ParameterTypes>  @@use @hw/ValueRangeParameter.xml ($rel + @{ Part = 'Type' })         </ParameterTypes>
<Block name="Parameters">   @@use @hw/ValueRangeParameter.xml ($rel + @{ Part = 'Parameter' })    </Block>
<Block name="ParameterRefs"> @@use @hw/ValueRangeParameter.xml ($rel + @{ Part = 'ParameterRef' }) </Block>
<Block name="Choose">       @@use @hw/ValueRangeParameter.xml ($rel + @{ Part = 'Choose' })       </Block>
```
```xml
<!-- Applikations-XML -->
<Union SizeInBit="8"><Memory CodeSegment="%MID%" Offset="40" BitOffset="0" />
  <op:include href="Ranges.gen.xml" xpath="//Block[@name='Parameters']/*" /></Union>
...
<op:include href="Ranges.gen.xml" xpath="//Block[@name='Choose']/*" />
```
- Keine Wahl, sondern fester Wert (z. B. `VisibleChannels` eines Moduls = Hardware-Anzahl): `Fixed = { $true }`
  (oder nur für bestimmte n, z. B. `{ $_ -le 1 }`). Der Wert wird per `<Assign>` gesetzt und schreibgeschützt gezeigt.
- Wert 0: der Parameter ist versteckt und auf 0 gesetzt, damit ETS das Byte schreibt.
- Die Firmware liest wie immer **ein** Byte. Lauffähiges Beispiel: Demo `src/hw/Ranges.xml`.

Weitere Vorlagen:

- `ValueRangeType.xml`: ein ParameterType `0..`höchster Wert aller Boards (eine Liste für alle).
- `PortListTypes.xml` + `BoardParameter.xml`: je Board ein eigener Typ mit genau seinen Ports und ein Parameter je
  Board in einer Union; der `<choose>` zeigt den des gewählten Boards. Die Firmware liest den Wert über einen
  Träger-Parameter und `hwPortGpio()` (`HardwareConfig/Helpers/HardwarePorts.h`).

```xml
<!-- Vorlage: ParameterType 0..max des Manifest-Werts Relays -->
@@use @hw/ValueRangeType.xml @{ Name = 'RelayCount'; Value = 'Relays'; ZeroText = 'Deaktiviert'; UIHint = 'DropDown' }
```

## 5. Sensoren (Paradebeispiel Raumcontroller)

*Beispiel: Varianten mit/ohne CO2, Feuchte, Helligkeit, Präsenz.*

Nur was **fest auf der Platine** sitzt, gehört in den Header. Ein steckbarer Sensor bleibt ein Parameter der
Applikation (der Header kann ihn nicht kennen).

```c
// Board-Header, z. B. Raumcontroller Plus
#define HW_SENSOR_TEMP_HUM   // SHT4x
#define HW_SENSOR_CO2        // SCD41
#define HW_SENSOR_LUX        // VEML7700
// HW_SENSOR_PRESENCE fehlt: diese Variante hat keinen Präsenzmelder
```
```xml
<!-- Manifest -->
<Capability name="TempHum"  text="Temperatur/Feuchte" expr="defined(HW_SENSOR_TEMP_HUM)" />
<Capability name="Co2"      text="CO2"                expr="defined(HW_SENSOR_CO2)" />
<Capability name="Lux"      text="Helligkeit"         expr="defined(HW_SENSOR_LUX)" />
<Capability name="Presence" text="Präsenz"            expr="defined(HW_SENSOR_PRESENCE)" />
```
```xml
<!-- Applikations-XML: je Sensor eine Seite / ein Kanal; dazu die Logik-Eingänge, die den Sensor brauchen -->
<choose ParamRefId="%HWP_SelectRef%">
  <when test="%HWP_CAP_Co2%"> <ParameterBlock ... Text="CO2" > ... </ParameterBlock> </when>
</choose>
```
Firmware: `#ifdef HW_SENSOR_CO2` legt den Treiber an. Die Geräteabfrage meldet, welche Sensoren die Firmware hat;
weicht das von der ETS-Auswahl ab, sagt ETS es beim Abfragen.

## 6. Netzwerk: LAN, WLAN, MQTT

```xml
<!-- Manifest: Common.caps.xml bringt Lan und Wifi -->
<Import href="lib/OGM-HardwareConfig/generator/capabilities/Common.caps.xml" />
```
```xml
<!-- Applikations-XML -->
<choose ParamRefId="%HWP_SelectRef%">
  <when test="%HWP_CAP_Wifi_OR_NONE%"> ... WLAN-Seite ... </when>    <!-- auch vor der Auswahl sichtbar -->
</choose>
<choose ParamRefId="%HWP_SelectRef%">
  <when test="%HWP_NOCAP_Lan%"> ... Hinweis „kein LAN“ ... </when>
</choose>
```
MQTT ist keine Hardware: es hängt am Netzwerk (`Lan` oder `Wifi`), nicht an einem eigenen Header-Define.

## 7. Build-Varianten eines Boards

*Beispiel: Pico W mit und ohne WLAN gebaut, TP- und IP-Firmware für dieselbe Platine.*

Mehrere Envs mit derselben `DEVICE_HW_ID` werden zu einem Eintrag zusammengefasst. `merge="any"` (Standard): die
Fähigkeit gilt, wenn **eine** Variante sie hat; `merge="all"`: nur wenn **alle** sie haben. Was ein konkretes Gerät
wirklich kann, liefert die Geräteabfrage; Fähigkeiten, in denen sich die Varianten unterscheiden, meldet sie nicht als
Abweichung (jede Variante passt zum Eintrag).

## 8. Drittanbieter-Hardware

```c
#define DEVICE_THIRD_PARTY   // im Board-Block
```
Badge statt OpenKNX-Logo und `<Notice when="ThirdParty">` kommen von selbst (Fähigkeit `ThirdParty` ist eingebaut).

## 9. Firmware: Auswahl prüfen, Abfrage beantworten

```cpp
#include "HardwareProfileData.h"

uint16_t selected = ParamHWP_HardwareSelect;
if (selected != HardwareProfile::OWN_HW_ID)
    return;                                  // fremde Auswahl: keine hardwareabhängigen Parameter lesen

// Geräteabfrage (Knopf „Vom Gerät lesen“, Function Property 158/4): eine Zeile im Modul
bool MyModule::processFunctionProperty(uint8_t objectIndex, uint8_t propertyId, uint8_t length, uint8_t* data,
                                       uint8_t* resultData, uint8_t& resultLength)
{
    if (HardwareProfile::answerQuery(objectIndex, propertyId, resultData, resultLength)) return true;
    return false;
}
```

## 10. Steckmodule und zur Laufzeit erkannte Teile

*Beispiel: Raumcontroller Pro mit Steckplatz für ein Sensormodul.*

```c
#define HW_SLOT_SENSOR            // Board-Header: der Steckplatz ist da, ob ein Modul steckt, weiß nur die Firmware
```
```xml
<Capability name="SensorModule" text="Steckmodul Sensor" expr="defined(HW_SLOT_SENSOR)" switch="true" runtime="true" />
```
Die Hardware-Seite zeigt einen Schalter „aktiv“; die Geräteabfrage stellt ihn. `runtime="true"` nimmt das Bit aus `OWN_CAPS`
(sonst meldete jedes Board mit Steckplatz „Modul vorhanden“), die Firmware setzt es:
`answerQuery(objectIndex, propertyId, resultData, resultLength, moduleFound ? (1u << HardwareProfile::CapSensorModule) : 0)`.

## 11. Grenzen nach Ressourcen (Flash, PSRAM, RAM)

*Beispiel: weniger Kanäle oder LEDs auf Geräten ohne PSRAM.*

```c
#define DEVICE_FLASH_SIZE_MB 8    // gibt es schon (Common.caps.xml: Wert FlashMB)
#define DEVICE_PSRAM_SIZE_MB 2    // Vorschlag, gleiches Schema
```
```xml
<Value name="PsramMB" text="PSRAM" expr="DEVICE_PSRAM_SIZE_MB" default="0" max="16" unit="MB" query="false" />
<Capability name="LargeFlash" text="mind. 8 MB Flash" expr="defined(DEVICE_FLASH_SIZE_MB) &amp;&amp; DEVICE_FLASH_SIZE_MB >= 8" />
```
In ETS dann `%HWP_VAL_PsramMB_GE_2%` oder `%HWP_CAP_LargeFlash%`; eine Obergrenze je Gerät als Liste 0..n (Fall 4).

## 12. Standardwert je Hardware

`ValueRangeParameter.xml` mit `Default = 'max'`: der Wert steht beim ersten Wählen auf dem Wert der Hardware (z. B. alle
Relais genutzt). Für andere Standardwerte je Board: `BoardParameter.xml` (ein Parameter je Board, `Value` mit `$b`).

## 13. Falsche Auswahl erkennen (optional anzeigen)

```cpp
switch (HardwareProfile::checkSelection(ParamHWP_HardwareSelect))
{
    case HardwareProfile::Selection::Match: /* hardwareabhängige Parameter lesen */ break;
    case HardwareProfile::Selection::Other: /* optional: Log, Diagnose-KO, Info-LED */ break;
    default: break;                                                     // NotSelected
}
```

## 14. Kommunikationsobjekte je Hardware

Ein `<ComObjectRefRef>` im selben `<when>` wie die Einstellung (z. B. KO „Leistung“ nur mit `%HWP_CAP_PowerMeter%`). Die
KO-Nummer bleibt gleich. Ob die ETS die Gruppenadressen eines KOs behält, das nach einem Hardware-Wechsel
ausgeblendet ist, ist nicht geprüft: nach dem Wechsel die Verknüpfungen kontrollieren.

## 15. Prüfen und CI

`Build-HardwareProfile.ps1 -Check` (Exit-Code 1 = erzeugte Dateien veraltet), `-ListIds` (Header-Regeln, doppelte IDs),
`-NextId 0x25` (nächste freie ID). Die GitHub Action des Repos führt `-ListIds` und `-Check` bei jedem Commit aus.

## 16. Port-Auswahl und GPIO-Konflikte

*Beispiel: zwei Ausgänge wählen je einen Port der Hardware oder „Manuell“ mit einem GPIO; ein fest verdrahtetes Relais
belegt seinen Pin immer. Zwei Einstellungen auf demselben GPIO zeigen in ETS je eine Fehlermeldung, die Firmware löst
dieselben Werte mit denselben Regeln auf.* Hier ist ein Script nötig: eine reine `choose`-Lösung bräuchte je Nutzung eine `<when>` für jede
Kombination aus Board und den Werten aller anderen Nutzungen.

```c
// Board-Header
#define HW_PORT_COUNT 2
#define HW_PORT_1_GPIO 4
#define HW_PORT_2_GPIO 6
#define HW_RELAY_COUNT 1          // Relais 1 fest auf GPIO 12
#define HW_RELAY_1_GPIO 12
```
```xml
<!-- Manifest: Port-Werte einmal (ETS-Prüfung und Firmware-Header), dann die Prüfung -->
<HardwareProfile ... portManualValue="10" portNoneValue="15">
  <Ports board="*" excludeRelayPins="true" max="10" />
  <Conflicts output="src/MyApp.conflicts.gen.xml" number="900">
    <Param name="Outputs" ref="%AID%_P-%TT%00023_R-%TT%0002301" />
    <Param name="Signal1" ref="%AID%_P-%TT%00024_R-%TT%0002401" />
    <Use name="Out1Data" text="Ausgang 1 Daten" when="Outputs >= 1"
         port="%AID%_UP-%TT%{{D5 (1000 + $b.Slot)}}_R-%TT%{{D5 (1000 + $b.Slot)}}01">
      <Manual when="Signal1 in 1 2" ref="%AID%_P-%TT%00027_R-%TT%0002701" />   <!-- SPI: MOSI-GPIO -->
      <Manual ref="%AID%_P-%TT%00026_R-%TT%0002601" />                         <!-- sonst Daten-GPIO -->
    </Use>
    <Use name="Out1Clock" text="Ausgang 1 Takt" when="Outputs >= 1 and Signal1 in 1 2" port="...">
      <Manual ref="%AID%_P-%TT%00028_R-%TT%0002801" />
    </Use>
    <Use name="Relay1" text="Relais 1" wiredRelay="1" port="..." />   <!-- Port nur auf Boards ohne festes Relais 1 -->
  </Conflicts>
</HardwareProfile>
```
```xml
<!-- Applikations-XML: die Teile in das eigene Modul (%TT%) einbinden -->
<op:include href="MyApp.conflicts.gen.xml" xpath="//ApplicationProgram/Static/ParameterTypes/ParameterType" />  <!-- in ParameterTypes -->
<op:include href="MyApp.conflicts.gen.xml" xpath="//Block[@name='Parameters']/*" />                            <!-- in Parameters -->
<op:include href="MyApp.conflicts.gen.xml" xpath="//Block[@name='ParameterRefs']/*" />                         <!-- in ParameterRefs -->
<op:include href="MyApp.conflicts.gen.xml" xpath="//Block[@name='Calculation']/*" />                           <!-- in ParameterCalculations -->
<!-- unter der Port-Auswahl, auf jeder Seite: -->
<op:include href="MyApp.conflicts.gen.xml" xpath="//Block[@name='Conflict_Out1Data']/*" />
<!-- in einer Kanalvorlage (%C%): <ChannelBlock name="OutData" text="Ausgang %C% Daten" uses="Out1Data Out2Data" /> -->
<op:include href="MyApp.conflicts.gen.xml" xpath="//Block[@name='ConflictChannel_OutData']/*" />
```
```cpp
// Firmware: dieselben Werte (HardwareProfileData.h), Auswahl als Parameter
uint8_t data = HardwareProfile::signalGpio(ParamHWP_HardwareSelect, portByte, manualGpio);
uint8_t relay = HardwareProfile::relaySignalGpio(ParamHWP_HardwareSelect, 0, relayPortByte, relayManualGpio);
if (data == HardwareProfile::GPIO_NONE) { /* kein GPIO: andere oder keine Hardware gewählt, kein Port, nicht gesetzt */ }
```

- Die Port-Parameter je Board (Union auf einem Byte, Vorlagen `PortListTypes.xml` und `BoardParameter.xml`) bleiben, wie
  sie sind; die Prüfung liest sie nur. Ohne gewählte Hardware prüft sie nicht.
- Die Fehlermeldungen sind Parameter ohne Gerätespeicher; die Firmware sieht davon nichts.
- Beispiel mit Kontexthilfe: Demo-Seite „7 GPIO-Konflikte“.
- Reservierte GPIOs: mit `<Conflicts … reserved="true">` meldet ETS auch eine Nutzung auf einem Pin, den das Board selbst
  belegt (Prog-Taster/-LED, Info-LEDs, KNX-UART eines TP-Builds, Flash/PSRAM des ESP32, dazu die `<ReservedPins>` der
  Applikation), und die Firmware prüft mit `HardwareProfile::isReservedGpio(gpio)` dieselben Pins:

```xml
<ReservedPins macros="NEOPIX_LED_PIN QUINLED_ETHERNET_MDC_GPIO QUINLED_ETHERNET_MDIO_GPIO" />   <!-- nur, was die App zusätzlich nicht ansteuert -->
<Conflicts output="src/MyApp.conflicts.gen.xml" number="900" reserved="true"> … </Conflicts>
```
```cpp
if (HardwareProfile::isReservedGpio(data)) { /* Kanal nicht starten, Fehler loggen */ }
```

---

## Durchgehendes Beispiel: Shelly-Aktor (SmartDeviceActuator)

Heute (eigene Auswahl `SDA_HardwareVariant`, Werte von Hand per `<Assign>`):

| Gerät | Schaltkanäle | Binäreingänge | Jalousie | Leistungsmessung | Temperatur |
|---|---|---|---|---|---|
| Shelly Plus 1 | 1 | 1 | – | nein | ja |
| Shelly Plus 1PM | 1 | 1 | – | ja | ja |
| Shelly Plus 2PM / 2PM Gen3 | 2 | 2 | 1 | ja | ja |
| Shelly Plus i4 | – | 4 | – | nein | nein |
| Shelly Plug S MTR Gen3 | 1 | – | – | ja | ja |
| Testgerät (nur ETS) | 16 | 16 | 8 | ja | ja |

Mit OGM-HardwareConfig:

```c
// Board-Header, z. B. Shelly Plus 2PM (DEVICE_THIRD_PARTY, eigene DEVICE_HW_ID)
#define HW_RELAY_COUNT 2
#define OPENKNX_BI_GPIO_COUNT 2
#define HW_POWER_METER
#define HW_TEMP_SENSOR
```
```xml
<!-- Manifest -->
<Import href="lib/OGM-HardwareConfig/generator/capabilities/Common.caps.xml" />
<Value name="Relays" text="Schaltkanäle" expr="HW_RELAY_COUNT" default="0" max="16" />
<Capability name="PowerMeter"  text="Leistungsmessung" expr="defined(HW_POWER_METER)" />
<Capability name="Temperature" text="Gerätetemperatur" expr="defined(HW_TEMP_SENSOR)" />
<Boards platformio="release_*" />
```

| Heute | Mit dem Generator |
|---|---|
| `SDA_HardwareVariant` (Liste von Hand) | Hardware-Auswahl aus den Board-Headern, Wert = HW-ID, mit Geräteabfrage |
| Kanal „Schaltaktor“ `when !=4` | `%HWP_VAL_Relays_GE_1%` |
| Kanal „Binäreingänge“ `when !=6` | `%HWP_VAL_BinaryInputs_GE_1%` |
| Kanal „Jalousie“ `when 0 3 5` | `%HWP_VAL_Relays_GE_2%` |
| `SWA_VisibleChannels`, `BI_VisibleChannels`, `SHC_VisibleChannels` per `<Assign>` | per `BoardWhens.xml` aus `Relays` / `BinaryInputs` (Fall 3b) |
| `SWA_HardwareVariantCanMeasure` | `%HWP_CAP_PowerMeter%` |
| `SWA_HardwareVariantHasTemperature` | `%HWP_CAP_Temperature%` |
| `SWA_HardwareVariantHasFrontControls` | eigene Fähigkeit (z. B. `HW_FRONT_CONTROLS`), sobald ein Gerät sie hat |
| Testgerät „nur ETS“ (alles sichtbar) | „Nicht gewählt“ mit `unselected="showAll"` zeigt alles |
| Eigenschaften-Tabelle auf der Seite | Gerätekarte und Entwickleransicht der Hardware-Seite |

Neue HW-ID: `Build-HardwareProfile.ps1 -NextId 0x25` (nächste freie in der Gruppe, mit Board-Block zum Ausfüllen).

`HW_POWER_METER` und `HW_TEMP_SENSOR` setzen die Shelly-Header (`include/HardwareConfig/Others/Shelly/Devices.h`), z. B. Shelly
Plus 1PM (0x2501) und die beiden Plus-2PM-Platinen PCB v0.1.5 (0x2502) und v0.1.9 (0x2503). `HW_SENSOR_*` und
`HW_FRONT_CONTROLS` sind Vorschläge; sie gibt es in den Headern noch nicht.
