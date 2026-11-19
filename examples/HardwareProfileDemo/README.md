# Hardware-Profil Demo

Test- und Beispiel-Applikation des [Hardware-Profil-Generators](../../generator/README.md). Eine knxprod für
16 Geräte zeigt jeden Anwendungsfall aus [Anwendungsfaelle.md](../../generator/Anwendungsfaelle.md); jede Seite hat eine
Kontexthilfe (F1), die sagt, was man sieht und wie es entsteht.

## Geräte

| HW-ID | Gerät | Was es zeigt |
|---|---|---|
| 0x1310 / 0x1320 | OpenKNXiao KNeoPix RP2350 / ESP32-S3 | Board aus dem Build-Env (`<Boards platformio>`), Zeile „Firmware: …“, QR-Code |
| 0x1132 | REG2 PiPico2 W Display RTC | WLAN per Build-Flag, Display, RTC |
| 0x1021 / 0x1022 | REG1 Basismodul LAN+TP / LAN | LAN; ohne TP der Hinweis „nur über IP“ |
| 0x1203 / 0x2400 | UP1 Taster / AB-SmartHouse Taster | 2 bzw. 4 Binäreingänge, Status-LEDs, Summer (nur 0x2400) |
| 0x2121 | QuinLED Dig-Quad V3 Ethernet | Drittanbieter (Badge, Hinweis) |
| 0x3F00–0x3F02 | Demo Raumcontroller Basic / Plus / Pro | Sensoren je Stufe, Pro mit Steckplatz (Schalter auf der Hardware-Seite); Info-LEDs: Plus Info 1/2 mit Label und Funktion (änderbar), Pro Info 1 und Info 3 fest „Gerätestatus“ (nur lesbar) |
| 0x3F10–0x3F14 | Demo Shelly Plus 1 / 1PM / 2PM / i4 / Plug S | Relais, Eingänge, Jalousie, Leistungsmessung, Frontbedienung, Drittanbieter; Listen und Kanäle je Modell (Tabelle unten) |

Die Demo-Geräte (0x3Fxx) stehen nur hier, in `include/DemoBoards.h`; `include/HardwareConfig.h` hängt sie an die echten
Header an (`<IncludePath>include</IncludePath>`). Sie haben keine Firmware. Ihr Name in der Auswahl nennt die wichtigsten
Merkmale, ihre Gerätekarte (`HW_INFO_TEXT`) sagt „Hat: …“ und „Zeigt: …“: was auf den Demo-Seiten mit diesem Gerät zu sehen
sein muss. Geprüft im Viewer (Demo 2.9):

| Gerät | Schaltfunktion (Seite 3) | Zeitquelle | Kanäle: Betriebsart / Kanalfunktion / „Schaltzustand senden“ | Info LEDs |
|---|---|---|---|---|
| Raumcontroller Basic | volle Liste | keine, KNX-Bus | änderbar / volle Liste / keiner | keine Zeile |
| Raumcontroller Plus | volle Liste | keine, KNX-Bus | änderbar / volle Liste / keiner; Zeile „Status-LED“ | Info 1 Busstatus, Info 2 Zeitstatus |
| Raumcontroller Pro | volle Liste | keine, KNX-Bus | änderbar / volle Liste / keiner | Info 1 Busstatus, Info 3 fest Gerätestatus |
| Shelly Plus 1 | nicht genutzt, Schalten, Treppenlicht | + Internet (NTP) | änderbar / nicht genutzt, Schalten / Kanal 1 | – |
| Shelly Plus 1PM | + Leistung messen | + Internet (NTP) | fest „Leistung messen“ / + Leistung messen / Kanal 1 | – |
| Shelly Plus 2PM | + Jalousie, Leistung messen | + Internet (NTP) | fest „Leistung messen“ / + Leistung messen / Kanal 1, 2 | – |
| Shelly Plus i4 | nicht genutzt, Taster auswerten | + Internet (NTP) | änderbar / nicht genutzt, Schalten / keiner | – |
| Shelly Plug S | nicht genutzt, Schalten, Leistung messen | + Internet (NTP) | fest „Leistung messen“ / + Leistung messen / Kanal 1 | – |

