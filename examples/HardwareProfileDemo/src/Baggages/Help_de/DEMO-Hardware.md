# Hardware

**Was Sie sehen:** Die Auswahl der Hardware. Bei „Nicht gewählt“ stehen darunter der Abgleich mit dem Gerät (Knopf „Hardware vom Gerät abfragen“) und der Hinweis, dass alle Einstellungen sichtbar sind. Bei einem gewählten Gerät steht dort die Gerätekarte:

- OpenKNX-Logo oder, bei `DEVICE_THIRD_PARTY`, das Kennzeichen „Drittanbieter Hardware“
- Gerätename (`DEVICE_NAME`) und Beschreibung (`HW_INFO_TEXT`, sonst der Standardtext)
- QR-Code mit Link, nur wenn der Header `HW_INFO_URL` hat (KNeoPix, Raumcontroller Plus, Shelly Plug S)
- „Firmware: …“ nur bei Boards mit eigenem Build-Env (KNeoPix RP2350 / ESP32-S3)
- der Kasten „Nach einem Wechsel der Hardware …“ bei jedem Gerät
- der Schalter „Steckmodul Sensor“ nur beim Raumcontroller Pro
- der Drittanbieter-Hinweis bei QuinLED und den Shellys

**Ausprobieren:** Raumcontroller Pro wählen (Schalter), dann Shelly Plug S (Kennzeichen, Hinweis, QR-Code), dann REG1 Basismodul LAN (kein QR-Code, Standardtext).

**Wie es funktioniert:** Alles auf dieser Seite erzeugt der Generator aus dem Manifest (`<Page>`, `<InfoImage>`, `<Notice>`) und den Board-Headern. Die Bilder (Logo, Kennzeichen, QR+Link) liegen in `src/Baggages/HWPInfo`. Der Abfrageknopf liest per Function Property 158/4 die HW-ID, die Merkmal-Bits und die Werte aus dem Gerät (`answerQuery()` in der Firmware) und setzt die Auswahl.
