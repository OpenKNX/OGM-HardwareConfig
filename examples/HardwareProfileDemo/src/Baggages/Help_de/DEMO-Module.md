# 1 Module und Kanäle

**Wie es funktioniert:** Wert `Relays` (`HW_RELAY_COUNT`) und `BinaryInputs` (`OPENKNX_BI_GPIO_COUNT`) im Manifest. Kanal n steht in `<when test="%HWP_VAL_Relays_GE_n%">`, der Hinweis in `%HWP_VAL_Relays_EQ_0%`.

Probieren: Demo Shelly Plus 1 (1 Kanal), Plus 2PM (2 Kanäle + Jalousie), Plus i4 (keine Relais, 4 Eingänge).
