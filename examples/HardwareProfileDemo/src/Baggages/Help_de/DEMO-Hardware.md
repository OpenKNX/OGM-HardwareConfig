# Gerät

**Ausprobieren:** Raumcontroller Pro wählen (Schalter), dann Shelly Plug S (Kennzeichen, Hinweis, QR-Code), dann REG1 Basismodul LAN (kein QR-Code, Standardtext), dann Raumcontroller Plus (eigenes Logo) und AB-SmartHouse (ohne Logo).

**Wie es funktioniert:** Alles auf dieser Seite erzeugt der Generator aus dem Manifest (`<Page>`, `<InfoImage>` mit `<Logo>`, `<Notice>`) und den Board-Headern. Die Bilder (Logo, Kennzeichen, QR+Link, Schritt-Bild `Steps.png`) liegen in `src/Baggages/HWPInfo`. Den Baumtext setzt eine Berechnung aus der Auswahl. Der Abfrageknopf liest per Function Property 158/4 die HW-ID, die Merkmal-Bits und die Werte aus dem Gerät (`answerQuery()` in der Firmware) und setzt die Auswahl.
