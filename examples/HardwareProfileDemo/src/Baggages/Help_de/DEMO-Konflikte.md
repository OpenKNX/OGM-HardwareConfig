# 7 GPIO-Konflikte

**Zum Ausprobieren:**

- KNeoPix wählen, „Genutzte Ausgänge“ = 2, bei beiden Ausgängen denselben Daten-Port: beide melden einen Konflikt.
- Ausgang 1 auf „Manuell“, Daten-GPIO = GPIO eines Ports von Ausgang 2: Konflikt (manuell gegen Port).
- Ausgang 1 auf „SPI“: statt des Daten-GPIO zählt der MOSI-GPIO, dazu der Takt.
- „Genutzte Ausgänge“ auf 1 zurück: Ausgang 2 zählt nicht mehr, seine Meldung verschwindet.
- Shelly Plus 1 wählen, Ausgang 1 „Manuell“ mit GPIO 26: Konflikt mit dem fest verdrahteten Relais 1.
- Freier Anschluss 1 und 2 (Seite Hardware) auf denselben Pin: beide Meldungen stehen hier.
- KNeoPix wählen, Ausgang 1 „Manuell“ mit Daten-GPIO 0: Meldung „GPIO … selbst belegt“, GPIO 0 ist der KNX-TX-Pin dieser TP-Firmware. Ebenso GPIO 26 (Prog-Taster) oder beim KNeoPix ESP32-S3 GPIO 30 (Flash).

**Wie es funktioniert:** `<Conflicts>` im Manifest. Der Generator schreibt eine ParameterCalculation mit einer Funktion, die über eine Tabelle läuft: jede aktive Nutzung ergibt einen GPIO (Port-Wert über die Port-Tabelle der gewählten Hardware, „Manuell“ über den GPIO-Parameter, fest verdrahtetes Relais über `HW_RELAY_<n>_GPIO`). Gleicher GPIO = Konflikt. Mit `reserved="true"` zählen auch die Pins, die die Hardware selbst belegt (Prog-Taster/-LED, Info-LEDs, KNX-UART einer TP-Firmware, Flash/PSRAM des ESP32 und die `<ReservedPins>` des Manifests); dieselben Pins prüft die Firmware mit `HardwareProfile::isReservedGpio`. Die Ergebnisse sind Parameter ohne Gerätespeicher; je Nutzung bindet die Applikation einen fertigen Block `Conflict_<Name>` ein.
