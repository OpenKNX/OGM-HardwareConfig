#pragma once
/**
 * @file DemoBoards.h
 * @brief Demo boards for the ETS test product only (no firmware env): every kind of hardware dependence in one place.
 * @note IDs 0x3F00..0x3F1F (community range, never used by a real board). Defines HW_POWER_METER, HW_TEMP_SENSOR,
 *       HW_FRONT_CONTROLS, HW_SENSOR_* and HW_SLOT_SENSOR are the names proposed in generator/Anwendungsfaelle.md.
 */

// ---- room controller in three stages (fixed sensors on the board; Pro has a slot for a plug-in sensor module) ----
#ifdef DEMO_RAUMCONTROLLER_BASIC
    #define DEVICE_HW_ID 0x3F00
    #define DEVICE_ID "Demo-Raumcontroller-Basic"
    #define DEVICE_NAME "Demo Raumcontroller Basic – Temp./Feuchte"
    #define HW_INFO_TEXT "Hat: Temperatur/Feuchte, kein Relais, keine Info-LED. Zeigt: Seite 4 nur Temperatur/Feuchte; Zeitquelle nur keine/KNX-Bus; Kanäle mit voller Liste, ohne „Schaltzustand senden“; keine Info-LED-Zeile."
    #define HW_SENSOR_TEMP_HUM
    #define KNX_UART_RX_PIN 1
#endif
#ifdef DEMO_RAUMCONTROLLER_PLUS
    #define DEVICE_HW_ID 0x3F01
    #define DEVICE_ID "Demo-Raumcontroller-Plus"
    #define DEVICE_NAME "Demo Raumcontroller Plus – CO2, Lux, 2 Info-LEDs"
    #define HW_INFO_TEXT "Hat: Temp./Feuchte, CO2, Helligkeit, 2 Eingänge, 2 Status-LEDs, Info-LEDs links/rechts. Zeigt: eigenes Logo; Info LEDs: Info 1 Busstatus, Info 2 Zeitstatus (änderbar); Kanäle: Zeile „Status-LED“; kein Relais."
    #define HW_INFO_URL "https://openknx.de"
    #define HW_SENSOR_TEMP_HUM
    #define HW_SENSOR_CO2
    #define HW_SENSOR_LUX
    #define OPENKNX_BI_GPIO_COUNT 2
    #define OPENKNX_SLED_COUNT 2
    #define KNX_UART_RX_PIN 1
    // info LEDs: rows "Info 1" / "Info 2" of the page "Info LEDs" with the label, preset function (HardwareManifest.xml <PartRows>, <Fixes>)
    #define INFO1_LED_PIN 20
    #define INFO1_LED_LABEL "links"
    #define OPENKNX_INFOLED1_DEFAULT 3  // Busstatus (OPENKNX_LEDFUNC_BASE_KNX; the generator reads numbers only)
    #define INFO2_LED_PIN 21
    #define INFO2_LED_LABEL "rechts"
    #define OPENKNX_INFOLED2_DEFAULT 4  // Zeitstatus (OPENKNX_LEDFUNC_BASE_TIME)
#endif
#ifdef DEMO_RAUMCONTROLLER_PRO
    #define DEVICE_HW_ID 0x3F02
    #define DEVICE_ID "Demo-Raumcontroller-Pro"
    #define DEVICE_NAME "Demo Raumcontroller Pro – Präsenz, Steckplatz, Info 3 fest"
    // what this demo board shows (device card on the page "Gerät"): what it has and what the demo pages must show
    #define HW_INFO_TEXT "Hat: Temp./Feuchte, CO2, Helligkeit, Präsenz, Steckplatz, 4 Eingänge, Info-LEDs links/mitte. Zeigt: Schalter „Steckmodul“; Info LEDs: Info 1 Busstatus, Info 3 fest „Gerätestatus“ (nur lesbar); Modul „Demo-Präsenz“ nur hier; kein Relais."
    #define HW_SENSOR_TEMP_HUM
    #define HW_SENSOR_CO2
    #define HW_SENSOR_LUX
    #define HW_SENSOR_PRESENCE
    #define HW_SLOT_SENSOR            // slot for a plug-in sensor module: the firmware detects it at run time
    #define OPENKNX_BI_GPIO_COUNT 4
    #define OPENKNX_SLED_COUNT 4
    #define KNX_UART_RX_PIN 1
    // one info LED with the same label and function as the Plus (same group in the generated rows)
    #define INFO1_LED_PIN 20
    #define INFO1_LED_LABEL "links"
    #define OPENKNX_INFOLED1_DEFAULT 3
    // info LED 3 with a fixed function: row "Info 3" read-only "Geraetestatus" (HardwareManifest.xml <Fix name="InfoLed3"> in the
    // copy of the OGM-Common part)
    #define INFO3_LED_PIN 22
    #define INFO3_LED_LABEL "mitte"
    #define OPENKNX_INFOLED3_DEFAULT 2  // Geraetestatus (OPENKNX_LEDFUNC_BASE_DEVICE)
#endif

