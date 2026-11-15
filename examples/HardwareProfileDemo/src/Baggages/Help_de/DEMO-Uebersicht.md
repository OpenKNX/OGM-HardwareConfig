# Hardware-Profil Demo

**Ausprobieren:** Unter *OpenKNX → Gerät* ein Gerät wählen und die Seiten ansehen. „Nicht gewählt“ zeigt alles (`unselected="showAll"`).

**Wie es funktioniert:** Die Board-Header beschreiben die Hardware (`DEVICE_HW_ID`, `HW_RELAY_COUNT`, `HW_SENSOR_CO2` …). Der Generator macht daraus Feature-Flags wie `%HWP_CAP_Co2%`; jede Seite fragt nur diese Flags ab, nie eine Geräteliste. Ein neues Gerät braucht nur seinen Header-Block.
