# 3 Listen je Hardware

**Was Sie sehen:** „Genutzte Relais“ und „Genutzte Binäreingänge“ bieten nur so viele Einträge, wie die Hardware hat (0..1, 0..2, 0..4). „Schaltkanäle“ und „Status-LEDs“ sind fest auf den Wert der Hardware gesetzt und nur lesbar.

**Wie es funktioniert:** Vorlage `ValueRangeParameter.xml`: je Listenlänge ein Typ und ein Parameter, alle in einer Union auf **einem** Byte; ETS zeigt den der gewählten Hardware. `Fixed` setzt den Wert per `<Assign>` und zeigt ihn schreibgeschützt. Kein Script.
