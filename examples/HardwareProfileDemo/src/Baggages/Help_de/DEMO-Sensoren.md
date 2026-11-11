# 4 Sensoren

**Was Sie sehen:** Je fest eingebautem Sensor eine Einstellung und ein Kommunikationsobjekt. Raumcontroller Basic: Temperatur/Feuchte. Plus: + CO2, Helligkeit. Pro: + Präsenz und ein Steckplatz für ein Sensormodul.

**Wie es funktioniert:** Je Sensor eine Fähigkeit (`HW_SENSOR_*` im Header). Das Steckmodul ist eine Fähigkeit mit `switch="true"` und `runtime="true"`: Auf der Seite Hardware gibt es einen Schalter; die Geräteabfrage meldet, ob ein Modul steckt (Firmware: `answerQuery(…, runtimeCaps)`; die Demo-Firmware meldet keins).