// ---- smart relays of a third party (example of a Shelly family, see generator/Anwendungsfaelle.md) ----
#ifdef DEMO_SHELLY_PLUS_1
    #define DEVICE_HW_ID 0x3F10
    #define DEVICE_ID "Demo-Shelly-Plus-1"
    #define DEVICE_NAME "Demo Shelly Plus 1 – 1 Relais, WLAN"
    // what this demo board shows (device card on the page "Gerät"): what it has and what the demo pages must show
    #define HW_INFO_TEXT "Hat: 1 Relais (fest an GPIO 26), 1 Eingang, Gerätetemperatur, WLAN. Zeigt: Schaltfunktion ohne Jalousie/Messung; Zeitquelle mit NTP; Kanalfunktion nur nicht genutzt/Schalten; nur Kanal 1 „Schaltzustand senden“."
    #define DEVICE_THIRD_PARTY
    #define HW_RELAY_COUNT 1
    #define HW_RELAY_1_GPIO 26
    #define OPENKNX_BI_GPIO_COUNT 1
    #define HW_TEMP_SENSOR
    #define KNX_IP_WIFI
#endif
#ifdef DEMO_SHELLY_PLUS_1PM
    #define DEVICE_HW_ID 0x3F11
    #define DEVICE_ID "Demo-Shelly-Plus-1PM"
    #define DEVICE_NAME "Demo Shelly Plus 1PM – 1 Relais, Messung"
    // what this demo board shows (device card on the page "Gerät"): what it has and what the demo pages must show
    #define HW_INFO_TEXT "Hat: 1 Relais, 1 Eingang, Leistungsmessung, Gerätetemperatur, WLAN. Zeigt: Schaltfunktion mit Leistung messen; Betriebsart fest „Leistung messen“ (nur lesbar); Kanalfunktion 0/1/3; nur Kanal 1 „Schaltzustand senden“."
    #define DEVICE_THIRD_PARTY
    #define HW_RELAY_COUNT 1
    #define HW_RELAY_1_GPIO 26
    #define OPENKNX_BI_GPIO_COUNT 1
    #define HW_POWER_METER
    #define HW_TEMP_SENSOR
    #define KNX_IP_WIFI
#endif
#ifdef DEMO_SHELLY_PLUS_2PM
    #define DEVICE_HW_ID 0x3F12
    #define DEVICE_ID "Demo-Shelly-Plus-2PM"
    #define DEVICE_NAME "Demo Shelly Plus 2PM – 2 Relais, Messung"
    #define DEVICE_THIRD_PARTY
    #define HW_INFO_TEXT "Hat: 2 Relais (auch 1 Jalousie), 2 Eingänge, Leistungsmessung, Gerätetemperatur, WLAN. Zeigt: Schaltfunktion mit Jalousie; Betriebsart fest „Leistung messen“; Kanal 1 und 2 „Schaltzustand senden“."
    #define HW_RELAY_COUNT 2
    #define HW_RELAY_1_GPIO 12
    #define HW_RELAY_2_GPIO 13
    #define OPENKNX_BI_GPIO_COUNT 2
    #define HW_POWER_METER
    #define HW_TEMP_SENSOR
    #define KNX_IP_WIFI
#endif
#ifdef DEMO_SHELLY_PLUS_I4
    #define DEVICE_HW_ID 0x3F13
    #define DEVICE_ID "Demo-Shelly-Plus-i4"
    #define DEVICE_NAME "Demo Shelly Plus i4 – 4 Eingänge, kein Relais"
    // what this demo board shows (device card on the page "Gerät"): what it has and what the demo pages must show
    #define HW_INFO_TEXT "Hat: 4 Eingänge, WLAN, kein Relais. Zeigt: Schaltfunktion nur nicht genutzt/„Taster auswerten“; Kanalfunktion nur nicht genutzt/Schalten; keine Zeile „Schaltzustand senden“."
    #define DEVICE_THIRD_PARTY
    #define OPENKNX_BI_GPIO_COUNT 4
    #define KNX_IP_WIFI
#endif
#ifdef DEMO_SHELLY_PLUG_S
    #define DEVICE_HW_ID 0x3F14
    #define DEVICE_ID "Demo-Shelly-Plug-S"
    #define DEVICE_NAME "Demo Shelly Plug S – Stecker, Messung, Front"
    // what this demo board shows (device card on the page "Gerät"): what it has and what the demo pages must show
    #define HW_INFO_TEXT "Hat: 1 Relais (fest an GPIO 4), Leistungsmessung, Gerätetemperatur, Taste/LED-Ring, WLAN. Zeigt: Schaltfunktion Schalten/Leistung messen; Betriebsart fest „Leistung messen“; nur Kanal 1 „Schaltzustand senden“."
    #define DEVICE_THIRD_PARTY
    #define HW_INFO_URL "https://www.shelly.com"
    #define HW_RELAY_COUNT 1
    #define HW_RELAY_1_GPIO 4
    #define HW_POWER_METER
    #define HW_TEMP_SENSOR
    #define HW_FRONT_CONTROLS        // button and LED ring on the device
    #define KNX_IP_WIFI
#endif
