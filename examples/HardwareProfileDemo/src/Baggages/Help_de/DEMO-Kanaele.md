# Kanäle je Hardware

**Wie es funktioniert:** Die drei Kanäle kommen aus einer Kanal-Vorlage (`HardwareProfileDemo.Channel.templ.xml`). Ihre Parameter haben IDs mit den Platzhaltern des OpenKNXproducers (`%TT%%CC%001`); der Generator nimmt diese Platzhalter in seine Teile mit, so gilt ein Eintrag im Manifest für jeden Kanal. Kein Script.

- **Betriebsart** (`<Fix>`): auf Geräten mit Leistungsmessung fest „Leistung messen“ und nur lesbar, sonst frei wählbar.
- **Kanalfunktion** (`<Filters>`): Geräte mit Leistungsmessung bieten „nicht genutzt“, „Schalten“ und „Leistung messen“, die übrigen Shellys nur „nicht genutzt“ und „Schalten“, alle anderen Geräte die volle Liste.
- **Status-LED zeigt den Kanal** (`<PartRows>`): die Zeile erscheint nur auf Geräten, deren Board-Header eine zweite Info-LED hat (`INFO2_LED_PIN`). Das Produkt nutzt dafür eine erzeugte Kopie der Vorlage.
- **Schaltzustand senden** (`<PartRows>` mit `count`): Kanal n zeigt die Zeile nur, wenn das Gerät mindestens n Relais hat (Shelly Plus 1PM und Plug S: Kanal 1, Plus 2PM: Kanal 1 und 2, Plus i4: keiner).

Ohne gewähltes Gerät zeigen alle Kanäle die volle Liste und alle Zeilen.
