# 6 Firmware

**Geräteabfrage:** Der Knopf „Vom Gerät lesen“ (Seite Gerät, nur bei „Nicht gewählt“) ruft Function Property 158/4. Die Firmware antwortet mit einer Zeile: `if (HardwareProfile::answerQuery(objectIndex, propertyId, resultData, resultLength, runtimeCaps)) return true;`. `runtimeCaps` braucht nur ein Board mit `runtime="true"`-Fähigkeit (hier: Steckmodul des Raumcontroller Pro); sonst entfällt das Argument.

**Auswahl prüfen:** `HardwareProfile::checkSelection(ParamHWP_HardwareSelect)` liefert `NotSelected`, `Match` oder `Other`. Nur bei `Match` hardwareabhängige Parameter lesen; `Other` kann die Applikation melden (Log, KO, LED).

**Seite Gerät:** Gerätekarte (Logo bzw. Badge, Name, Text, QR nur mit `HW_INFO_URL`), optional `firmware="Firmware: {env}"` und `changeInfo`, Drittanbieter-Hinweis.