## Seiten

| Seite | Anwendungsfall | Mittel |
|---|---|---|
| OpenKNX → Gerät | Auswahl, Geräteabfrage, Funktionen des gewählten Geräts unter der Karte (`<Page cardFeatures>`), Gerätekarte (eigenes Logo: Raumcontroller Plus, ohne Logo: AB-SmartHouse), Firmware-Zeile, Wechsel-Hinweis, Steckmodul-Schalter, Kontexthilfe | `<Page>` (`help`), `<InfoImage>`, `<Notice>` |
| 1 Module und Kanäle | Kanäle je Relais, Jalousie ab 2 Relais, Eingänge je Hardware | `%HWP_VAL_*_GE_n%`, `_EQ_0` |
| 2 Merkmale | Leistungsmessung, Temperatur, Frontbedienung, Display, Summer, großer Flash; KOs nur mit Merkmal | `%HWP_CAP_*%` |
| 3 Listen je Hardware | Liste 0..n je Gerät, fester Wert schreibgeschützt; „Schaltfunktion“ mit eigener Teilmenge je Shelly-Modell, „Zeitquelle“ je Fähigkeit (RTC, LAN/WLAN, sonst nur Bus) | `ValueRangeParameter.xml`, `<Filters>` (`<Allow board>`, `<Allow capability>`, `board="*"`) |
| 4 Sensoren | Sensoren je Raumcontroller-Stufe, Steckmodul | `%HWP_CAP_*%`, `switch="true"` |
| 5 Netzwerk | LAN, WLAN (auch vor der Auswahl), kein TP | `Common.caps.xml`, `_OR_NONE`, `NOCAP` |
| 6 Firmware | Geräteabfrage und Auswahlprüfung in der Firmware | `answerQuery()`, `checkSelection()` |
| 7 GPIO-Konflikte | zwei Ausgänge mit Port je Board, „Manuell“, SPI (MOSI + Takt), freie Anschlüsse, feste Relais der Shellys: gleicher GPIO = Fehlermeldung; „Manuell“ auf einem reservierten Pin (KNX-UART, Prog-Taster, Flash) = eigene Meldung | `<Conflicts reserved="true">`, `<ReservedPins>`, `portManualValue`/`portNoneValue`, `src/hw/Outputs.xml` |
| Demo-Kanäle → Kanäle je Hardware | Kanal-Vorlage (3 Kanäle, eigenes Modul DEMOCH): „Betriebsart“ auf Geräten mit Leistungsmessung fest und nur lesbar, „Kanalfunktion“ gefiltert (Leistungsmessung: 0 1 3, übrige Shellys: 0 1), Zeile „Status-LED“ nur mit `INFO2_LED_PIN` | Tokens `%TT%%CC%` in `<Fix ref>` (Block `Fix_<name>_ParameterRefs`), `<Filter ref>` und `<PartRows>` auf der Vorlage (die Kopie ist `template=`) |
| Demo-Präsenz | ein Modul, das nur Geräte mit Präsenzsensor unterstützen (Raumcontroller Pro): auf allen anderen Geräten verschwindet das ganze Modul aus dem Baum | `<Fix capability="!Presence" value="0" show="assign">` auf den OpenKNX-Modulschalter `BASE_ModuleEnabled_DEMOPM` |
| OpenKNX → Info LEDs | Zeilen „Info 1..3“ nur, wenn das Board die LED hat, mit Label aus dem Board-Header („Info 1 (links)“); Funktion beim Wählen des Boards aus `OPENKNX_INFOLED<n>_DEFAULT` (Raumcontroller Plus / Pro), änderbar | `<PartRows>` (`%BASE_InfoLedPart%`), `<Fix valueMacro show="assign">` |
| Entwickleransicht | technische Daten je Board | `<Page dev>` |

