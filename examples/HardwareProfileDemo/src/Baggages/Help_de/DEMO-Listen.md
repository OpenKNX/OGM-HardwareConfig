# 3 Listen je Hardware

**Wie es funktioniert:** Vorlage `ValueRangeParameter.xml`: je Listenlänge ein Typ und ein Parameter, alle in einer Union auf **einem** Byte; sichtbar ist nur der der gewählten Hardware. `Fixed` setzt den Wert per `<Assign>` und zeigt ihn schreibgeschützt. Kein Script.

**Auswahl gefiltert je Hardware:** `<Filters>` im Manifest. „Schaltfunktion“ und „Zeitquelle“ sind normale Auswahllisten; je Gerät bietet ETS nur die Einträge an, die diese Hardware kann:

- **Schaltfunktion:** neben „nicht genutzt“ bietet der Shelly Plus i4 nur „Taster auswerten“, der Plug S „Schalten“ und „Leistung messen“, der Plus 2PM auch „Jalousie“; alle Geräte außer den Shellys haben die volle Liste.
- **Zeitquelle:** mit Echtzeituhr alle Quellen, mit LAN oder WLAN „KNX-Bus“ und „Internet (NTP)“, sonst nur „KNX-Bus“.

Der Wert landet immer im selben Parameter; die Firmware liest nur diesen.
