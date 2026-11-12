# Device-Registry

Verbindliche Liste der veröffentlichten OpenKNX-Geräte, mit der `DEVICE_ID` aus den Headern als Schlüssel.
Toolbox / Gerätemanager und Wiki lesen daraus die Geräteübersicht.

## Aufbau

- `devices/<DEVICE_ID>.json`: eine Datei je Gerät, flach, ohne Unterordner.
- `devices/schema.json`: JSON-Schema für die Gerätedateien. Alle Wertelisten stehen hier, auch `vendor` und
  `platform`; ein neuer Hersteller oder eine neue Plattform kommt per PR ins Schema.

Der Header bleibt die Quelle für `DEVICE_ID` und `DEVICE_NAME`. Ein Gerät steht in der Registry, sobald seine
Datei per PR angelegt ist; Makros ohne Datei (Hilfsmakros, Entwicklungsboards, Unveröffentlichtes) sind kein Fehler.

Bilder liegen nicht hier, sondern im Repo [OpenKNX/OpenKNX.github.io](https://github.com/OpenKNX/OpenKNX.github.io)
unter `data/devices/img/<DEVICE_ID>.jpg` (quadratisch, mindestens 500 × 500 Pixel). Dort liegt auch der Aggregator,
der daraus und aus diesen Dateien `devices.json` erzeugt. Bei einem neuen Gerät zuerst die Gerätedatei hier,
danach das Bild dort per PR einreichen.

## Felder

| Feld | Pflicht | Werte |
| --- | --- | --- |
| `id` | ja | `DEVICE_ID`, gleich dem Dateinamen |
| `name` | ja | genau der `DEVICE_NAME` aus dem Header |
| `vendor` | ja | `OpenKNX` |
| `category` | ja | `universal`, `gateway`, `sensor`, `actuator`, `binary-input`, `control`, `other` (Gruppen der Wiki-Geräteübersicht) |
| `platform` | nein | `REG1`, `REG2`, `UP1` |
| `formFactor` | ja | `type`: `reg`, `up`, `ap`, `other`; `units` (Teilungseinheiten) Pflicht bei `reg`, sonst nicht erlaubt; `frame` Pflicht bei `up` (`true` = mit Tragring auf der Dose, im Schalterprogramm; `false` = in der Dose), sonst nicht erlaubt |
| `mcu` | ja | `RP2040`, `RP2350`, `ESP32`, `ESP32-S3` |
| `network` | ja | Anschlüsse zur Steuerungsebene, mindestens einer: `knx-tp`, `knx-rf`, `lan`, `wlan`, `spe`. KNX/IP ist ein Firmware-Feature und braucht einen IP-fähigen Anschluss |
| `power` | ja | mögliche Versorgungen, jede reicht allein: `bus`, `dc`, `ac`, `poe`, `usb` |
| `status` | ja | `planned`, `alpha`, `beta`, `stable`, `deprecated`; Reifegrad der Hardware, unabhängig von den Applikationen |
| `availability` | ja | mindestens einer von `opensource`, `kit`, `pcb` |
| `description` | nein | Deutsch, höchstens 400 Zeichen und 4 Zeilen |
| `translations` | nein | `{ "<Sprachcode>": { "name"?, "description"? } }`, Sprachcode nach ISO 639-1, nicht `de` |
| `links` | nein | `source` (Bezugsquelle), `forum` (Thread im knx-user-forum), `hardware` (Repo, Schaltplan), `wiki` (nur wenn abweichend von `https://device.openknx.de/<id>`; fehlt dort die Weiterleitung, hat das Gerät keinen Wiki-Link) |

## Prüfung

Bei jedem Pull Request prüft `.github/workflows/device-registry.yml` mit `scripts/registry/check_devices.py`:

1. Die Datei ist gültig nach `devices/schema.json`, und der Dateiname ist gleich `id`.
2. Ein Makro in den Headern ergibt genau diese `DEVICE_ID` (Auflösung per C-Präprozessor wie im Firmware-Build).
3. `name` ist gleich dem `DEVICE_NAME` dieses Makros.

Schlägt die Prüfung fehl, zeigt der Pull Request die Meldungen; der Autor korrigiert im selben PR.

### Optional: vor dem Pull Request selbst prüfen

Wer eine Gerätedatei anlegt oder ändert, kann dieselbe Prüfung vorab auf dem eigenen Rechner laufen lassen und
spart sich so Korrekturrunden im PR. Nötig ist das nicht, die CI prüft ohnehin. Voraussetzungen sind Python mit
dem Paket `jsonschema` und der C-Präprozessor `cpp` (Teil von gcc, unter Windows z. B. über MSYS2):

```
pip install jsonschema
python scripts/registry/check_devices.py
```