„Nicht gewählt“ zeigt alles (`unselected="showAll"`).

## Bauen

Einmalig `lib/` anlegen (Links, `lib/` ist nicht im Repo):

- Generator (`Build-HardwareProfile.ps1`, auch `-Check` und die CI): `lib/OGM-HardwareConfig` → `../../..` (dieses Repo)
  und `lib/OGM-Common` → ein Checkout von OGM-Common (die CI legt ihn unter `_deps/OGM-Common` ab).
- knxprod (OpenKNXproducer) zusätzlich: `lib/OFM-ConfigTransfer` (die Applikation bindet `ConfigTransfer.share.xml` ein).
- Firmware zusätzlich: `lib/knx` und `lib/TPUart` (knx bindet `TPUart/Interface/Abstract.h` in `platform.h` ohne
  Bedingung ein, auch für IP-Builds).

```
pwsh ../../generator/Build-HardwareProfile.ps1          # Profil erzeugen (-Check: nur prüfen)
cd src && OpenKNXproducer create -h ../include/knxprod.h HardwareProfileDemo.xml
pio run -e release_OKNXHW_OPENKNXIAO_KNEOPIX_RP2350_V1
```

## Update testen

`pwsh scripts/Test-DemoUpdate.ps1` baut die Demo als Version N in eine Kopie (`out/update`, nicht im Repo), ändert sie an
jeder Stelle, an der ein Update brechen kann, baut Version N+1 und vergleicht beide knxprods so, wie ETS beim
„Aktualisieren“ Werte übernimmt (gleiche ParameterRef-Nummer, der neue Typ nimmt den alten Wert an):

| Änderung in N+1 | geprüft wird |
|---|---|
| Fähigkeit mitten im Paket, eigene Fähigkeit vorn, zwei Fähigkeiten getauscht | Abfrage-Bits bleiben je Name, neue hängen hinten an |
| Fähigkeit wird Schalter, neuer Schalter | Schalter-Parameter behalten ihre IDs |
| neuer Wert ohne Abfrage, Wertebereich vergrößert | kein Abfrage-Bit, alte Werte bleiben gültig |
| Board entfernt, Board neu, Reihenfolge der Auswahl | Slots und IDs bleiben, nur das entfernte Board fällt weg (erwartet) |
| GPIO-Rolle mit einem Feld mehr, neue GPIO-Rolle, Texte | alte Parameter bleiben |

Jeder andere Verlust lässt den Test scheitern (Exit-Code 1), auch ein Parameter, der in N+1 nur noch lesbar ist oder seinen
Speicher verliert. Nicht geprüft wird die Sichtbarkeit (`choose`, `Assign`) in N+1: ein ausgeblendeter Parameter bekommt beim
nächsten Download seinen Standardwert; das zeigt der Test in ETS. Der Ausgabeordner wird bei jedem Lauf neu angelegt; einen
Ordner, den das Skript nicht selbst angelegt hat (Markierung `.test-demo-update`), löscht es nicht. `-Break` fügt einen echten Bruch hinzu (ein Board bietet
weniger Ports an): dann muss der Test scheitern. Beide knxprods bleiben in `out/update` für den Test in ETS: N
importieren, Gerät einfügen, Werte setzen, N+1 importieren, „Aktualisieren“. `-Language en` gibt alles auf Englisch aus (Standard: Deutsch).

`OpenKnxId 0xAD` / `ApplicationNumber 240` sind Platzhalter für die Demo (0xAD ist die OpenKnxId von NeoPixel; eine eigene Applikation braucht ihre eigene). Die GitHub Action des Repos
(`.github/workflows/hardware-profile.yml`) prüft bei jedem Push und Pull Request, dass die erzeugten Dateien dieser Demo aktuell sind.
